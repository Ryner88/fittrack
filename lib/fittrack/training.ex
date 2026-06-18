defmodule Fittrack.Training do
  @moduledoc """
  The Training context.
  """

  import Ecto.Query, warn: false

  alias Fittrack.Accounts.Scope
  alias Fittrack.Repo
  alias Fittrack.Training.Exercise
  alias Fittrack.Training.ExerciseAlias
  alias Fittrack.Training.ExerciseEquipment
  alias Fittrack.Training.ExerciseMedia
  alias Fittrack.Training.ExerciseMediaCache
  alias Fittrack.Training.ExerciseMuscle
  alias Fittrack.Training.ExerciseSubstitution
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.ExerciseTemplateEquipment
  alias Fittrack.Training.ExerciseTemplateMuscle
  alias Fittrack.Training.ExerciseTemplateSource
  alias Fittrack.Training.ExerciseVariation
  alias Fittrack.Training.Normalizer
  alias Fittrack.Training.OpenAIWorkoutParserClient
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

  def list_recent_exercises(scope, opts \\ %{})

  def list_recent_exercises(%Scope{user: user}, opts) do
    opts = if is_list(opts), do: Map.new(opts), else: opts
    limit = opts |> Map.get(:limit, 5) |> parse_positive_integer(5)

    recent_sets =
      WorkoutSet
      |> join(:inner, [workout_set], exercise in assoc(workout_set, :exercise))
      |> where([_workout_set, exercise], exercise.user_id == ^user.id)
      |> group_by([workout_set, _exercise], workout_set.exercise_id)
      |> select([workout_set, _exercise], %{
        exercise_id: workout_set.exercise_id,
        last_used_at: max(workout_set.inserted_at)
      })

    Exercise
    |> join(:inner, [exercise], recent in subquery(recent_sets),
      on: recent.exercise_id == exercise.id
    )
    |> order_by([_exercise, recent], desc: recent.last_used_at)
    |> limit(^limit)
    |> preload(source_template: :media)
    |> Repo.all()
  end

  def list_recent_exercises(_, _opts), do: []

  def list_popular_exercises(scope, opts \\ %{})

  def list_popular_exercises(%Scope{user: user}, opts) do
    opts = if is_list(opts), do: Map.new(opts), else: opts
    limit = opts |> Map.get(:limit, 5) |> parse_positive_integer(5)

    exercise_counts =
      WorkoutSet
      |> join(:inner, [workout_set], exercise in assoc(workout_set, :exercise))
      |> where([_workout_set, exercise], exercise.user_id == ^user.id)
      |> group_by([workout_set, _exercise], workout_set.exercise_id)
      |> select([workout_set, _exercise], %{
        exercise_id: workout_set.exercise_id,
        set_count: count(workout_set.id)
      })

    Exercise
    |> join(:inner, [exercise], counts in subquery(exercise_counts),
      on: counts.exercise_id == exercise.id
    )
    |> order_by([exercise, counts], desc: counts.set_count, asc: exercise.name)
    |> limit(^limit)
    |> preload(source_template: :media)
    |> Repo.all()
  end

  def list_popular_exercises(_, _opts), do: []

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

  def get_exercise(scope, id, opts \\ [])

  def get_exercise(%Scope{user: user}, id, opts) do
    Exercise
    |> where([exercise], exercise.id == ^id and exercise.user_id == ^user.id)
    |> maybe_preload_source_template(Keyword.get(opts, :preload_source_template, false))
    |> Repo.one()
  end

  def list_substitution_templates_for_exercise(scope, exercise_id, opts \\ %{})

  def list_substitution_templates_for_exercise(%Scope{user: user}, exercise_id, opts) do
    opts = if is_list(opts), do: Map.new(opts), else: opts
    limit = opts |> Map.get(:limit, 4) |> parse_positive_integer(4)

    with %Exercise{source_template_id: template_id} when not is_nil(template_id) <-
           Repo.get_by(Exercise, id: exercise_id, user_id: user.id) do
      ExerciseSubstitution
      |> where([substitution], substitution.exercise_template_id == ^template_id)
      |> order_by([substitution], asc: substitution.priority, asc: substitution.reason)
      |> limit(^limit)
      |> preload(:substitute_exercise_template)
      |> Repo.all()
      |> Enum.map(& &1.substitute_exercise_template)
    else
      _ -> []
    end
  end

  def list_substitution_templates_for_exercise(_, _exercise_id, _opts), do: []

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
    list_all_exercise_templates(opts)
  end

  def paginate_exercise_templates(opts \\ %{}) do
    search = Map.get(opts, :search)
    search = if is_binary(search), do: String.trim(search), else: search

    muscle_group = Map.get(opts, :muscle_group)
    equipment = Map.get(opts, :equipment)
    category = Map.get(opts, :category)
    difficulty = Map.get(opts, :difficulty)
    page = opts |> Map.get(:page, 1) |> parse_positive_integer(1)
    per_page = opts |> Map.get(:per_page, 24) |> parse_positive_integer(24) |> min(60)

    query =
      ExerciseTemplate
      |> maybe_filter_templates(search)
      |> maybe_filter_by_muscle_group(muscle_group)
      |> maybe_filter_by_equipment(equipment)
      |> maybe_filter_by_category(category)
      |> maybe_filter_by_difficulty(difficulty)

    total_count = Repo.aggregate(query, :count, :id)
    total_pages = max(ceil(total_count / per_page), 1)
    page = min(page, total_pages)

    templates =
      query
      |> order_by([template], asc: template.name)
      |> preload([
        :aliases,
        :media,
        template_muscles: [:exercise_muscle],
        template_equipment: [:exercise_equipment]
      ])
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      entries: templates,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  def exercise_template_filter_options do
    %{
      muscles:
        ExerciseMuscle
        |> order_by([muscle], asc: muscle.name)
        |> select([muscle], muscle.name)
        |> Repo.all(),
      equipment:
        ExerciseEquipment
        |> order_by([equipment], asc: equipment.name)
        |> select([equipment], equipment.name)
        |> Repo.all(),
      categories:
        ExerciseTemplate
        |> where(
          [template],
          not is_nil(template.exercise_category) and template.exercise_category != ""
        )
        |> distinct(true)
        |> order_by([template], asc: template.exercise_category)
        |> select([template], template.exercise_category)
        |> Repo.all(),
      difficulties: ["beginner", "intermediate", "advanced"]
    }
  end

  def admin_exercise_template_filter_options do
    base_options = exercise_template_filter_options()

    Map.merge(base_options, %{
      sources:
        ExerciseTemplateSource
        |> where([source], not is_nil(source.source) and source.source != "")
        |> distinct(true)
        |> order_by([source], asc: source.source)
        |> select([source], source.source)
        |> Repo.all(),
      tags:
        ExerciseTemplate
        |> where([template], not is_nil(template.weighted_tags))
        |> select([template], template.weighted_tags)
        |> Repo.all()
        |> List.flatten()
        |> Enum.reject(&(&1 in [nil, ""]))
        |> Enum.uniq()
        |> Enum.sort(),
      media_statuses: ["missing_media" | ExerciseMedia.cache_statuses()],
      review_statuses: ["needs_review", "verified", "archived", "ai_generated"]
    })
  end

  def paginate_admin_exercise_templates(opts \\ %{}) do
    opts = if is_list(opts), do: Map.new(opts), else: opts
    page = opts |> get_option(:page, 1) |> parse_positive_integer(1)
    per_page = opts |> get_option(:per_page, 20) |> parse_positive_integer(20) |> min(100)

    query =
      ExerciseTemplate
      |> maybe_filter_admin_templates(get_option(opts, :search))
      |> maybe_filter_by_muscle_group(get_option(opts, :muscle_group))
      |> maybe_filter_by_equipment(get_option(opts, :equipment))
      |> maybe_filter_by_category(get_option(opts, :category))
      |> maybe_filter_by_difficulty(get_option(opts, :difficulty))
      |> maybe_filter_by_source(get_option(opts, :source))
      |> maybe_filter_by_tag(get_option(opts, :tag))
      |> maybe_filter_by_media_status(get_option(opts, :media_status))
      |> maybe_filter_by_review_status(get_option(opts, :review_status))

    total_count = Repo.aggregate(query, :count, :id)
    total_pages = max(ceil(total_count / per_page), 1)
    page = min(page, total_pages)

    preloads = admin_template_preloads()

    templates =
      query
      |> order_by([template], desc: template.updated_at, asc: template.name)
      |> preload(^preloads)
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      entries: templates,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  def list_matching_exercise_templates(search, opts \\ %{}) do
    opts = if is_list(opts), do: Map.new(opts), else: opts

    search_exercise_templates(search, opts)
    |> Repo.preload([
      :aliases,
      :media,
      template_muscles: [:exercise_muscle],
      template_equipment: [:exercise_equipment]
    ])
  end

  def list_all_exercise_templates(opts \\ %{}) do
    search = Map.get(opts, :search)
    search = if is_binary(search), do: String.trim(search), else: search

    muscle_group = Map.get(opts, :muscle_group)
    equipment = Map.get(opts, :equipment)
    category = Map.get(opts, :category)
    difficulty = Map.get(opts, :difficulty)

    ExerciseTemplate
    |> maybe_filter_templates(search)
    |> maybe_filter_by_muscle_group(muscle_group)
    |> maybe_filter_by_equipment(equipment)
    |> maybe_filter_by_category(category)
    |> maybe_filter_by_difficulty(difficulty)
    |> order_by([template], asc: template.name)
    |> preload(:media)
    |> Repo.all()
  end

  @doc """
  Gets a shared exercise template by id.
  """
  def get_exercise_template(id) do
    ExerciseTemplate
    |> preload(:media)
    |> Repo.get(id)
  end

  def get_admin_exercise_template!(id) do
    preloads = admin_template_preloads()

    ExerciseTemplate
    |> preload(^preloads)
    |> Repo.get!(id)
  end

  def admin_exercise_media_filter_options do
    %{
      statuses: ExerciseMedia.cache_statuses(),
      sources:
        ExerciseMedia
        |> where([media], not is_nil(media.source) and media.source != "")
        |> distinct(true)
        |> order_by([media], asc: media.source)
        |> select([media], media.source)
        |> Repo.all()
    }
  end

  def paginate_admin_exercise_media(opts \\ %{}) do
    opts = if is_list(opts), do: Map.new(opts), else: opts
    page = opts |> get_option(:page, 1) |> parse_positive_integer(1)
    per_page = opts |> get_option(:per_page, 50) |> parse_positive_integer(50) |> min(100)

    query =
      ExerciseMedia
      |> join(:inner, [media], template in assoc(media, :exercise_template))
      |> maybe_filter_media_report_by_status(get_option(opts, :status))
      |> maybe_filter_media_report_by_source(get_option(opts, :source))
      |> maybe_filter_media_report_by_search(get_option(opts, :search))

    total_count = Repo.aggregate(query, :count, :id)
    total_pages = max(ceil(total_count / per_page), 1)
    page = min(page, total_pages)

    entries =
      query
      |> order_by([media, template],
        desc: fragment("coalesce(?, ?, ?)", media.checked_at, media.cached_at, media.updated_at),
        asc: template.name,
        asc: media.id
      )
      |> preload([_media, template], exercise_template: template)
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      entries: entries,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  def change_exercise_template(%ExerciseTemplate{} = template, attrs \\ %{}) do
    ExerciseTemplate.changeset(template, attrs)
  end

  def create_exercise_template(attrs) when is_map(attrs) do
    {template_attrs, related_attrs} = split_admin_template_attrs(attrs)

    %ExerciseTemplate{}
    |> ExerciseTemplate.changeset(template_attrs)
    |> Repo.insert()
    |> sync_admin_template_relations(related_attrs)
  end

  def update_exercise_template(%ExerciseTemplate{} = template, attrs) when is_map(attrs) do
    {template_attrs, related_attrs} = split_admin_template_attrs(attrs)

    template
    |> ExerciseTemplate.changeset(template_attrs)
    |> Repo.update()
    |> sync_admin_template_relations(related_attrs)
  end

  def archive_exercise_template(%ExerciseTemplate{} = template) do
    template
    |> ExerciseTemplate.changeset(%{is_deprecated: true, is_verified: false})
    |> Repo.update()
  end

  def get_exercise_media(id) do
    Repo.get(ExerciseMedia, id)
  end

  def primary_cached_media(%ExerciseTemplate{} = template) do
    template
    |> cached_media()
    |> Enum.sort_by(fn media ->
      {not media.is_primary, media.display_order || 0, media.id || 0}
    end)
    |> List.first()
  end

  def primary_cached_media(%Exercise{} = exercise) do
    case Repo.preload(exercise, source_template: :media).source_template do
      %ExerciseTemplate{} = template -> primary_cached_media(template)
      _ -> nil
    end
  end

  def primary_cached_media(_value), do: nil

  def cached_media(%ExerciseTemplate{} = template) do
    media =
      case Ecto.assoc_loaded?(template.media) do
        true -> template.media
        false -> Repo.preload(template, :media).media
      end

    media
    |> Enum.filter(&(&1.cache_status == "cached" and is_binary(&1.local_path)))
    |> Enum.sort_by(&{&1.display_order || 0, &1.id || 0})
  end

  def cached_media(_template), do: []

  def exercise_media_path(%ExerciseMedia{local_path: local_path, cache_status: "cached"})
      when is_binary(local_path) do
    with {:ok, path} <- ExerciseMediaCache.safe_absolute_path(local_path),
         true <- File.regular?(path) do
      {:ok, path}
    else
      false -> {:error, :missing_file}
      {:error, reason} -> {:error, reason}
    end
  end

  def exercise_media_path(_media), do: {:error, :not_cached}

  def upsert_exercise_media(%ExerciseTemplate{} = template, attrs) do
    media =
      media_lookup(attrs) ||
        %ExerciseMedia{}

    attrs =
      attrs
      |> Map.put(:exercise_template_id, template.id)
      |> Map.put_new(:display_order, 0)
      |> preserve_cached_media_fields(media)

    media
    |> ExerciseMedia.changeset(attrs)
    |> Repo.insert_or_update()
  end

  def update_exercise_media(%ExerciseMedia{} = media, attrs) do
    media
    |> ExerciseMedia.changeset(attrs)
    |> Repo.update()
  end

  def find_template_for_wger_media(%{source_exercise_id: source_exercise_id})
      when is_binary(source_exercise_id) do
    with id when is_binary(id) <- source_exercise_id,
         {integer_id, ""} <- Integer.parse(id),
         %ExerciseTemplate{} = template <- Repo.get_by(ExerciseTemplate, source_id: integer_id) do
      template
    else
      _ ->
        Repo.one(
          from template in ExerciseTemplate,
            join: source in assoc(template, :template_sources),
            where:
              source.source == "wger" and source.external_id == ^to_string(source_exercise_id),
            limit: 1
        )
    end
  end

  def find_template_for_wger_media(_media), do: nil

  def get_exercise_template_by_slug(slug) do
    ExerciseTemplate
    |> where([template], template.slug == ^slug)
    |> preload([
      :aliases,
      :media,
      template_muscles: [:exercise_muscle],
      template_equipment: [:exercise_equipment],
      variations: [:variation_exercise_template],
      substitutions: [:substitute_exercise_template]
    ])
    |> Repo.one()
  end

  def list_exercise_aliases(%ExerciseTemplate{} = template) do
    ExerciseAlias
    |> where([exercise_alias], exercise_alias.exercise_template_id == ^template.id)
    |> order_by([exercise_alias], desc: exercise_alias.weight, asc: exercise_alias.name)
    |> Repo.all()
  end

  def create_exercise_alias(%ExerciseTemplate{} = template, attrs) do
    %ExerciseAlias{}
    |> ExerciseAlias.changeset(Map.put(attrs, :exercise_template_id, template.id))
    |> Repo.insert()
  end

  def create_exercise_variation(
        %ExerciseTemplate{} = base,
        %ExerciseTemplate{} = variation,
        attrs
      ) do
    %ExerciseVariation{}
    |> ExerciseVariation.changeset(
      attrs
      |> Map.put(:base_exercise_template_id, base.id)
      |> Map.put(:variation_exercise_template_id, variation.id)
    )
    |> Repo.insert()
  end

  def create_exercise_substitution(
        %ExerciseTemplate{} = exercise,
        %ExerciseTemplate{} = substitute,
        attrs
      ) do
    %ExerciseSubstitution{}
    |> ExerciseSubstitution.changeset(
      attrs
      |> Map.put(:exercise_template_id, exercise.id)
      |> Map.put(:substitute_exercise_template_id, substitute.id)
    )
    |> Repo.insert()
  end

  def search_exercise_templates(term, opts \\ %{}) do
    term = if is_binary(term), do: String.trim(term), else: ""
    opts = if is_list(opts), do: Map.new(opts), else: opts
    limit = Map.get(opts, :limit, 20)

    ExerciseTemplate
    |> join(:left, [template], exercise_alias in ExerciseAlias,
      on: exercise_alias.exercise_template_id == template.id
    )
    |> maybe_search_exercise_templates(term)
    |> order_by([template, exercise_alias],
      desc:
        fragment(
          "GREATEST(similarity(?, ?), similarity(coalesce(?, ''), ?))",
          template.name,
          ^term,
          exercise_alias.name,
          ^term
        ),
      desc: template.quality_score,
      asc: template.name
    )
    |> distinct([template], template.id)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Returns catalog health metrics for the internal exercise admin dashboard.
  """
  def exercise_library_admin_summary do
    %{
      templates: Repo.aggregate(ExerciseTemplate, :count, :id),
      muscles: Repo.aggregate(ExerciseMuscle, :count, :id),
      equipment: Repo.aggregate(ExerciseEquipment, :count, :id),
      media: Repo.aggregate(ExerciseMedia, :count, :id),
      cached_media: count_media_with_status("cached"),
      missing_media_records: count_media_with_status("missing"),
      skipped_media: count_media_with_status("skipped"),
      stale_media: count_media_with_status("stale"),
      failed_media: count_media_with_status("failed"),
      unsupported_media: count_media_with_status("unsupported"),
      sources: Repo.aggregate(ExerciseTemplateSource, :count, :id),
      missing_primary_muscle: count_templates_missing(:primary_muscle),
      missing_equipment: count_templates_missing(:equipment),
      missing_media: count_templates_without_media(),
      normalized_muscle_links: Repo.aggregate(ExerciseTemplateMuscle, :count, :id),
      normalized_equipment_links: Repo.aggregate(ExerciseTemplateEquipment, :count, :id)
    }
  end

  @doc """
  Returns recently imported templates with normalized associations preloaded.
  """
  def list_recent_exercise_templates(limit \\ 20) do
    ExerciseTemplate
    |> order_by([template], desc: template.updated_at)
    |> limit(^limit)
    |> preload([
      :media,
      template_sources: [],
      template_muscles: [:exercise_muscle],
      template_equipment: [:exercise_equipment]
    ])
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

  defp admin_template_preloads do
    [
      :aliases,
      :media,
      :template_sources,
      template_muscles: [:exercise_muscle],
      template_equipment: [:exercise_equipment]
    ]
  end

  defp split_admin_template_attrs(attrs) do
    attrs = normalize_admin_template_attrs(attrs)

    related_keys = [
      "aliases_text",
      "muscle_names",
      "equipment_names",
      "source_name",
      "source_external_id",
      "source_url",
      "source_payload"
    ]

    {Map.drop(attrs, related_keys), Map.take(attrs, related_keys)}
  end

  defp normalize_admin_template_attrs(attrs) do
    attrs
    |> stringify_admin_keys()
    |> normalize_admin_array_field("secondary_muscles")
    |> normalize_admin_array_field("weighted_tags")
    |> normalize_admin_array_field("training_style_tags")
    |> normalize_admin_source_id()
  end

  defp normalize_admin_array_field(attrs, field) do
    Map.update(attrs, field, [], &split_admin_text/1)
  end

  defp normalize_admin_source_id(%{"source_id" => ""} = attrs),
    do: Map.put(attrs, "source_id", nil)

  defp normalize_admin_source_id(attrs), do: attrs

  defp sync_admin_template_relations({:ok, %ExerciseTemplate{} = template}, related_attrs) do
    case sync_admin_template_relations(template, related_attrs) do
      {:ok, template} -> {:ok, template}
      {:error, reason} -> {:error, reason}
    end
  end

  defp sync_admin_template_relations({:error, changeset}, _related_attrs), do: {:error, changeset}

  defp sync_admin_template_relations(%ExerciseTemplate{} = template, related_attrs) do
    Repo.transaction(fn ->
      template
      |> sync_template_aliases(Map.get(related_attrs, "aliases_text"))
      |> sync_template_muscles(Map.get(related_attrs, "muscle_names"))
      |> sync_template_equipment(Map.get(related_attrs, "equipment_names"))
      |> sync_template_source(related_attrs)
      |> Repo.preload(admin_template_preloads(), force: true)
    end)
  end

  defp sync_template_aliases(template, aliases_text) when is_binary(aliases_text) do
    aliases = split_admin_text(aliases_text)

    Repo.delete_all(
      from exercise_alias in ExerciseAlias,
        where: exercise_alias.exercise_template_id == ^template.id
    )

    Enum.each(aliases, fn alias_name ->
      %ExerciseAlias{}
      |> ExerciseAlias.changeset(%{
        exercise_template_id: template.id,
        name: alias_name,
        kind: "alias",
        source: "admin",
        weight: 5
      })
      |> Repo.insert!()
    end)

    template
  end

  defp sync_template_aliases(template, _aliases_text), do: template

  defp sync_template_muscles(template, muscle_names) when is_binary(muscle_names) do
    muscles = split_admin_text(muscle_names)

    Repo.delete_all(
      from template_muscle in ExerciseTemplateMuscle,
        where: template_muscle.exercise_template_id == ^template.id
    )

    Enum.with_index(muscles)
    |> Enum.each(fn {name, position} ->
      muscle = get_or_create_exercise_muscle!(name)

      %ExerciseTemplateMuscle{}
      |> ExerciseTemplateMuscle.changeset(%{
        exercise_template_id: template.id,
        exercise_muscle_id: muscle.id,
        role: if(position == 0, do: "primary", else: "secondary"),
        position: position
      })
      |> Repo.insert!()
    end)

    template
  end

  defp sync_template_muscles(template, _muscle_names), do: template

  defp sync_template_equipment(template, equipment_names) when is_binary(equipment_names) do
    equipment_names = split_admin_text(equipment_names)

    Repo.delete_all(
      from template_equipment in ExerciseTemplateEquipment,
        where: template_equipment.exercise_template_id == ^template.id
    )

    Enum.with_index(equipment_names)
    |> Enum.each(fn {name, position} ->
      equipment = get_or_create_exercise_equipment!(name)

      %ExerciseTemplateEquipment{}
      |> ExerciseTemplateEquipment.changeset(%{
        exercise_template_id: template.id,
        exercise_equipment_id: equipment.id,
        position: position
      })
      |> Repo.insert!()
    end)

    template
  end

  defp sync_template_equipment(template, _equipment_names), do: template

  defp sync_template_source(template, related_attrs) do
    source = related_attrs |> Map.get("source_name") |> normalize_optional_text()
    external_id = related_attrs |> Map.get("source_external_id") |> normalize_optional_text()

    if source && external_id do
      source_record =
        Repo.get_by(ExerciseTemplateSource, source: source, external_id: external_id) ||
          %ExerciseTemplateSource{}

      payload =
        related_attrs
        |> Map.get("source_payload")
        |> decode_admin_payload()

      source_record
      |> ExerciseTemplateSource.changeset(%{
        exercise_template_id: template.id,
        source: source,
        external_id: external_id,
        source_url: related_attrs |> Map.get("source_url") |> normalize_optional_text(),
        payload: payload || %{},
        imported_at: DateTime.utc_now(:second)
      })
      |> Repo.insert_or_update!()
    end

    template
  end

  defp get_or_create_exercise_muscle!(name) do
    normalized_name = Normalizer.normalize_text(name)

    Repo.get_by(ExerciseMuscle, normalized_name: normalized_name) ||
      %ExerciseMuscle{}
      |> ExerciseMuscle.changeset(%{name: name, source: "admin"})
      |> Repo.insert!()
  end

  defp get_or_create_exercise_equipment!(name) do
    normalized_name = Normalizer.normalize_text(name)

    Repo.get_by(ExerciseEquipment, normalized_name: normalized_name) ||
      %ExerciseEquipment{}
      |> ExerciseEquipment.changeset(%{name: name, source: "admin"})
      |> Repo.insert!()
  end

  defp decode_admin_payload(value) when value in [nil, ""], do: %{}

  defp decode_admin_payload(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, payload} when is_map(payload) -> payload
      _ -> %{"raw" => value}
    end
  end

  defp decode_admin_payload(value) when is_map(value), do: value
  defp decode_admin_payload(_value), do: %{}

  defp stringify_admin_keys(attrs) do
    Map.new(attrs, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp split_admin_text(value) when is_list(value), do: Enum.flat_map(value, &split_admin_text/1)

  defp split_admin_text(value) when is_binary(value) do
    value
    |> String.split([",", "\n"], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp split_admin_text(_value), do: []

  defp count_templates_missing(field) do
    ExerciseTemplate
    |> where([template], is_nil(field(template, ^field)) or field(template, ^field) == "")
    |> Repo.aggregate(:count, :id)
  end

  defp count_templates_without_media do
    ExerciseTemplate
    |> join(:left, [template], media in assoc(template, :media))
    |> where(
      [_template, media],
      is_nil(media.id) or media.cache_status != "cached" or is_nil(media.local_path)
    )
    |> Repo.aggregate(:count, :id)
  end

  defp count_media_with_status(status) do
    ExerciseMedia
    |> where([media], media.cache_status == ^status)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns the list of workouts for the current user.
  """
  def list_workouts(%Scope{user: user}) do
    Workout
    |> where([workout], workout.user_id == ^user.id)
    |> order_by([workout], desc: workout.started_at)
    |> preload(workout_sets: [exercise: [source_template: :media]])
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
    |> preload(workout_sets: [exercise: [source_template: :media]])
    |> Repo.one()
  end

  def get_active_workout(_), do: nil

  def list_active_workouts(%Scope{user: user}) do
    Workout
    |> where([workout], workout.user_id == ^user.id)
    |> join(:left, [workout], workout_set in assoc(workout, :workout_sets))
    |> group_by([workout], workout.id)
    |> having([_workout, workout_set], count(workout_set.id) == 0)
    |> order_by([workout], desc: workout.started_at)
    |> preload(workout_sets: [:exercise])
    |> Repo.all()
  end

  def list_active_workouts(_), do: []

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

  defp maybe_preload_source_template(query, true), do: preload(query, source_template: :media)
  defp maybe_preload_source_template(query, _), do: query

  defp media_lookup(%{source: source, source_id: source_id})
       when is_binary(source) and is_binary(source_id) do
    Repo.get_by(ExerciseMedia, source: source, source_id: source_id)
  end

  defp media_lookup(%{source_url: source_url}) when is_binary(source_url) do
    Repo.get_by(ExerciseMedia, source_url: source_url)
  end

  defp media_lookup(attrs) do
    source = Map.get(attrs, "source")
    source_id = Map.get(attrs, "source_id")
    source_url = Map.get(attrs, "source_url")

    cond do
      is_binary(source) and is_binary(source_id) ->
        Repo.get_by(ExerciseMedia, source: source, source_id: source_id)

      is_binary(source_url) ->
        Repo.get_by(ExerciseMedia, source_url: source_url)

      true ->
        nil
    end
  end

  defp preserve_cached_media_fields(attrs, %ExerciseMedia{cache_status: "cached"}) do
    if Map.get(attrs, :cache_status) == "remote_only" or
         Map.get(attrs, "cache_status") == "remote_only" do
      Map.drop(attrs, [
        :cache_status,
        "cache_status",
        :local_path,
        "local_path",
        :storage_key,
        "storage_key",
        :content_hash,
        "content_hash",
        :cached_at,
        "cached_at",
        :file_size,
        "file_size",
        :mime_type,
        "mime_type"
      ])
    else
      attrs
    end
  end

  defp preserve_cached_media_fields(attrs, _media), do: attrs

  defp maybe_filter_templates(query, search) when search in [nil, ""], do: query

  defp maybe_filter_templates(query, search) do
    template_ids =
      search_exercise_templates(search, limit: 500)
      |> Enum.map(& &1.id)

    if template_ids == [] do
      where(query, [template], false)
    else
      where(query, [template], template.id in ^template_ids)
    end
  end

  defp maybe_filter_admin_templates(query, search) when search in [nil, ""], do: query

  defp maybe_filter_admin_templates(query, search) do
    search = String.trim(search)
    like = "%#{search}%"
    normalized = Normalizer.normalize_text(search)

    query
    |> join(:left, [template], exercise_alias in assoc(template, :aliases), as: :admin_alias)
    |> join(:left, [template], template_source in assoc(template, :template_sources),
      as: :admin_source
    )
    |> where(
      [template, admin_alias: exercise_alias, admin_source: template_source],
      ilike(template.name, ^like) or
        ilike(template.slug, ^like) or
        ilike(template.primary_muscle, ^like) or
        ilike(template.equipment, ^like) or
        ilike(template.normalized_name, ^like) or
        ilike(exercise_alias.name, ^like) or
        ilike(exercise_alias.normalized_name, ^like) or
        ilike(template_source.source, ^like) or
        ilike(template_source.external_id, ^like) or
        fragment("? = ANY(?)", ^normalized, template.weighted_tags)
    )
    |> distinct([template], template.id)
  end

  defp maybe_filter_by_muscle_group(query, nil), do: query
  defp maybe_filter_by_muscle_group(query, ""), do: query

  defp maybe_filter_by_muscle_group(query, muscle_group) do
    where(
      query,
      [template],
      template.primary_muscle == ^muscle_group or
        fragment(
          "EXISTS (SELECT 1 FROM exercise_template_muscles etm JOIN exercise_muscles em ON em.id = etm.exercise_muscle_id WHERE etm.exercise_template_id = ? AND em.name = ?)",
          template.id,
          ^muscle_group
        )
    )
  end

  defp maybe_filter_by_equipment(query, nil), do: query
  defp maybe_filter_by_equipment(query, ""), do: query

  defp maybe_filter_by_equipment(query, equipment) do
    equipment_terms = equipment_filter_terms(equipment)

    if equipment_terms == [] do
      query
    else
      where(
        query,
        [template],
        fragment("lower(?)", template.equipment) in ^equipment_terms or
          fragment(
            "EXISTS (SELECT 1 FROM exercise_template_equipment ete JOIN exercise_equipment ee ON ee.id = ete.exercise_equipment_id WHERE ete.exercise_template_id = ? AND lower(ee.name) = ANY(?))",
            template.id,
            ^equipment_terms
          )
      )
    end
  end

  defp maybe_filter_by_source(query, nil), do: query
  defp maybe_filter_by_source(query, ""), do: query

  defp maybe_filter_by_source(query, source) do
    where(
      query,
      [template],
      fragment(
        "EXISTS (SELECT 1 FROM exercise_template_sources ets WHERE ets.exercise_template_id = ? AND ets.source = ?)",
        template.id,
        ^source
      )
    )
  end

  defp maybe_filter_by_tag(query, nil), do: query
  defp maybe_filter_by_tag(query, ""), do: query

  defp maybe_filter_by_tag(query, tag) do
    where(query, [template], fragment("? = ANY(?)", ^tag, template.weighted_tags))
  end

  defp maybe_filter_by_media_status(query, nil), do: query
  defp maybe_filter_by_media_status(query, ""), do: query

  defp maybe_filter_by_media_status(query, "missing_media") do
    where(
      query,
      [template],
      fragment(
        "NOT EXISTS (SELECT 1 FROM exercise_media em WHERE em.exercise_template_id = ?)",
        template.id
      )
    )
  end

  defp maybe_filter_by_media_status(query, status) do
    where(
      query,
      [template],
      fragment(
        "EXISTS (SELECT 1 FROM exercise_media em WHERE em.exercise_template_id = ? AND em.cache_status = ?)",
        template.id,
        ^status
      )
    )
  end

  defp maybe_filter_media_report_by_status(query, nil), do: query
  defp maybe_filter_media_report_by_status(query, ""), do: query

  defp maybe_filter_media_report_by_status(query, status) do
    where(query, [media, _template], media.cache_status == ^status)
  end

  defp maybe_filter_media_report_by_source(query, nil), do: query
  defp maybe_filter_media_report_by_source(query, ""), do: query

  defp maybe_filter_media_report_by_source(query, source) do
    where(query, [media, _template], media.source == ^source)
  end

  defp maybe_filter_media_report_by_search(query, search) do
    case normalize_optional_text(search) do
      nil ->
        query

      search ->
        pattern = "%#{search}%"

        where(
          query,
          [media, template],
          ilike(template.name, ^pattern) or
            ilike(media.source_url, ^pattern) or
            ilike(media.source, ^pattern) or
            ilike(media.source_id, ^pattern) or
            ilike(media.source_exercise_id, ^pattern) or
            ilike(media.storage_key, ^pattern) or
            ilike(media.local_path, ^pattern)
        )
    end
  end

  defp maybe_filter_by_review_status(query, nil), do: query
  defp maybe_filter_by_review_status(query, ""), do: query

  defp maybe_filter_by_review_status(query, "needs_review") do
    where(query, [template], not template.is_verified and not template.is_deprecated)
  end

  defp maybe_filter_by_review_status(query, "verified") do
    where(query, [template], template.is_verified)
  end

  defp maybe_filter_by_review_status(query, "archived") do
    where(query, [template], template.is_deprecated)
  end

  defp maybe_filter_by_review_status(query, "ai_generated") do
    where(query, [template], template.is_ai_generated)
  end

  defp maybe_filter_by_review_status(query, _status), do: query

  defp maybe_filter_by_category(query, nil), do: query
  defp maybe_filter_by_category(query, ""), do: query

  defp maybe_filter_by_category(query, category) do
    where(query, [template], template.exercise_category == ^category)
  end

  defp maybe_filter_by_difficulty(query, nil), do: query
  defp maybe_filter_by_difficulty(query, ""), do: query

  defp maybe_filter_by_difficulty(query, difficulty) do
    where(query, [template], template.difficulty == ^difficulty)
  end

  defp parse_positive_integer(value, _default) when is_integer(value) and value > 0, do: value

  defp parse_positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> default
    end
  end

  defp parse_positive_integer(_value, default), do: default

  defp get_option(opts, key, default \\ nil) do
    Map.get(opts, key, Map.get(opts, to_string(key), default))
  end

  defp maybe_search_exercise_templates(query, ""), do: query

  defp maybe_search_exercise_templates(query, term) do
    like = "%#{term}%"

    where(
      query,
      [template, exercise_alias],
      ilike(template.name, ^like) or ilike(template.primary_muscle, ^like) or
        ilike(template.equipment, ^like) or ilike(template.normalized_name, ^like) or
        ilike(template.slug, ^like) or ilike(exercise_alias.name, ^like) or
        ilike(exercise_alias.normalized_name, ^like) or
        fragment("similarity(?, ?) > 0.2", template.name, ^term) or
        fragment("similarity(coalesce(?, ''), ?) > 0.2", exercise_alias.name, ^term) or
        fragment("? = ANY(?)", ^Normalizer.normalize_text(term), template.weighted_tags)
    )
  end

  @doc """
  Builds an AI-powered 4-week workout plan draft based on user input.
  """
  def preview_ai_workout_plan(%Scope{} = scope, attrs) when is_map(attrs) do
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

    duration_minutes =
      attrs
      |> Map.get("duration_minutes", 45)
      |> parse_int(45)

    source_url = normalize_optional_text(Map.get(attrs, "source_url"))
    source_transcript = normalize_optional_text(Map.get(attrs, "source_transcript"))
    source_summary = summarize_training_source(source_url, source_transcript)
    source_only? = truthy?(Map.get(attrs, "source_only")) or source_summary != nil
    set_type_preferences = source_set_type_preferences(source_summary)
    source_exercises = source_structured_exercises(source_summary)

    with :ok <-
           validate_unique_goals([
             primary_goal,
             secondary_goal,
             tertiary_goal,
             additional_goal
           ]),
         {:ok, days} <- validate_days_per_week(days_per_week),
         {:ok, duration_minutes} <- validate_duration_minutes(duration_minutes),
         :ok <- validate_source_summary(source_only?, source_summary),
         :ok <- validate_source_exercises(source_only?, source_exercises),
         {:ok, exercises} <-
           fetch_ai_exercises(scope, equipment, experience, source_summary, source_only?),
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
          rest_seconds,
          primary_goal,
          duration_minutes,
          set_type_preferences,
          source_summary,
          source_only?,
          source_exercises
        )

      plan_name = "AI Workout Plan (#{goal_label(primary_goal)}) - #{Date.utc_today()}"

      plan_description =
        [
          "4-week automatically generated plan.",
          "Goals (priority order): #{format_goal_preferences([primary_goal, secondary_goal, tertiary_goal, additional_goal])}",
          "Experience: #{String.capitalize(experience)}",
          "Equipment: #{format_equipment_preferences(equipment)}",
          "Session Duration: #{duration_minutes} minutes",
          maybe_preference_line("Training Styles", training_styles, &training_style_label/1),
          maybe_preference_line("Training Split", training_split, &training_split_label/1),
          source_description_line(source_summary),
          safety_note_line(source_summary),
          "",
          "Follow this weekly workout cycle for 4 weeks and progress weights each week."
        ]
        |> Enum.reject(&is_nil/1)
        |> Enum.join("\n")

      if source_only? and workout_plan_exercises == [] do
        {:error,
         "Could not detect exercises from that link. Use a page with a written exercise list, or configure OPENAI_API_KEY for AI parsing."}
      else
        {:ok,
         %{
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
           "estimated_duration_minutes" => duration_minutes,
           "workout_plan_exercises" => workout_plan_exercises
         }}
      end
    else
      [] ->
        {:error,
         "No exercises available to generate plan. Add exercises or expand equipment options."}

      {:error, msg} ->
        {:error, msg}
    end
  end

  def preview_ai_workout_plan(_, _), do: {:error, "Unauthorized"}

  @doc """
  Generates an AI-powered 4-week workout plan based on user input, saves it to the current user account.
  """
  def generate_ai_workout_plan(%Scope{} = scope, attrs) when is_map(attrs) do
    with {:ok, workout_plan_attrs} <- preview_ai_workout_plan(scope, attrs) do
      create_workout_plan(scope, workout_plan_attrs)
    end
  end

  def generate_ai_workout_plan(_, _), do: {:error, "Unauthorized"}

  defp normalize_optional_text(nil), do: nil

  defp normalize_optional_text(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp truthy?(value), do: value in [true, "true", "1", 1]

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

  defp validate_duration_minutes(minutes) when minutes in 15..180, do: {:ok, minutes}

  defp validate_duration_minutes(_),
    do: {:error, "Duration must be between 15 and 180 minutes"}

  defp validate_source_summary(true, %{status: :invalid, summary: summary}), do: {:error, summary}

  defp validate_source_summary(true, %{status: :error, summary: summary}), do: {:error, summary}

  defp validate_source_summary(true, %{status: :no_readable_text, kind: kind})
       when kind in [:youtube, :video],
       do:
         {:error,
          "Could not read workout details from that video. If it is a YouTube link, the transcript or page text may be unavailable."}

  defp validate_source_summary(true, %{status: :no_readable_text}),
    do: {:error, no_structured_source_message()}

  defp validate_source_summary(_source_only?, _source_summary), do: :ok

  defp validate_source_exercises(true, []) do
    {:error, no_structured_source_message()}
  end

  defp validate_source_exercises(_source_only?, _source_exercises), do: :ok

  defp fetch_ai_exercises(scope, equipment, _experience, source_summary, source_only?) do
    template_exercises =
      source_exercise_templates(source_summary)
      |> maybe_add_ai_exercise_templates(equipment, source_only?)
      |> Enum.uniq_by(&{&1.normalized_name, &1.normalized_equipment})
      |> Enum.take(30)
      |> Enum.flat_map(fn template ->
        case add_template_to_user(scope, template.id) do
          {:ok, exercise} -> [exercise]
          _ -> []
        end
      end)

    personal_exercises = if source_only?, do: [], else: ai_personal_exercises(scope, equipment)

    exercises =
      (template_exercises ++ personal_exercises)
      |> Enum.uniq_by(& &1.id)

    if exercises == [] do
      {:error, "No exercise templates available for selected equipment"}
    else
      {:ok, exercises}
    end
  end

  defp maybe_add_ai_exercise_templates(templates, _equipment, true), do: templates

  defp maybe_add_ai_exercise_templates(templates, equipment, _),
    do: templates ++ ai_exercise_templates(equipment)

  defp ai_personal_exercises(scope, equipment) do
    case list_exercises(scope, %{equipment: equipment}) do
      [] -> list_exercises(scope)
      exercises -> exercises
    end
  end

  defp source_exercise_templates(nil), do: []

  defp source_exercise_templates(source_summary) do
    templates = list_exercise_templates()

    source_summary
    |> source_exercise_names()
    |> Enum.flat_map(fn exercise_name ->
      search_terms = exercise_search_terms(exercise_name)

      db_matches = Enum.flat_map(search_terms, &list_exercise_templates(%{search: &1}))
      fuzzy_matches = Enum.filter(templates, &template_matches_exercise_name?(&1, search_terms))

      db_matches ++ fuzzy_matches
    end)
    |> Enum.uniq_by(&{&1.normalized_name, &1.normalized_equipment})
  end

  defp source_exercise_names(%{structured: %{"exercises" => exercises}})
       when is_list(exercises) do
    exercises
    |> Enum.map(&normalize_optional_text(&1["name"]))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp source_exercise_names(%{structured: %{:exercises => exercises}}) when is_list(exercises) do
    exercises
    |> Enum.map(&normalize_optional_text(&1[:name]))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp source_exercise_names(_), do: []

  defp exercise_search_terms(exercise_name) do
    normalized =
      exercise_name
      |> Normalizer.normalize_text()
      |> String.replace(~r/\b(dumbbell|barbell|machine|cable|bodyweight|weighted)\b/, "")
      |> String.replace(~r/\s+/, " ")
      |> String.trim()

    [exercise_name, normalized]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp template_matches_exercise_name?(template, search_terms) do
    normalized_template = Normalizer.normalize_text(template.name)

    Enum.any?(search_terms, fn term ->
      normalized_term = Normalizer.normalize_text(term)

      normalized_term != "" and
        (String.contains?(normalized_template, normalized_term) or
           String.contains?(normalized_term, normalized_template))
    end)
  end

  defp ai_exercise_templates([]), do: list_exercise_templates()

  defp ai_exercise_templates(equipment) do
    equipment_matches =
      equipment
      |> Enum.flat_map(fn eq -> list_exercise_templates(%{equipment: eq}) end)
      |> Enum.uniq_by(&{&1.normalized_name, &1.normalized_equipment})

    case equipment_matches do
      [] -> list_exercise_templates()
      templates -> templates
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
         rest_seconds,
         primary_goal,
         duration_minutes,
         set_type_preferences,
         _source_summary,
         source_only?,
         source_exercises
       ) do
    cond do
      source_exercises == [] and source_only? ->
        []

      source_exercises == [] ->
        build_generated_workout_plan_exercises(
          exercises,
          schedule_days,
          sets,
          min_reps,
          max_reps,
          rest_seconds,
          primary_goal,
          duration_minutes,
          set_type_preferences
        )

      true ->
        build_source_workout_plan_exercises(
          exercises,
          source_exercises,
          schedule_days,
          sets,
          min_reps,
          max_reps,
          rest_seconds,
          set_type_preferences,
          source_only?
        )
    end
  end

  defp build_generated_workout_plan_exercises(
         exercises,
         schedule_days,
         sets,
         min_reps,
         max_reps,
         rest_seconds,
         primary_goal,
         duration_minutes,
         set_type_preferences
       ) do
    # Use a dynamic daily exercise list and rotate through the pool for variety.
    pool_exercises = Enum.shuffle(exercises)

    exercises_per_day =
      cond do
        duration_minutes <= 30 -> min(length(pool_exercises), 3)
        duration_minutes <= 45 -> min(length(pool_exercises), 4)
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
        position = day_idx * exercises_per_day + idx

        %{
          position: position,
          exercise_id: exercise.id,
          target_sets: sets,
          target_reps_min: min_reps,
          target_reps_max: max_reps,
          rest_seconds: rest_seconds,
          target_kind: target_kind_for_goal(primary_goal, position, set_type_preferences),
          scheduled_day: day,
          notes: plan_exercise_notes(primary_goal, set_type_preferences)
        }
      end)
    end)
  end

  defp build_source_workout_plan_exercises(
         exercises,
         source_exercises,
         schedule_days,
         default_sets,
         default_min_reps,
         default_max_reps,
         default_rest_seconds,
         set_type_preferences,
         source_only?
       ) do
    exercise_lookup =
      exercises
      |> Enum.map(fn exercise -> {Normalizer.normalize_text(exercise.name), exercise} end)
      |> Map.new()

    source_exercises
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {source_exercise, position} ->
      with name when is_binary(name) <- source_exercise["name"],
           %Exercise{} = exercise <- find_source_exercise(exercises, exercise_lookup, name) do
        [
          %{
            position: position,
            exercise_id: exercise.id,
            target_sets: bounded_integer(source_exercise["target_sets"], default_sets, 1, 8),
            target_reps_min:
              bounded_integer(source_exercise["target_reps_min"], default_min_reps, 1, 50),
            target_reps_max:
              bounded_integer(source_exercise["target_reps_max"], default_max_reps, 1, 75),
            rest_seconds:
              bounded_integer(source_exercise["rest_seconds"], default_rest_seconds, 0, 300),
            target_kind:
              normalize_workout_set_kind(
                source_exercise["target_kind"] ||
                  Enum.at(
                    set_type_preferences,
                    rem(position - 1, max(1, length(set_type_preferences)))
                  )
              ),
            scheduled_day:
              normalize_scheduled_day(source_exercise["scheduled_day"], schedule_days, position),
            notes: normalize_source_exercise_notes(source_exercise["notes"])
          }
        ]
      else
        _ -> []
      end
    end)
    |> case do
      [] when source_only? ->
        []

      [] ->
        build_generated_workout_plan_exercises(
          exercises,
          schedule_days,
          default_sets,
          default_min_reps,
          default_max_reps,
          default_rest_seconds,
          "general",
          45,
          set_type_preferences
        )

      plan_exercises ->
        plan_exercises
    end
  end

  defp find_source_exercise(exercises, exercise_lookup, name) do
    normalized_name = Normalizer.normalize_text(name)

    Map.get(exercise_lookup, normalized_name) ||
      Enum.find(exercises, fn exercise ->
        normalized_exercise = Normalizer.normalize_text(exercise.name)

        String.contains?(normalized_exercise, normalized_name) ||
          String.contains?(normalized_name, normalized_exercise)
      end)
  end

  defp source_structured_exercises(%{structured: structured}) do
    case structured do
      %{"exercises" => exercises} when is_list(exercises) ->
        Enum.map(exercises, &stringify_keys/1)

      %{exercises: exercises} when is_list(exercises) ->
        Enum.map(exercises, &stringify_keys/1)

      _ ->
        []
    end
  end

  defp source_structured_exercises(_), do: []

  defp bounded_integer(value, default, min, max) do
    value
    |> parse_int(default)
    |> then(&(&1 |> Kernel.max(min) |> Kernel.min(max)))
  end

  defp normalize_workout_set_kind(kind) do
    kind = normalize_optional_text(kind) || "straight_set"

    if kind in WorkoutSet.kinds(), do: kind, else: "straight_set"
  end

  defp normalize_scheduled_day(nil, schedule_days, position) do
    Enum.at(schedule_days, rem(position - 1, length(schedule_days)))
  end

  defp normalize_scheduled_day(day, schedule_days, position) do
    day = normalize_optional_text(day)

    if day in days_for_week(7) do
      day
    else
      normalize_scheduled_day(nil, schedule_days, position)
    end
  end

  defp normalize_source_exercise_notes(nil),
    do: "Source-derived exercise. Review technique and load before saving."

  defp normalize_source_exercise_notes(notes) do
    notes
    |> to_string()
    |> String.trim()
    |> case do
      "" -> "Source-derived exercise. Review technique and load before saving."
      text -> String.slice(text, 0, 240)
    end
  end

  defp target_kind_for_goal(_primary_goal, idx, set_type_preferences)
       when is_list(set_type_preferences) and set_type_preferences != [] do
    Enum.at(set_type_preferences, rem(idx - 1, length(set_type_preferences)))
  end

  defp target_kind_for_goal("strength", 1, _preferences), do: "top_set"
  defp target_kind_for_goal("strength", idx, _preferences) when idx in 2..3, do: "working_set"
  defp target_kind_for_goal("hypertrophy", idx, _preferences) when idx in 1..3, do: "working_set"
  defp target_kind_for_goal("endurance", idx, _preferences) when idx > 3, do: "amrap"
  defp target_kind_for_goal("fat_loss", idx, _preferences) when rem(idx, 2) == 0, do: "superset"
  defp target_kind_for_goal(_, _, _preferences), do: "straight_set"

  defp plan_exercise_notes(_primary_goal, []),
    do: "Week 1-4: same structure. Increase load 2.5-5% each week."

  defp plan_exercise_notes(_primary_goal, _preferences) do
    "Source-guided block. Review exercise order, load, and fatigue before saving. Progress only when technique is stable."
  end

  defp summarize_training_source(nil, nil), do: nil

  defp summarize_training_source(source_url, source_transcript)
       when is_binary(source_transcript) do
    source_kind = source_kind_for_transcript(source_url)
    structured = parse_source_workout(source_transcript, source_url || "pasted transcript")

    status =
      if source_structured_exercises(%{structured: structured}) == [] do
        :no_structured_exercises
      else
        :ok
      end

    %{
      url: source_url,
      kind: source_kind,
      status: status,
      summary: source_summary_text(status, source_kind, source_transcript),
      text: source_transcript,
      structured: structured
    }
  end

  defp summarize_training_source(source_url, _source_transcript) do
    with {:ok, uri} <- URI.new(source_url),
         true <- valid_source_uri?(uri) do
      fetch_training_source_summary(source_url, classify_source_url(uri))
    else
      _ ->
        %{
          url: source_url,
          kind: :invalid,
          status: :invalid,
          summary: "Source link was not a valid HTTP or HTTPS URL."
        }
    end
  end

  defp source_kind_for_transcript(nil), do: :transcript

  defp source_kind_for_transcript(source_url) do
    with {:ok, uri} <- URI.new(source_url),
         true <- valid_source_uri?(uri) do
      classify_source_url(uri)
    else
      _ -> :transcript
    end
  end

  defp valid_source_uri?(%URI{scheme: scheme, host: host})
       when scheme in ["http", "https"] and is_binary(host),
       do: host != ""

  defp valid_source_uri?(_uri), do: false

  defp classify_source_url(%URI{host: host, path: path}) do
    host = host |> to_string() |> String.downcase()
    path = path |> to_string() |> String.downcase()

    cond do
      host in ["youtube.com", "www.youtube.com", "m.youtube.com"] and youtube_path?(path) ->
        :youtube

      host == "youtu.be" ->
        :youtube

      host in ["vimeo.com", "www.vimeo.com"] or String.ends_with?(path, [".mp4", ".mov", ".webm"]) ->
        :video

      true ->
        :article
    end
  end

  defp youtube_path?(path) do
    Enum.any?(["/watch", "/shorts/", "/embed/", "/live/"], &String.starts_with?(path, &1))
  end

  defp fetch_training_source_summary(source_url, source_kind) do
    case ai_source_http_client().get(source_url, receive_timeout: 5_000) do
      {:ok, %{status: status, body: body}} when status in 200..299 and is_binary(body) ->
        text = source_text(body)
        structured = parse_source_workout(text, source_url)

        status =
          cond do
            text == "" ->
              :no_readable_text

            source_structured_exercises(%{structured: structured}) == [] ->
              :no_structured_exercises

            true ->
              :ok
          end

        %{
          url: source_url,
          kind: source_kind,
          status: status,
          summary: source_summary_text(status, source_kind, text),
          text: text,
          structured: structured
        }

      {:ok, %{status: status}} ->
        %{
          url: source_url,
          kind: source_kind,
          status: :error,
          summary: "Source returned HTTP #{status}."
        }

      {:error, _reason} ->
        %{
          url: source_url,
          kind: source_kind,
          status: :error,
          summary: "Source could not be fetched."
        }
    end
  end

  defp source_text(body) do
    body
    |> String.replace(~r/<script[\s\S]*?<\/script>/i, " ")
    |> String.replace(~r/<style[\s\S]*?<\/style>/i, " ")
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp summarize_source_text(""), do: "Source loaded, but no readable workout text was found."

  defp summarize_source_text(text) do
    text
    |> String.slice(0, 700)
    |> String.trim()
  end

  defp source_summary_text(:no_readable_text, _source_kind, _text),
    do: "Source loaded, but no readable workout text was found."

  defp source_summary_text(:no_structured_exercises, _source_kind, text),
    do: summarize_source_text(text)

  defp source_summary_text(:ok, _source_kind, text), do: summarize_source_text(text)

  defp no_structured_source_message do
    "Could not detect structured exercises from that link. Try an article with a written exercise list, paste a transcript, or use the manual generator."
  end

  defp parse_source_workout("", _source_url), do: nil

  defp parse_source_workout(text, source_url) do
    parser_client = ai_workout_parser_client()

    if function_exported?(parser_client, :parse_workout_text, 2) do
      case parser_client.parse_workout_text(text, %{source_url: source_url}) do
        {:ok, attrs} when is_map(attrs) -> normalize_structured_workout(attrs)
        _ -> nil
      end
    end
  end

  defp normalize_structured_workout(attrs) do
    attrs = stringify_keys(attrs)

    exercises =
      attrs
      |> Map.get("exercises", [])
      |> case do
        exercises when is_list(exercises) -> Enum.map(exercises, &stringify_keys/1)
        _ -> []
      end
      |> Enum.map(&normalize_structured_exercise/1)
      |> Enum.reject(&is_nil/1)

    %{
      "title" => normalize_optional_text(attrs["title"]),
      "summary" => normalize_optional_text(attrs["summary"]),
      "safety_notes" => normalize_string_list(attrs["safety_notes"]),
      "exercises" => exercises
    }
  end

  defp normalize_structured_exercise(attrs) do
    name = normalize_optional_text(attrs["name"] || attrs["exercise"] || attrs["movement"])

    if is_nil(name) do
      nil
    else
      {rep_min, rep_max} = normalize_rep_range(attrs)

      %{
        "name" => name,
        "scheduled_day" => normalize_optional_text(attrs["scheduled_day"] || attrs["day"]),
        "target_sets" => bounded_integer(attrs["target_sets"] || attrs["sets"], 3, 1, 8),
        "target_reps_min" => rep_min,
        "target_reps_max" => rep_max,
        "rest_seconds" =>
          bounded_integer(
            attrs["rest_seconds"] || attrs["rest"] || attrs["rest_time"],
            60,
            0,
            300
          ),
        "target_kind" =>
          normalize_workout_set_kind(attrs["target_kind"] || attrs["set_type"] || attrs["type"]),
        "notes" => normalize_optional_text(attrs["notes"]) || "Source-derived exercise."
      }
    end
  end

  defp normalize_rep_range(attrs) do
    reps_text = normalize_optional_text(attrs["reps"] || attrs["rep_range"])

    case reps_text && Regex.run(~r/(\d+)(?:\s*[-–]\s*(\d+))?/, reps_text) do
      [_, reps] ->
        reps = bounded_integer(reps, 8, 1, 75)
        {reps, reps}

      [_, min_reps, max_reps] ->
        min_reps = bounded_integer(min_reps, 8, 1, 50)
        max_reps = bounded_integer(max_reps, min_reps, min_reps, 75)
        {min_reps, max_reps}

      _ ->
        {
          bounded_integer(attrs["target_reps_min"] || attrs["min_reps"], 8, 1, 50),
          bounded_integer(attrs["target_reps_max"] || attrs["max_reps"], 12, 1, 75)
        }
    end
  end

  defp normalize_string_list(values) when is_list(values) do
    values
    |> Enum.map(&normalize_optional_text/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_string_list(_), do: []

  defp source_set_type_preferences(nil), do: []

  defp source_set_type_preferences(%{structured: %{"exercises" => exercises}})
       when is_list(exercises) do
    exercises
    |> Enum.map(&normalize_workout_set_kind(&1["target_kind"]))
    |> Enum.uniq()
  end

  defp source_set_type_preferences(%{structured: %{exercises: exercises}})
       when is_list(exercises) do
    exercises
    |> Enum.map(&normalize_workout_set_kind(&1[:target_kind]))
    |> Enum.uniq()
  end

  defp source_set_type_preferences(%{text: text}) when is_binary(text) do
    normalized = String.downcase(text)

    [
      {"warm", "warm_up"},
      {"superset", "superset"},
      {"circuit", "circuit"},
      {"drop set", "drop_set"},
      {"amrap", "amrap"},
      {"as many reps", "amrap"},
      {"timed", "timed_set"},
      {"seconds", "timed_set"},
      {"failure", "failure"},
      {"rest-pause", "rest_pause"},
      {"rest pause", "rest_pause"}
    ]
    |> Enum.flat_map(fn {keyword, kind} ->
      if String.contains?(normalized, keyword), do: [kind], else: []
    end)
    |> Enum.uniq()
  end

  defp source_set_type_preferences(_source_summary), do: []

  defp source_description_line(nil), do: nil

  defp source_description_line(%{url: nil, status: :ok, summary: summary}) do
    "Source guide: pasted transcript\nSource summary: #{summary}"
  end

  defp source_description_line(%{url: nil, summary: summary}) do
    "Source guide: pasted transcript\nSource note: #{summary}"
  end

  defp source_description_line(%{url: url, status: :ok, summary: summary}) do
    "Source guide: #{url}\nSource summary: #{summary}"
  end

  defp source_description_line(%{url: url, summary: summary}) do
    "Source guide: #{url}\nSource note: #{summary}"
  end

  defp safety_note_line(nil), do: nil

  defp safety_note_line(%{structured: %{"safety_notes" => safety_notes}})
       when is_list(safety_notes) and safety_notes != [] do
    "Safety review: #{Enum.join(safety_notes, " ")}"
  end

  defp safety_note_line(_source_summary) do
    "Safety review: generated volume is capped by your selected experience, duration, and available exercise library. Avoid max-effort failure work on complex lifts unless supervised."
  end

  defp ai_source_http_client do
    Application.get_env(:fittrack, :ai_workout_source_http_client, Req)
  end

  defp ai_workout_parser_client do
    Application.get_env(:fittrack, :ai_workout_parser_client, OpenAIWorkoutParserClient)
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify_keys(_), do: %{}

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
