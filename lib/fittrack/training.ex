defmodule Fittrack.Training do
  @moduledoc """
  The Training context.
  """

  import Ecto.Query, warn: false

  alias Fittrack.Accounts.Scope
  alias Fittrack.Repo
  alias Fittrack.Training.Exercise
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.WorkoutSession
  alias Fittrack.Training.WorkoutSet

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

    ExerciseTemplate
    |> maybe_filter_templates(search)
    |> order_by([template], asc: template.name)
    |> Repo.all()
  end

  @doc """
  Creates a user exercise from a shared template.
  """
  def add_template_to_user(scope, template_id)

  def add_template_to_user(%Scope{user: user}, template_id) do
    with %ExerciseTemplate{} = template <- Repo.get(ExerciseTemplate, template_id) do
      case Repo.get_by(Exercise, user_id: user.id, name: template.name, equipment: template.equipment) do
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
  Returns the list of workout sessions for the current user.
  """
  def list_workout_sessions(%Scope{user: user}) do
    WorkoutSession
    |> where([session], session.user_id == ^user.id)
    |> order_by([session], desc: session.started_at)
    |> Repo.all()
  end

  def list_workout_sessions(_), do: []

  @doc """
  Gets a workout session with sets for the current user.
  """
  def get_workout_session!(%Scope{user: user}, id) do
    WorkoutSession
    |> where([session], session.id == ^id and session.user_id == ^user.id)
    |> Repo.one!()
    |> Repo.preload(workout_sets: workout_sets_query("oldest"))
  end

  @doc """
  Lists workout sets for a session for the current user with multiple sort options.
  """
  def list_workout_sets(scope, session, opts \\ %{})

  def list_workout_sets(%Scope{user: user}, %WorkoutSession{} = session, opts) do
    sort = Map.get(opts, :sort, "newest")

    if session.user_id == user.id do
      Repo.all(workout_sets_query(sort, session.id))
    else
      []
    end
  end

  def list_workout_sets(_, _, _opts), do: []

  @doc """
  Creates a workout session scoped to the current user.
  """
  def create_workout_session(%Scope{user: user}, attrs) do
    %WorkoutSession{}
    |> WorkoutSession.changeset(attrs)
    |> Ecto.Changeset.put_change(:user_id, user.id)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking workout session changes.
  """
  def change_workout_session(%WorkoutSession{} = workout_session, attrs \\ %{}) do
    WorkoutSession.changeset(workout_session, attrs)
  end

  @doc """
  Creates a workout set within a session for the current user.
  """
  def create_workout_set(%Scope{user: user}, %WorkoutSession{} = session, attrs) do
    exercise_id = Map.get(attrs, "exercise_id") || Map.get(attrs, :exercise_id)

    with true <- session.user_id == user.id,
         %Exercise{} <- Repo.get_by(Exercise, id: exercise_id, user_id: user.id) do
      %WorkoutSet{}
      |> WorkoutSet.changeset(attrs)
      |> Ecto.Changeset.put_change(:workout_session_id, session.id)
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
        ilike(exercise.equipment, ^like)
    )
  end

  defp maybe_filter_templates(query, search) when search in [nil, ""], do: query

  defp maybe_filter_templates(query, search) do
    like = "%#{search}%"

    where(
      query,
      [template],
      ilike(template.name, ^like) or ilike(template.primary_muscle, ^like) or
        ilike(template.equipment, ^like)
    )
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
end
