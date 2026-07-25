defmodule FittrackWeb.Api.V1.JSONHelpers do
  @moduledoc false

  alias Ecto.Changeset
  alias Fittrack.Training
  alias Fittrack.Training.Exercise
  alias Fittrack.Training.ExerciseMedia
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.Workout
  alias Fittrack.Training.WorkoutSet

  def pagination(%{
        page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: total_pages
      }) do
    %{
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  def user_json(user) do
    %{
      id: user.id,
      email: user.email,
      confirmed_at: datetime(user.confirmed_at)
    }
  end

  def exercise_json(%Exercise{} = exercise, conn) do
    exercise = preload_source_template(exercise)

    %{
      id: exercise.id,
      name: exercise.name,
      primary_muscle: exercise.primary_muscle,
      secondary_muscles: exercise.secondary_muscles || [],
      equipment: exercise.equipment,
      notes: exercise.notes,
      instructions: exercise.instructions,
      slug: exercise.slug,
      is_custom: exercise.is_custom,
      is_private: exercise.is_private,
      movement_pattern: exercise.movement_pattern,
      exercise_category: exercise.exercise_category,
      training_style_tags: exercise.training_style_tags || [],
      source_template_id: exercise.source_template_id,
      media: source_template_media(exercise.source_template, conn),
      inserted_at: datetime(exercise.inserted_at),
      updated_at: datetime(exercise.updated_at)
    }
  end

  def exercise_template_json(%ExerciseTemplate{} = template, conn) do
    template = preload_template_media(template)

    %{
      id: template.id,
      name: template.name,
      primary_muscle: template.primary_muscle,
      secondary_muscles: template.secondary_muscles || [],
      equipment: template.equipment,
      difficulty: template.difficulty,
      notes: template.notes,
      slug: template.slug,
      canonical_slug: template.canonical_slug,
      weighted_tags: template.weighted_tags || [],
      is_verified: template.is_verified,
      movement_pattern: template.movement_pattern,
      exercise_category: template.exercise_category,
      training_style_tags: template.training_style_tags || [],
      media: media_json(Training.cached_media(template), conn),
      inserted_at: datetime(template.inserted_at),
      updated_at: datetime(template.updated_at)
    }
  end

  def workout_json(%Workout{} = workout, conn) do
    workout_sets =
      if Ecto.assoc_loaded?(workout.workout_sets), do: workout.workout_sets, else: []

    %{
      id: workout.id,
      started_at: datetime(workout.started_at),
      notes: workout.notes,
      status: if(workout_sets == [], do: "active", else: "completed"),
      sets: Enum.map(workout_sets, &workout_set_json(&1, conn)),
      inserted_at: datetime(workout.inserted_at),
      updated_at: datetime(workout.updated_at)
    }
  end

  def workout_set_json(%WorkoutSet{} = workout_set, conn) do
    exercise =
      if Ecto.assoc_loaded?(workout_set.exercise), do: workout_set.exercise, else: nil

    %{
      id: workout_set.id,
      workout_id: workout_set.workout_session_id,
      exercise_id: workout_set.exercise_id,
      exercise: if(exercise, do: exercise_json(exercise, conn)),
      weight: decimal(workout_set.weight),
      reps: workout_set.reps,
      rpe: decimal(workout_set.rpe),
      rest_seconds: workout_set.rest_seconds,
      notes: workout_set.notes,
      kind: workout_set.kind,
      inserted_at: datetime(workout_set.inserted_at),
      updated_at: datetime(workout_set.updated_at)
    }
  end

  def changeset_errors(%Changeset{} = changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts
        |> Enum.find_value(key, fn {opt_key, value} ->
          if Atom.to_string(opt_key) == key, do: value
        end)
        |> to_string()
      end)
    end)
  end

  defp preload_source_template(%Exercise{} = exercise) do
    if Ecto.assoc_loaded?(exercise.source_template) do
      exercise
    else
      Fittrack.Repo.preload(exercise, source_template: :media)
    end
  end

  defp preload_template_media(%ExerciseTemplate{} = template) do
    if Ecto.assoc_loaded?(template.media) do
      template
    else
      Fittrack.Repo.preload(template, :media)
    end
  end

  defp source_template_media(%ExerciseTemplate{} = template, conn) do
    media_json(Training.cached_media(template), conn)
  end

  defp source_template_media(_, _conn), do: []

  defp media_json(media, conn) do
    Enum.map(media, fn %ExerciseMedia{} = media ->
      %{
        id: media.id,
        kind: media.kind,
        url:
          "#{conn.script_name |> Enum.map_join("/", &URI.encode/1)}/exercise-media/#{media.id}",
        mime_type: media.mime_type,
        width: media.width,
        height: media.height,
        duration_seconds: media.duration_seconds,
        file_size: media.file_size,
        cached_at: datetime(media.cached_at),
        provider_attribution: media.provider_attribution
      }
    end)
  end

  defp datetime(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp datetime(%NaiveDateTime{} = datetime),
    do: datetime |> DateTime.from_naive!("Etc/UTC") |> datetime()

  defp datetime(nil), do: nil

  defp decimal(%Decimal{} = decimal), do: Decimal.to_string(decimal, :normal)
  defp decimal(nil), do: nil
  defp decimal(value), do: value
end
