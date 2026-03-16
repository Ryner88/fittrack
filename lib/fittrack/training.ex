defmodule Fittrack.Training do
  @moduledoc """
  The Training context.
  """

  import Ecto.Query, warn: false

  alias Fittrack.Accounts.Scope
  alias Fittrack.Repo
  alias Fittrack.Training.Exercise
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.Normalizer
  alias Fittrack.Training.Workout
  alias Fittrack.Training.WorkoutSet
  alias Fittrack.Training.WorkoutPlan
  alias Fittrack.Training.WorkoutPlanExercise

  @doc """
  Returns the list of exercises for the current user.
  """
  def list_exercises(scope, opts \\ %{})

  def list_exercises(%Scope{user: user}, opts) do
    search = Map.get(opts, :search)
    search = if is_binary(search), do: String.trim(search), else: search

    Exercise
    |> where([exercise], exercise.user_id == ^user.id)
    |> maybe_filter_exercises(search)
    |> order_by([exercise], asc: exercise.name)
    |> Repo.all()
  end

  def list_exercises(_, _opts), do: []

  @doc """
  Gets a single exercise for the current user.
  """
  def get_exercise!(%Scope{user: user}, id) do
    Repo.get_by!(Exercise, id: id, user_id: user.id)
  end

  @doc """
  Creates a exercise scoped to the current user.
  """
  def create_exercise(%Scope{user: user}, attrs) do
    %Exercise{}
    |> Exercise.changeset(attrs)
    |> Ecto.Changeset.put_change(:user_id, user.id)
    |> Repo.insert()
  end

  @doc """
  Updates a exercise.
  """
  def update_exercise(%Scope{}, %Exercise{} = exercise, attrs) do
    exercise
    |> Exercise.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a exercise.
  """
  def delete_exercise(%Scope{}, %Exercise{} = exercise) do
    Repo.delete(exercise)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking exercise changes.
  """
  def change_exercise(%Exercise{} = exercise, attrs \\ %{}) do
    Exercise.changeset(exercise, attrs)
  end

  @doc """
  Returns the list of exercise templates.
  """
  def list_exercise_templates(opts \\ %{}) do
    search = Map.get(opts, :search)
    search = if is_binary(search), do: String.trim(search), else: search

    muscle_group = Map.get(opts, :muscle_group)
    equipment = Map.get(opts, :equipment)
    difficulty = Map.get(opts, :difficulty)

    ExerciseTemplate
    |> maybe_filter_templates(search)
    |> maybe_filter_by_muscle_group(muscle_group)
    |> maybe_filter_by_equipment(equipment)
    |> maybe_filter_by_difficulty(difficulty)
    |> order_by([template], asc: template.name)
    |> Repo.all()
  end

  @doc """
  Creates a user exercise from a shared template.
  """
  def add_template_to_user(scope, template_id)

  def add_template_to_user(%Scope{user: user}, template_id) do
    with %ExerciseTemplate{} = template <- Repo.get(ExerciseTemplate, template_id) do
      normalized_name = Normalizer.normalize_text(template.name)
      normalized_equipment = Normalizer.normalize_text(template.equipment)

      # Fast path: return existing exercise without attempting insert (avoids noisy unique constraint errors)
      case Repo.get_by(Exercise,
             user_id: user.id,
             normalized_name: normalized_name,
             normalized_equipment: normalized_equipment
           ) do
        %Exercise{} = exercise ->
          {:ok, exercise}

        nil ->
          attrs = %{
            name: template.name,
            primary_muscle: template.primary_muscle,
            equipment: template.equipment,
            notes: template.notes
          }

          %Exercise{}
          |> Exercise.changeset(attrs)
          |> Ecto.Changeset.put_change(:user_id, user.id)
          |> Repo.insert()
      end
    else
      nil -> {:error, :not_found}
    end
  end

  def add_template_to_user(_, _template_id), do: {:error, :unauthorized}

  @doc """
  Returns the list of workouts for the current user.
  """
  def list_workouts(%Scope{user: user}) do
    Workout
    |> where([workout], workout.user_id == ^user.id)
    |> order_by([workout], desc: workout.started_at)
    |> preload(workout_sets: [:exercise])
    |> Repo.all()
  end

  def list_workouts(_), do: []

  @doc """
  Gets a workout with sets for the current user.
  """
  def get_workout!(%Scope{user: user}, id) do
    Workout
    |> where([workout], workout.id == ^id and workout.user_id == ^user.id)
    |> Repo.one!()
    |> Repo.preload(workout_sets: workout_sets_query("oldest"))
  end

  @doc """
  Lists workout sets for a workout for the current user with multiple sort options.
  """
  def list_workout_sets(scope, workout, opts \\ %{})

  def list_workout_sets(%Scope{user: user}, %Workout{} = workout, opts) do
    sort = Map.get(opts, :sort, "newest")

    if workout.user_id == user.id do
      Repo.all(workout_sets_query(sort, workout.id))
    else
      []
    end
  end

  def list_workout_sets(_, _, _opts), do: []

  @doc """
  Creates a workout scoped to the current user.
  """
  def create_workout(%Scope{user: user}, attrs) do
    %Workout{}
    |> Workout.changeset(attrs)
    |> Ecto.Changeset.put_change(:user_id, user.id)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking workout changes.
  """
  def change_workout(%Workout{} = workout, attrs \\ %{}) do
    Workout.changeset(workout, attrs)
  end

  @doc """
  Creates a workout set within a workout for the current user.
  """
  def create_workout_set(%Scope{user: user}, %Workout{} = workout, attrs) do
    exercise_id = Map.get(attrs, "exercise_id") || Map.get(attrs, :exercise_id)

    with true <- workout.user_id == user.id,
         %Exercise{} <- Repo.get_by(Exercise, id: exercise_id, user_id: user.id) do
      %WorkoutSet{}
      |> WorkoutSet.changeset(attrs)
      |> Ecto.Changeset.put_change(:workout_id, workout.id)
      |> Repo.insert()
      |> preload_workout_set()
    else
      false -> {:error, :unauthorized}
      nil -> {:error, :invalid_exercise}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking workout set changes.
  """
  def change_workout_set(%WorkoutSet{} = workout_set, attrs \\ %{}) do
    WorkoutSet.changeset(workout_set, attrs)
  end

  defp maybe_filter_exercises(query, search) when search in [nil, ""], do: query

  defp maybe_filter_exercises(query, search) do
    like = "%#{search}%"

    where(
      query,
      [exercise],
      ilike(exercise.name, ^like) or ilike(exercise.primary_muscle, ^like) or
        ilike(exercise.equipment, ^like) or ilike(exercise.normalized_name, ^like) or
        ilike(exercise.normalized_equipment, ^like)
    )
  end

  defp maybe_filter_templates(query, search) when search in [nil, ""], do: query

  defp maybe_filter_templates(query, search) do
    like = "%#{search}%"

    where(
      query,
      [template],
      ilike(template.name, ^like) or ilike(template.primary_muscle, ^like) or
        ilike(template.equipment, ^like) or ilike(template.normalized_name, ^like) or
        ilike(template.normalized_equipment, ^like)
    )
  end

  defp maybe_filter_by_muscle_group(query, nil), do: query

  defp maybe_filter_by_muscle_group(query, muscle_group) do
    where(query, [template], template.primary_muscle == ^muscle_group)
  end

  defp maybe_filter_by_equipment(query, nil), do: query

  defp maybe_filter_by_equipment(query, equipment) do
    where(query, [template], template.equipment == ^equipment)
  end

  defp maybe_filter_by_difficulty(query, nil), do: query

  defp maybe_filter_by_difficulty(query, difficulty) do
    where(query, [template], template.difficulty == ^difficulty)
  end

  defp workout_sets_query(sort), do: workout_sets_query(sort, nil)

  defp workout_sets_query(sort, session_id) do
    base =
      from ws in WorkoutSet,
        join: e in assoc(ws, :exercise),
        preload: [exercise: e]

    base =
      if is_nil(session_id) do
        base
      else
        from [ws, e] in base, where: ws.workout_session_id == ^session_id
      end

    case sort do
      "oldest" ->
        from [ws, e] in base, order_by: [asc: ws.inserted_at, asc: ws.id]

      "exercise_asc" ->
        from [ws, e] in base, order_by: [asc: e.name, asc: ws.inserted_at, asc: ws.id]

      "exercise_desc" ->
        from [ws, e] in base, order_by: [desc: e.name, desc: ws.inserted_at, desc: ws.id]

      "weight_desc" ->
        from [ws, e] in base, order_by: [desc: ws.weight, desc: ws.inserted_at, desc: ws.id]

      "reps_desc" ->
        from [ws, e] in base, order_by: [desc: ws.reps, desc: ws.inserted_at, desc: ws.id]

      "rpe_desc" ->
        from [ws, e] in base, order_by: [desc: ws.rpe, desc: ws.inserted_at, desc: ws.id]

      "kind_asc" ->
        from [ws, e] in base, order_by: [asc: ws.kind, desc: ws.inserted_at, desc: ws.id]

      _newest ->
        from [ws, e] in base, order_by: [desc: ws.inserted_at, desc: ws.id]
    end
  end

  defp preload_workout_set({:ok, workout_set}) do
    {:ok, Repo.preload(workout_set, :exercise)}
  end

  defp preload_workout_set(error), do: error

  @doc """
  Returns the list of workout plans for the current user.
  """
  def list_workout_plans(%Scope{user: user}) do
    WorkoutPlan
    |> where([wp], wp.user_id == ^user.id)
    |> order_by([wp], desc: wp.updated_at)
    |> Repo.all()
    |> preload_workout_plan_exercises()
  end

  def list_workout_plans(_), do: []

  defp preload_workout_plan_exercises(workout_plans_or_plan) do
    Repo.preload(workout_plans_or_plan,
      workout_plan_exercises: {
        from(wpe in WorkoutPlanExercise, order_by: [asc: wpe.position]),
        [exercise: []]
      }
    )
  end

  @doc """
  Gets a workout plan with exercises for the current user.
  """
  def get_workout_plan!(%Scope{user: user}, id) do
    WorkoutPlan
    |> where([wp], wp.id == ^id and wp.user_id == ^user.id)
    |> Repo.one!()
    |> preload_workout_plan_exercises()
  end

  @doc """
  Creates a workout plan scoped to the current user.
  """
  def create_workout_plan(%Scope{user: user}, attrs) do
    %WorkoutPlan{}
    |> WorkoutPlan.changeset(attrs)
    |> Ecto.Changeset.put_change(:user_id, user.id)
    |> Repo.insert()
    |> case do
      {:ok, workout_plan} ->
        {:ok, preload_workout_plan_exercises(workout_plan)}

      error ->
        error
    end
  end

  @doc """
  Updates a workout plan.
  """
  def update_workout_plan(%Scope{}, %WorkoutPlan{} = workout_plan, attrs) do
    workout_plan
    |> WorkoutPlan.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, workout_plan} ->
        {:ok, preload_workout_plan_exercises(workout_plan)}

      error ->
        error
    end
  end

  @doc """
  Deletes a workout plan.
  """
  def delete_workout_plan(%Scope{}, %WorkoutPlan{} = workout_plan) do
    Repo.delete(workout_plan)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking workout plan changes.
  """
  def change_workout_plan(%WorkoutPlan{} = workout_plan, attrs \\ %{}) do
    WorkoutPlan.changeset(workout_plan, attrs)
  end

  @doc """
  Creates a workout from a workout plan.
  """
  def create_workout_from_plan(%Scope{user: user}, workout_plan_id) do
    workout_plan = get_workout_plan!(%Scope{user: user}, workout_plan_id)

    # Create a new workout
    {:ok, workout} =
      create_workout(%Scope{user: user}, %{
        name: "#{workout_plan.name} - #{DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d")}"
      })

    # Create workout sets for each exercise in the plan
    Enum.each(workout_plan.workout_plan_exercises, fn plan_exercise ->
      # Create sets based on the plan
      Enum.each(1..(plan_exercise.target_sets || 1), fn _set_number ->
        create_workout_set(%Scope{user: user}, workout, %{
          exercise_id: plan_exercise.exercise_id,
          reps: plan_exercise.target_reps_min || 8,
          rest_seconds: plan_exercise.rest_seconds
        })
      end)
    end)

    {:ok, workout}
  end

  @doc """
  Counts the total number of personal bests for the current user.
  """
  def count_personal_bests(%Scope{user: user}) do
    from(ws in WorkoutSet,
      join: wsession in assoc(ws, :workout),
      join: e in assoc(ws, :exercise),
      where: wsession.user_id == ^user.id and e.user_id == ^user.id,
      select: {e.id, max(ws.weight)},
      group_by: e.id
    )
    |> Repo.all()
    |> length()
  end

  def count_personal_bests(_), do: 0

  @doc """
  Calculates the total volume lifted by the current user.
  """
  def total_volume_lifted(%Scope{user: user}) do
    from(ws in WorkoutSet,
      join: wsession in assoc(ws, :workout),
      where: wsession.user_id == ^user.id,
      select: sum(ws.weight * ws.reps)
    )
    |> Repo.one()
    |> case do
      nil -> 0.0
      value -> value
    end
  end

  def total_volume_lifted(_), do: 0.0

  @doc """
  Counts the total number of workouts for the current user.
  """
  def count_workouts(%Scope{user: user}) do
    from(w in Workout,
      where: w.user_id == ^user.id,
      select: count(w.id)
    )
    |> Repo.one()
  end

  def count_workouts(_), do: 0

  @doc """
  Counts the number of workouts for the current week.
  """
  def count_weekly_workouts(%Scope{user: user}) do
    start_of_week = Date.utc_today() |> Date.beginning_of_week()
    end_of_week = Date.utc_today() |> Date.end_of_week()

    from(w in Workout,
      where:
        w.user_id == ^user.id and
          fragment("DATE(?)", w.started_at) >= ^start_of_week and
          fragment("DATE(?)", w.started_at) <= ^end_of_week,
      select: count(w.id)
    )
    |> Repo.one()
  end

  def count_weekly_workouts(_), do: 0

  @doc """
  Returns personal bests for each exercise for the current user.
  """
  def list_personal_bests(%Scope{user: user}) do
    from(ws in WorkoutSet,
      join: wsession in assoc(ws, :workout),
      join: e in assoc(ws, :exercise),
      where: wsession.user_id == ^user.id and e.user_id == ^user.id,
      group_by: [e.id, e.name],
      select: %{
        exercise_id: e.id,
        exercise_name: e.name,
        weight: max(ws.weight),
        reps: max(ws.reps),
        date: max(ws.inserted_at)
      },
      order_by: [desc: max(ws.weight)]
    )
    |> Repo.all()
  end

  def list_personal_bests(_), do: []

  @doc """
  Returns volume data over time for the current user.
  """
  def volume_over_time(scope, days \\ 30)

  def volume_over_time(%Scope{user: user}, days) do
    start_date = Date.utc_today() |> Date.add(-days)

    from(ws in WorkoutSet,
      join: wsession in assoc(ws, :workout),
      where:
        wsession.user_id == ^user.id and
          fragment("DATE(?)", ws.inserted_at) >= ^start_date,
      group_by: fragment("DATE(?)", ws.inserted_at),
      select: %{
        date: fragment("DATE(?)", ws.inserted_at),
        volume: sum(ws.weight * ws.reps)
      },
      order_by: fragment("DATE(?)", ws.inserted_at)
    )
    |> Repo.all()
  end

  def volume_over_time(_, _days), do: []

  @doc """
  Returns recent personal bests for the current user.
  """
  def recent_personal_bests(scope, opts \\ [])

  def recent_personal_bests(%Scope{user: user}, opts) do
    limit = Keyword.get(opts, :limit, 10)

    # Get personal bests with their latest date
    from(ws in WorkoutSet,
      join: wsession in assoc(ws, :workout),
      join: e in assoc(ws, :exercise),
      where: wsession.user_id == ^user.id and e.user_id == ^user.id,
      group_by: [e.id, e.name],
      select: %{
        exercise_name: e.name,
        weight: max(ws.weight),
        reps: max(ws.reps),
        date: max(ws.inserted_at)
      },
      order_by: [desc: max(ws.inserted_at)],
      limit: ^limit
    )
    |> Repo.all()
  end

  def recent_personal_bests(_, _opts), do: []

  @doc """
  Returns workout dates for a given month for the current user.
  """
  def workout_dates_in_month(%Scope{user: user}, start_date, end_date) do
    from(w in Workout,
      where:
        w.user_id == ^user.id and
          fragment("DATE(?)", w.started_at) >= ^start_date and
          fragment("DATE(?)", w.started_at) <= ^end_date,
      select: fragment("DATE(?)", w.started_at)
    )
    |> Repo.all()
  end

  def workout_dates_in_month(_, _start_date, _end_date), do: []
end
