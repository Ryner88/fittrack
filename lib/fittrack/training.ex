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

  @goal_preferences ~w(strength hypertrophy endurance fat_loss general)
  @training_style_preferences ~w(cardio strength hypertrophy isometric speed power plyometric mobility conditioning core balance functional bodybuilding calisthenics)
  @training_split_preferences ~w(full_body upper_lower push_pull_legs body_part_split athletic_performance circuit_based strength_focused hybrid)
  @equipment_aliases %{
    "bodyweight" => ["bodyweight", "body weight"],
    "dumbbell" => ["dumbbell", "dumbbells"],
    "barbell" => ["barbell", "barbells"],
    "bench" => ["bench", "benches"],
    "machine" => ["machine", "machines"],
    "kettlebell" => ["kettlebell", "kettlebells"],
    "band" => ["band", "bands", "resistance band", "resistance bands"],
    "cable" => ["cable", "cables", "cable machine", "cable machines"],
    "pull-up bar" => ["pull-up bar", "pull up bar", "pullup bar"],
    "cardio machine" => [
      "cardio machine",
      "cardio machines",
      "treadmill",
      "bike",
      "stationary bike",
      "elliptical",
      "rower",
      "rowing machine",
      "stair climber"
    ]
  }

  @doc """
  Returns the list of exercises for the current user.
  """
  def list_exercises(scope, opts \\ %{})

  def list_exercises(%Scope{user: user}, opts) do
    search = Map.get(opts, :search)
    search = if is_binary(search), do: String.trim(search), else: search

    equipment = Map.get(opts, :equipment)

    Exercise
    |> where([exercise], exercise.user_id == ^user.id)
    |> maybe_filter_exercises(search)
    |> maybe_filter_exercises_by_equipment(equipment)
    |> order_by([exercise], asc: exercise.name)
    |> maybe_preload_source_template(Map.get(opts, :preload_source_template, false))
    |> Repo.all()
  end

  def list_exercises(_, _opts), do: []

  @doc """
  Gets a single exercise for the current user.
  """
  def get_exercise!(scope, id, opts \\ [])

  def get_exercise!(%Scope{user: user}, id, opts) do
    Exercise
    |> where([exercise], exercise.id == ^id and exercise.user_id == ^user.id)
    |> maybe_preload_source_template(Keyword.get(opts, :preload_source_template, false))
    |> Repo.one!()
  end

  def get_exercise(%Scope{user: user}, id) do
    Repo.get_by(Exercise, id: id, user_id: user.id)
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
  Gets a shared exercise template by id.
  """
  def get_exercise_template(id) do
    Repo.get(ExerciseTemplate, id)
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
            notes: template.notes,
            source_template_id: template.id
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
  Returns the most recent active workout for the current user.

  Until workouts have an explicit finished state, a workout with no logged sets is treated as
  active/in-progress.
  """
  def get_active_workout(%Scope{user: user}) do
    Workout
    |> where([workout], workout.user_id == ^user.id)
    |> join(:left, [workout], workout_set in assoc(workout, :workout_sets))
    |> group_by([workout], workout.id)
    |> having([_workout, workout_set], count(workout_set.id) == 0)
    |> order_by([workout], desc: workout.started_at)
    |> limit(1)
    |> preload(workout_sets: [:exercise])
    |> Repo.one()
  end

  def get_active_workout(_), do: nil

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
      |> Ecto.Changeset.put_change(:workout_session_id, workout.id)
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

  defp maybe_filter_exercises_by_equipment(query, nil), do: query
  defp maybe_filter_exercises_by_equipment(query, []), do: query

  defp maybe_filter_exercises_by_equipment(query, equipment) when is_list(equipment) do
    equipment_terms =
      equipment
      |> equipment_filter_terms()
      |> then(&Enum.uniq(["bodyweight" | &1]))

    where(query, [exercise], fragment("lower(?)", exercise.equipment) in ^equipment_terms)
  end

  defp maybe_filter_exercises_by_equipment(query, _), do: query

  defp maybe_preload_source_template(query, true), do: preload(query, :source_template)
  defp maybe_preload_source_template(query, _), do: query

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
    equipment_terms = equipment_filter_terms(equipment)

    if equipment_terms == [] do
      query
    else
      where(query, [template], fragment("lower(?)", template.equipment) in ^equipment_terms)
    end
  end

  defp maybe_filter_by_difficulty(query, nil), do: query

  defp maybe_filter_by_difficulty(query, difficulty) do
    where(query, [template], template.difficulty == ^difficulty)
  end

  @doc """
  Generates an AI-powered 4-week workout plan based on user input, saves it to the current user account.
  """
  def generate_ai_workout_plan(%Scope{} = scope, attrs) when is_map(attrs) do
    primary_goal =
      (Map.get(attrs, "primary_goal") || Map.get(attrs, "goal") || "general")
      |> normalize_goal_preference("general")

    secondary_goal = Map.get(attrs, "secondary_goal") |> normalize_goal_preference()
    tertiary_goal = Map.get(attrs, "tertiary_goal") |> normalize_goal_preference()
    additional_goal = Map.get(attrs, "additional_goal") |> normalize_goal_preference()
    experience = Map.get(attrs, "experience", "beginner") |> String.downcase()

    training_styles =
      Map.get(attrs, "training_styles", [])
      |> normalize_multi_select(@training_style_preferences)

    training_split =
      Map.get(attrs, "training_split", [])
      |> normalize_multi_select(@training_split_preferences)

    equipment = normalize_equipment_input(Map.get(attrs, "equipment", []))

    days_per_week =
      attrs
      |> Map.get("days_per_week", 4)
      |> parse_int(4)

    with :ok <-
           validate_unique_goals([
             primary_goal,
             secondary_goal,
             tertiary_goal,
             additional_goal
           ]),
         {:ok, days} <- validate_days_per_week(days_per_week),
         {:ok, exercises} <- fetch_ai_exercises(scope, equipment, experience),
         false <- Enum.empty?(exercises) do
      sets = experience_to_sets(experience)
      rest_seconds = experience_to_rest(experience)
      {min_reps, max_reps} = goal_to_rep_range(primary_goal)

      schedule_days = days_for_week(days)

      workout_plan_exercises =
        build_workout_plan_exercises(
          exercises,
          schedule_days,
          sets,
          min_reps,
          max_reps,
          rest_seconds
        )

      plan_name = "AI Workout Plan (#{goal_label(primary_goal)}) - #{Date.utc_today()}"

      plan_description =
        [
          "4-week automatically generated plan.",
          "Goals (priority order): #{format_goal_preferences([primary_goal, secondary_goal, tertiary_goal, additional_goal])}",
          "Experience: #{String.capitalize(experience)}",
          "Equipment: #{format_equipment_preferences(equipment)}",
          maybe_preference_line("Training Styles", training_styles, &training_style_label/1),
          maybe_preference_line("Training Split", training_split, &training_split_label/1),
          "",
          "Follow this weekly workout cycle for 4 weeks and progress weights each week."
        ]
        |> Enum.reject(&is_nil/1)
        |> Enum.join("\n")

      create_workout_plan(scope, %{
        "name" => plan_name,
        "description" => String.trim(plan_description),
        "goal" => primary_goal,
        "primary_goal" => primary_goal,
        "secondary_goal" => secondary_goal,
        "tertiary_goal" => tertiary_goal,
        "additional_goal" => additional_goal,
        "primary_style" => goal_to_primary_style(primary_goal),
        "secondary_style_tags" => secondary_style_tags(training_styles),
        "training_styles" => training_styles,
        "training_split" => training_split,
        "difficulty" => experience_to_difficulty(experience),
        "estimated_duration_minutes" => 45,
        "workout_plan_exercises" => workout_plan_exercises
      })
    else
      [] ->
        {:error,
         "No exercises available to generate plan. Add exercises or expand equipment options."}

      {:error, msg} ->
        {:error, msg}
    end
  end

  def generate_ai_workout_plan(_, _), do: {:error, "Unauthorized"}

  defp normalize_goal_preference(value, default \\ nil)
  defp normalize_goal_preference(nil, default), do: default

  defp normalize_goal_preference(value, default) do
    normalized =
      value
      |> to_string()
      |> String.trim()
      |> String.downcase()

    cond do
      normalized == "" -> default
      normalized in @goal_preferences -> normalized
      true -> default
    end
  end

  defp validate_unique_goals(goals) do
    goals = Enum.reject(goals, &is_nil/1)

    if Enum.uniq(goals) == goals do
      :ok
    else
      {:error, "Each goal must be unique."}
    end
  end

  defp normalize_multi_select(values, allowed_values) when is_binary(values) do
    values
    |> String.split(",", trim: true)
    |> normalize_multi_select(allowed_values)
  end

  defp normalize_multi_select(values, allowed_values) when is_list(values) do
    values
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.downcase/1)
    |> Enum.filter(&(&1 in allowed_values))
    |> Enum.uniq()
  end

  defp normalize_multi_select(_, _allowed_values), do: []

  defp normalize_equipment_input(equipment) when is_binary(equipment) do
    equipment
    |> String.split(",", trim: true)
    |> normalize_equipment_input()
  end

  defp normalize_equipment_input(equipment) when is_list(equipment) do
    equipment
    |> Enum.map(&normalize_equipment_value/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp normalize_equipment_input(_), do: []

  defp normalize_equipment_value(nil), do: nil

  defp normalize_equipment_value(value) do
    normalized =
      value
      |> to_string()
      |> String.trim()
      |> String.downcase()

    cond do
      normalized == "" ->
        nil

      true ->
        Enum.find_value(@equipment_aliases, normalized, fn {canonical, aliases} ->
          if normalized == canonical or normalized in aliases, do: canonical
        end)
    end
  end

  defp equipment_filter_terms(equipment) when is_list(equipment) do
    equipment
    |> Enum.flat_map(&equipment_filter_terms/1)
    |> Enum.uniq()
  end

  defp equipment_filter_terms(equipment) do
    canonical = normalize_equipment_value(equipment)

    if canonical do
      Map.get(@equipment_aliases, canonical, [canonical])
    else
      []
    end
  end

  defp parse_int(value, _default) when is_integer(value), do: value

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_int(_, default), do: default

  defp validate_days_per_week(days) when days in 1..7, do: {:ok, days}
  defp validate_days_per_week(_), do: {:error, "Days per week must be between 1 and 7"}

  defp fetch_ai_exercises(scope, equipment, _experience) do
    exercises = list_exercises(scope, %{equipment: equipment})
    exercises = if exercises == [], do: list_exercises(scope), else: exercises

    if exercises != [] do
      {:ok, exercises}
    else
      templates =
        case equipment do
          [] ->
            list_exercise_templates()

          _ ->
            equipment
            |> Enum.map(fn eq -> list_exercise_templates(%{equipment: eq}) end)
            |> List.flatten()
        end

      templates = Enum.uniq_by(templates, & &1.name)

      if templates == [] do
        {:error, "No exercise templates available for selected equipment"}
      else
        created_exercises =
          templates
          |> Enum.map(fn template ->
            {:ok, exercise} = add_template_to_user(scope, template.id)
            exercise
          end)

        {:ok, created_exercises}
      end
    end
  end

  defp secondary_style_tags(training_styles) do
    training_styles
    |> Enum.flat_map(fn
      "strength" -> ["strength"]
      "hypertrophy" -> ["hypertrophy"]
      "conditioning" -> ["conditioning"]
      "mobility" -> ["mobility"]
      "bodybuilding" -> ["bodybuilding"]
      "calisthenics" -> ["calisthenics"]
      _ -> []
    end)
    |> Enum.uniq()
  end

  defp format_goal_preferences(goals) do
    goals
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&goal_label/1)
    |> Enum.join(" -> ")
  end

  defp format_equipment_preferences([]), do: "Any available equipment"

  defp format_equipment_preferences(equipment) do
    equipment
    |> Enum.map(&equipment_label/1)
    |> Enum.join(", ")
  end

  defp maybe_preference_line(_label, [], _formatter), do: nil

  defp maybe_preference_line(label, values, formatter) do
    "#{label}: #{Enum.map(values, formatter) |> Enum.join(", ")}"
  end

  defp goal_label("general"), do: "General Fitness"
  defp goal_label(value), do: humanize_choice(value)
  defp training_style_label(value), do: humanize_choice(value)

  defp training_split_label("upper_lower"), do: "Upper / Lower"
  defp training_split_label("push_pull_legs"), do: "Push / Pull / Legs"
  defp training_split_label("body_part_split"), do: "Body Part Split"
  defp training_split_label("athletic_performance"), do: "Athletic Performance"
  defp training_split_label("circuit_based"), do: "Circuit Based"
  defp training_split_label("strength_focused"), do: "Strength Focused"
  defp training_split_label(value), do: humanize_choice(value)

  defp equipment_label("bodyweight"), do: "Bodyweight"
  defp equipment_label("dumbbell"), do: "Dumbbells"
  defp equipment_label("barbell"), do: "Barbell"
  defp equipment_label("bench"), do: "Bench"
  defp equipment_label("machine"), do: "Machines"
  defp equipment_label("kettlebell"), do: "Kettlebells"
  defp equipment_label("band"), do: "Resistance Bands"
  defp equipment_label("cable"), do: "Cable Machine"
  defp equipment_label("pull-up bar"), do: "Pull-Up Bar"
  defp equipment_label("cardio machine"), do: "Cardio Machines"
  defp equipment_label(value), do: humanize_choice(value)

  defp humanize_choice(value) do
    value
    |> String.replace("_", " ")
    |> String.replace("-", " ")
    |> String.split(" ", trim: true)
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp goal_to_primary_style("strength"), do: "strength"
  defp goal_to_primary_style("hypertrophy"), do: "hypertrophy"
  defp goal_to_primary_style("endurance"), do: "conditioning"
  defp goal_to_primary_style("fat_loss"), do: "conditioning"
  defp goal_to_primary_style("general"), do: "bodybuilding"
  defp goal_to_primary_style(_), do: "bodybuilding"

  defp experience_to_difficulty("beginner"), do: "beginner"
  defp experience_to_difficulty("intermediate"), do: "intermediate"
  defp experience_to_difficulty("advanced"), do: "advanced"
  defp experience_to_difficulty(_), do: "beginner"

  defp experience_to_sets("beginner"), do: 3
  defp experience_to_sets("intermediate"), do: 4
  defp experience_to_sets("advanced"), do: 5
  defp experience_to_sets(_), do: 3

  defp experience_to_rest("beginner"), do: 60
  defp experience_to_rest("intermediate"), do: 90
  defp experience_to_rest("advanced"), do: 120
  defp experience_to_rest(_), do: 75

  defp goal_to_rep_range("strength"), do: {4, 6}
  defp goal_to_rep_range("hypertrophy"), do: {8, 12}
  defp goal_to_rep_range("endurance"), do: {12, 20}
  defp goal_to_rep_range("fat_loss"), do: {10, 15}
  defp goal_to_rep_range(_), do: {8, 12}

  defp days_for_week(1), do: ["Monday"]
  defp days_for_week(2), do: ["Monday", "Thursday"]
  defp days_for_week(3), do: ["Monday", "Wednesday", "Friday"]
  defp days_for_week(4), do: ["Monday", "Tuesday", "Thursday", "Friday"]
  defp days_for_week(5), do: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
  defp days_for_week(6), do: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

  defp days_for_week(7),
    do: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

  defp build_workout_plan_exercises(
         exercises,
         schedule_days,
         sets,
         min_reps,
         max_reps,
         rest_seconds
       ) do
    # Use a dynamic daily exercise list and rotate through the pool for variety.
    pool_exercises = Enum.shuffle(exercises)

    exercises_per_day =
      cond do
        length(pool_exercises) >= 6 -> 5
        length(pool_exercises) >= 4 -> 4
        true -> min(length(pool_exercises), 3)
      end

    schedule_days
    |> Enum.with_index()
    |> Enum.flat_map(fn {day, day_idx} ->
      day_exercises =
        pool_exercises
        |> Enum.drop(rem(day_idx * exercises_per_day, max(1, length(pool_exercises))))
        |> Enum.take(exercises_per_day)

      day_exercises
      |> Enum.with_index(1)
      |> Enum.map(fn {exercise, idx} ->
        %{
          position: day_idx * exercises_per_day + idx,
          exercise_id: exercise.id,
          target_sets: sets,
          target_reps_min: min_reps,
          target_reps_max: max_reps,
          rest_seconds: rest_seconds,
          scheduled_day: day,
          notes: "Week 1-4: same structure. Increase load 2.5-5% each week."
        }
      end)
    end)
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
        started_at: DateTime.utc_now() |> DateTime.truncate(:second),
        notes: "Started from plan: #{workout_plan.name}"
      })

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
      join: ws in assoc(w, :workout_sets),
      where: w.user_id == ^user.id,
      select: count(w.id, :distinct)
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
      join: ws in assoc(w, :workout_sets),
      where:
        w.user_id == ^user.id and
          fragment("DATE(?)", w.started_at) >= ^start_of_week and
          fragment("DATE(?)", w.started_at) <= ^end_of_week,
      select: count(w.id, :distinct)
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
  Returns exercise progress line points for a given exercise.
  """
  def exercise_progress_over_time(scope, exercise_id, days \\ 30)

  def exercise_progress_over_time(%Scope{user: user}, exercise_id, days) do
    start_date = Date.utc_today() |> Date.add(-days)

    from(ws in WorkoutSet,
      join: w in assoc(ws, :workout),
      where:
        w.user_id == ^user.id and ws.exercise_id == ^exercise_id and
          fragment("DATE(?)", ws.inserted_at) >= ^start_date,
      group_by: fragment("DATE(?)", ws.inserted_at),
      select: %{
        date: fragment("DATE(?)", ws.inserted_at),
        avg_weight: avg(ws.weight),
        max_weight: max(ws.weight),
        total_reps: sum(ws.reps)
      },
      order_by: fragment("DATE(?)", ws.inserted_at)
    )
    |> Repo.all()
  end

  def exercise_progress_over_time(_, _exercise_id, _days), do: []

  @doc """
  Logs a single set for fast dashboard entry.
  """
  def log_exercise_set(%Scope{} = scope, %{
        "exercise_id" => exercise_id,
        "weight" => weight,
        "reps" => reps
      }) do
    case get_exercise(scope, exercise_id) do
      nil ->
        {:error, :unauthorized}

      _exercise ->
        with {:ok, workout} <-
               create_workout(scope, %{
                 started_at: DateTime.utc_now(),
                 notes: "Quick Log: #{Date.utc_today()}"
               }),
             {:ok, workout_set} <-
               create_workout_set(scope, workout, %{
                 exercise_id: exercise_id,
                 weight: weight,
                 reps: reps,
                 kind: "normal"
               }) do
          {:ok, workout_set}
        else
          error -> error
        end
    end
  end

  @doc """
  Returns workout dates for a given month for the current user.
  """
  def workout_dates_in_month(%Scope{user: user}, start_date, end_date) do
    from(w in Workout,
      join: ws in assoc(w, :workout_sets),
      where:
        w.user_id == ^user.id and
          fragment("DATE(?)", w.started_at) >= ^start_date and
          fragment("DATE(?)", w.started_at) <= ^end_date,
      select: fragment("DATE(?)", w.started_at)
    )
    |> Repo.all()
  end

  def workout_dates_in_month(_, _start_date, _end_date), do: []

  @doc """
  Returns workout dates and session counts for a given month.
  """
  def workout_dates_in_month_with_counts(%Scope{user: user}, start_date, end_date) do
    from(w in Workout,
      join: ws in assoc(w, :workout_sets),
      where:
        w.user_id == ^user.id and
          fragment("DATE(?)", w.started_at) >= ^start_date and
          fragment("DATE(?)", w.started_at) <= ^end_date,
      group_by: fragment("DATE(?)", w.started_at),
      select: %{date: fragment("DATE(?)", w.started_at), count: count(w.id, :distinct)}
    )
    |> Repo.all()
  end

  def workout_dates_in_month_with_counts(_, _start_date, _end_date), do: []

  @doc """
  Lists workouts for a current user within a date range.
  Accepts Date or DateTime boundaries.
  """
  def list_workouts_in_date_range(%Scope{user: user}, %Date{} = start_date, %Date{} = end_date) do
    from(w in Workout,
      where:
        w.user_id == ^user.id and
          fragment("DATE(?)", w.started_at) >= ^start_date and
          fragment("DATE(?)", w.started_at) <= ^end_date,
      order_by: [desc: w.started_at],
      preload: [:workout_sets]
    )
    |> Repo.all()
  end

  def list_workouts_in_date_range(
        %Scope{user: user},
        %DateTime{} = start_dt,
        %DateTime{} = end_dt
      ) do
    from(w in Workout,
      where:
        w.user_id == ^user.id and
          w.started_at >= ^start_dt and
          w.started_at <= ^end_dt,
      order_by: [desc: w.started_at],
      preload: [:workout_sets]
    )
    |> Repo.all()
  end

  def list_workouts_in_date_range(_, _, _), do: []

  @doc """
  Returns completed workout dates and session counts for a given date range.
  """
  def completed_workout_dates_with_counts(%Scope{user: user}, start_date, end_date) do
    from(w in Workout,
      join: ws in assoc(w, :workout_sets),
      where:
        w.user_id == ^user.id and
          fragment("DATE(?)", w.started_at) >= ^start_date and
          fragment("DATE(?)", w.started_at) <= ^end_date,
      group_by: fragment("DATE(?)", w.started_at),
      select: %{date: fragment("DATE(?)", w.started_at), count: count(w.id, :distinct)}
    )
    |> Repo.all()
  end

  def completed_workout_dates_with_counts(_, _start_date, _end_date), do: []

  @doc """
  Lists completed workouts for a current user within a date range.
  """
  def list_completed_workouts_in_date_range(
        %Scope{user: user},
        %Date{} = start_date,
        %Date{} = end_date
      ) do
    from(w in Workout,
      join: ws in assoc(w, :workout_sets),
      where:
        w.user_id == ^user.id and
          fragment("DATE(?)", w.started_at) >= ^start_date and
          fragment("DATE(?)", w.started_at) <= ^end_date,
      distinct: w.id,
      order_by: [desc: w.started_at],
      preload: [workout_sets: :exercise]
    )
    |> Repo.all()
  end

  def list_completed_workouts_in_date_range(_, _, _), do: []

  @doc """
  Returns distinct completed workout dates for the current user.
  """
  def list_completed_workout_dates(%Scope{user: user}) do
    from(w in Workout,
      join: ws in assoc(w, :workout_sets),
      where: w.user_id == ^user.id,
      distinct: true,
      select: fragment("DATE(?)", w.started_at),
      order_by: [desc: fragment("DATE(?)", w.started_at)]
    )
    |> Repo.all()
  end

  def list_completed_workout_dates(_), do: []
end
