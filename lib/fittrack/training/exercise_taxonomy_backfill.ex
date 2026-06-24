defmodule Fittrack.Training.ExerciseTaxonomyBackfill do
  @moduledoc """
  Backfills normalized taxonomy and source metadata for shared exercise templates.
  """

  import Ecto.Query

  alias Fittrack.Repo
  alias Fittrack.Training.ExerciseEquipment
  alias Fittrack.Training.ExerciseMedia
  alias Fittrack.Training.ExerciseMuscle
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.ExerciseTemplateEquipment
  alias Fittrack.Training.ExerciseTemplateMuscle
  alias Fittrack.Training.ExerciseTemplateSource
  alias Fittrack.Training.Normalizer

  @wger_url "https://wger.de/api/v2/exerciseinfo/"

  @empty_report %{
    total_templates_inspected: 0,
    templates_updated: 0,
    muscles_created: 0,
    muscle_joins_created: 0,
    equipment_created: 0,
    equipment_joins_created: 0,
    sources_created: 0,
    source_links_updated: 0,
    media_cached: 0,
    media_missing: 0,
    media_stale: 0,
    media_failed: 0,
    template_rows_updated: 0,
    skipped_records: 0,
    errors: 0,
    failures: []
  }

  def run(opts \\ []) do
    opts = normalize_opts(opts)

    report =
      opts
      |> template_query()
      |> Repo.all()
      |> Enum.reduce(@empty_report, fn template, report ->
        merge_reports(report, process_template(template, opts))
      end)
      |> Map.update!(:failures, &Enum.reverse/1)

    {:ok, report}
  end

  def empty_report, do: @empty_report

  defp template_query(opts) do
    ExerciseTemplate
    |> maybe_filter_template(Keyword.get(opts, :template_id))
    |> order_by([template], asc: template.id)
    |> maybe_limit(Keyword.get(opts, :limit))
    |> preload([
      :template_sources,
      :media,
      template_muscles: [:exercise_muscle],
      template_equipment: [:exercise_equipment]
    ])
  end

  defp maybe_filter_template(query, nil), do: query

  defp maybe_filter_template(query, template_id) do
    where(query, [template], template.id == ^template_id)
  end

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit), do: limit(query, ^limit)

  defp process_template(%ExerciseTemplate{} = template, opts) do
    try do
      template
      |> do_process_template(opts)
      |> Map.update!(:total_templates_inspected, &(&1 + 1))
    rescue
      error ->
        @empty_report
        |> Map.update!(:total_templates_inspected, &(&1 + 1))
        |> Map.update!(:errors, &(&1 + 1))
        |> Map.update!(
          :failures,
          &[%{template_id: template.id, error: Exception.message(error)} | &1]
        )
    end
  end

  defp do_process_template(template, opts) do
    payload = source_payload(template)
    source_report = ensure_template_source(template, payload, opts)
    muscle_report = ensure_template_muscles(template, muscle_refs(template, payload), opts)

    equipment_report =
      ensure_template_equipment(template, equipment_refs(template, payload), opts)

    template_report = maybe_update_template_fields(template, payload, opts)
    media_report = media_status_report(template)

    report =
      @empty_report
      |> merge_reports(source_report)
      |> merge_reports(muscle_report)
      |> merge_reports(equipment_report)
      |> merge_reports(template_report)
      |> merge_reports(media_report)

    if template_changed?(report) do
      Map.update!(report, :templates_updated, &(&1 + 1))
    else
      Map.update!(report, :skipped_records, &(&1 + 1))
    end
  end

  defp template_changed?(report) do
    changed_keys = [
      :muscles_created,
      :muscle_joins_created,
      :equipment_created,
      :equipment_joins_created,
      :sources_created,
      :source_links_updated,
      :template_rows_updated
    ]

    Enum.any?(changed_keys, &(Map.fetch!(report, &1) > 0))
  end

  defp maybe_update_template_fields(template, payload, opts) do
    attrs =
      %{}
      |> maybe_put_source_id(template, source_external_id(template, payload))
      |> maybe_put_primary_muscle(template, muscle_refs(template, payload))
      |> maybe_put_secondary_muscles(template, muscle_refs(template, payload))
      |> maybe_put_equipment(template, equipment_refs(template, payload))

    cond do
      attrs == %{} ->
        @empty_report

      Keyword.get(opts, :dry_run, false) ->
        Map.update!(@empty_report, :template_rows_updated, &(&1 + 1))

      true ->
        case template |> ExerciseTemplate.changeset(attrs) |> Repo.update() do
          {:ok, _template} ->
            Map.update!(@empty_report, :template_rows_updated, &(&1 + 1))

          {:error, changeset} ->
            failure_report(template.id, changeset_errors(changeset))
        end
    end
  end

  defp maybe_put_source_id(attrs, %ExerciseTemplate{source_id: nil}, external_id) do
    case parse_integer(external_id) do
      nil -> attrs
      source_id -> Map.put(attrs, :source_id, source_id)
    end
  end

  defp maybe_put_source_id(attrs, _template, _external_id), do: attrs

  defp maybe_put_primary_muscle(attrs, template, refs) do
    case {blank?(template.primary_muscle), Enum.find(refs, &(&1.role == "primary"))} do
      {true, %{name: name}} -> Map.put(attrs, :primary_muscle, name)
      _other -> attrs
    end
  end

  defp maybe_put_secondary_muscles(attrs, template, refs) do
    secondary =
      refs
      |> Enum.filter(&(&1.role == "secondary"))
      |> Enum.map(& &1.name)
      |> Enum.reject(&blank?/1)

    if Enum.empty?(template.secondary_muscles || []) and secondary != [] do
      Map.put(attrs, :secondary_muscles, secondary)
    else
      attrs
    end
  end

  defp maybe_put_equipment(attrs, template, refs) do
    case {blank?(template.equipment), List.first(refs)} do
      {true, %{name: name}} -> Map.put(attrs, :equipment, name)
      _other -> attrs
    end
  end

  defp ensure_template_source(template, payload, opts) do
    case source_external_id(template, payload) do
      nil ->
        @empty_report

      external_id ->
        ensure_wger_source(template, external_id, payload, opts)
    end
  end

  defp ensure_wger_source(template, external_id, payload, opts) do
    external_id = to_string(external_id)

    case Repo.get_by(ExerciseTemplateSource, source: "wger", external_id: external_id) do
      nil ->
        create_source(template, external_id, payload, opts)

      %ExerciseTemplateSource{exercise_template_id: template_id}
      when template_id != template.id ->
        failure_report(
          template.id,
          "wger source #{external_id} already belongs to template #{template_id}"
        )

      %ExerciseTemplateSource{} = source ->
        update_source_link(source, template, external_id, payload, opts)
    end
  end

  defp create_source(template, external_id, payload, opts) do
    attrs = source_attrs(template.id, external_id, payload)

    if Keyword.get(opts, :dry_run, false) do
      Map.update!(@empty_report, :sources_created, &(&1 + 1))
    else
      %ExerciseTemplateSource{}
      |> ExerciseTemplateSource.changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, _source} ->
          Map.update!(@empty_report, :sources_created, &(&1 + 1))

        {:error, changeset} ->
          failure_report(template.id, changeset_errors(changeset))
      end
    end
  end

  defp update_source_link(source, template, external_id, payload, opts) do
    attrs = source_update_attrs(source, source_attrs(template.id, external_id, payload))

    cond do
      attrs == %{} ->
        @empty_report

      Keyword.get(opts, :dry_run, false) ->
        Map.update!(@empty_report, :source_links_updated, &(&1 + 1))

      true ->
        source
        |> ExerciseTemplateSource.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, _source} ->
            Map.update!(@empty_report, :source_links_updated, &(&1 + 1))

          {:error, changeset} ->
            failure_report(template.id, changeset_errors(changeset))
        end
    end
  end

  defp source_attrs(template_id, external_id, payload) do
    %{
      exercise_template_id: template_id,
      source: "wger",
      external_id: external_id,
      source_url: "#{@wger_url}#{external_id}/",
      payload: payload || %{},
      imported_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  defp source_update_attrs(source, attrs) do
    attrs
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      current = Map.get(source, key)

      cond do
        key == :payload ->
          if map_size(current || %{}) == 0 and map_size(value || %{}) > 0 do
            Map.put(acc, key, value)
          else
            acc
          end

        key == :imported_at and not is_nil(current) ->
          acc

        blank?(current) and not blank?(value) ->
          Map.put(acc, key, value)

        key == :exercise_template_id and current != value ->
          Map.put(acc, key, value)

        true ->
          acc
      end
    end)
  end

  defp ensure_template_muscles(_template, [], _opts), do: @empty_report

  defp ensure_template_muscles(template, refs, opts) do
    refs
    |> Enum.reduce(@empty_report, fn ref, report ->
      merge_reports(report, ensure_template_muscle(template, ref, opts))
    end)
  end

  defp ensure_template_muscle(template, ref, opts) do
    case get_or_create_muscle(ref, opts) do
      {:ok, muscle, record_report} ->
        join_report =
          ensure_muscle_join(template, muscle, ref, opts)

        merge_reports(record_report, join_report)

      {:dry_run_missing, record_report} ->
        record_report
        |> Map.update!(:muscle_joins_created, &(&1 + 1))

      {:error, reason} ->
        failure_report(template.id, reason)
    end
  end

  defp get_or_create_muscle(ref, opts) do
    case find_muscle(ref) do
      %ExerciseMuscle{} = muscle ->
        maybe_enrich_muscle(muscle, ref, opts)

      nil ->
        create_muscle(ref, opts)
    end
  end

  defp find_muscle(ref) do
    Repo.get_by(ExerciseMuscle, normalized_name: Normalizer.normalize_text(ref.name)) ||
      find_by_source(ExerciseMuscle, ref)
  end

  defp maybe_enrich_muscle(muscle, ref, opts) do
    attrs =
      %{}
      |> maybe_put_blank(:source, muscle.source, ref.source)
      |> maybe_put_blank(:source_id, muscle.source_id, ref.source_id)
      |> maybe_put_blank(:region, muscle.region, ref.region)
      |> remove_conflicting_source(ExerciseMuscle, muscle)

    cond do
      attrs == %{} ->
        {:ok, muscle, @empty_report}

      Keyword.get(opts, :dry_run, false) ->
        {:ok, muscle, @empty_report}

      true ->
        muscle
        |> ExerciseMuscle.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, muscle} -> {:ok, muscle, @empty_report}
          {:error, changeset} -> {:error, changeset_errors(changeset)}
        end
    end
  end

  defp create_muscle(ref, opts) do
    report = Map.update!(@empty_report, :muscles_created, &(&1 + 1))

    if Keyword.get(opts, :dry_run, false) do
      {:dry_run_missing, report}
    else
      %ExerciseMuscle{}
      |> ExerciseMuscle.changeset(%{
        name: ref.name,
        region: ref.region,
        source: ref.source,
        source_id: ref.source_id
      })
      |> Repo.insert()
      |> case do
        {:ok, muscle} -> {:ok, muscle, report}
        {:error, changeset} -> {:error, changeset_errors(changeset)}
      end
    end
  end

  defp ensure_muscle_join(template, muscle, ref, opts) do
    if existing_muscle_join?(template, muscle.id, ref.role) do
      @empty_report
    else
      attrs = %{
        exercise_template_id: template.id,
        exercise_muscle_id: muscle.id,
        role: ref.role,
        position: ref.position
      }

      if Keyword.get(opts, :dry_run, false) do
        Map.update!(@empty_report, :muscle_joins_created, &(&1 + 1))
      else
        %ExerciseTemplateMuscle{}
        |> ExerciseTemplateMuscle.changeset(attrs)
        |> Repo.insert()
        |> case do
          {:ok, _join} ->
            Map.update!(@empty_report, :muscle_joins_created, &(&1 + 1))

          {:error, changeset} ->
            failure_report(template.id, changeset_errors(changeset))
        end
      end
    end
  end

  defp existing_muscle_join?(template, muscle_id, role) do
    Enum.any?(template.template_muscles, fn template_muscle ->
      template_muscle.exercise_muscle_id == muscle_id and template_muscle.role == role
    end)
  end

  defp ensure_template_equipment(_template, [], _opts), do: @empty_report

  defp ensure_template_equipment(template, refs, opts) do
    refs
    |> Enum.reduce(@empty_report, fn ref, report ->
      merge_reports(report, ensure_template_equipment_item(template, ref, opts))
    end)
  end

  defp ensure_template_equipment_item(template, ref, opts) do
    case get_or_create_equipment(ref, opts) do
      {:ok, equipment, record_report} ->
        join_report = ensure_equipment_join(template, equipment, ref, opts)
        merge_reports(record_report, join_report)

      {:dry_run_missing, record_report} ->
        record_report
        |> Map.update!(:equipment_joins_created, &(&1 + 1))

      {:error, reason} ->
        failure_report(template.id, reason)
    end
  end

  defp get_or_create_equipment(ref, opts) do
    case find_equipment(ref) do
      %ExerciseEquipment{} = equipment ->
        maybe_enrich_equipment(equipment, ref, opts)

      nil ->
        create_equipment(ref, opts)
    end
  end

  defp find_equipment(ref) do
    Repo.get_by(ExerciseEquipment, normalized_name: Normalizer.normalize_text(ref.name)) ||
      find_by_source(ExerciseEquipment, ref)
  end

  defp maybe_enrich_equipment(equipment, ref, opts) do
    attrs =
      %{}
      |> maybe_put_blank(:source, equipment.source, ref.source)
      |> maybe_put_blank(:source_id, equipment.source_id, ref.source_id)
      |> maybe_put_blank(:category, equipment.category, ref.category)
      |> remove_conflicting_source(ExerciseEquipment, equipment)

    cond do
      attrs == %{} ->
        {:ok, equipment, @empty_report}

      Keyword.get(opts, :dry_run, false) ->
        {:ok, equipment, @empty_report}

      true ->
        equipment
        |> ExerciseEquipment.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, equipment} -> {:ok, equipment, @empty_report}
          {:error, changeset} -> {:error, changeset_errors(changeset)}
        end
    end
  end

  defp create_equipment(ref, opts) do
    report = Map.update!(@empty_report, :equipment_created, &(&1 + 1))

    if Keyword.get(opts, :dry_run, false) do
      {:dry_run_missing, report}
    else
      %ExerciseEquipment{}
      |> ExerciseEquipment.changeset(%{
        name: ref.name,
        category: ref.category,
        source: ref.source,
        source_id: ref.source_id
      })
      |> Repo.insert()
      |> case do
        {:ok, equipment} -> {:ok, equipment, report}
        {:error, changeset} -> {:error, changeset_errors(changeset)}
      end
    end
  end

  defp ensure_equipment_join(template, equipment, ref, opts) do
    if existing_equipment_join?(template, equipment.id) do
      @empty_report
    else
      attrs = %{
        exercise_template_id: template.id,
        exercise_equipment_id: equipment.id,
        position: ref.position
      }

      if Keyword.get(opts, :dry_run, false) do
        Map.update!(@empty_report, :equipment_joins_created, &(&1 + 1))
      else
        %ExerciseTemplateEquipment{}
        |> ExerciseTemplateEquipment.changeset(attrs)
        |> Repo.insert()
        |> case do
          {:ok, _join} ->
            Map.update!(@empty_report, :equipment_joins_created, &(&1 + 1))

          {:error, changeset} ->
            failure_report(template.id, changeset_errors(changeset))
        end
      end
    end
  end

  defp existing_equipment_join?(template, equipment_id) do
    Enum.any?(template.template_equipment, fn template_equipment ->
      template_equipment.exercise_equipment_id == equipment_id
    end)
  end

  defp find_by_source(_schema, %{source: nil}), do: nil
  defp find_by_source(_schema, %{source_id: nil}), do: nil

  defp find_by_source(schema, ref) do
    Repo.get_by(schema, source: ref.source, source_id: ref.source_id)
  end

  defp maybe_put_blank(attrs, _field, _current, nil), do: attrs
  defp maybe_put_blank(attrs, _field, _current, ""), do: attrs

  defp maybe_put_blank(attrs, field, current, value) do
    if blank?(current), do: Map.put(attrs, field, value), else: attrs
  end

  defp remove_conflicting_source(attrs, _schema, _record) when attrs == %{}, do: attrs

  defp remove_conflicting_source(attrs, schema, record) do
    source = Map.get(attrs, :source)
    source_id = Map.get(attrs, :source_id)

    if source && source_id do
      case Repo.get_by(schema, source: source, source_id: source_id) do
        nil -> attrs
        %{id: id} when id == record.id -> attrs
        _conflict -> Map.drop(attrs, [:source, :source_id])
      end
    else
      attrs
    end
  end

  defp media_status_report(template) do
    media = template.media || []

    cond do
      media == [] ->
        Map.update!(@empty_report, :media_missing, &(&1 + 1))

      true ->
        Enum.reduce(media, @empty_report, fn media, report ->
          case media_status(media) do
            :cached -> Map.update!(report, :media_cached, &(&1 + 1))
            :missing -> Map.update!(report, :media_missing, &(&1 + 1))
            :stale -> Map.update!(report, :media_stale, &(&1 + 1))
            :failed -> Map.update!(report, :media_failed, &(&1 + 1))
            :other -> report
          end
        end)
    end
  end

  defp media_status(%ExerciseMedia{cache_status: "cached", local_path: local_path})
       when is_binary(local_path),
       do: :cached

  defp media_status(%ExerciseMedia{cache_status: "missing"}), do: :missing
  defp media_status(%ExerciseMedia{cache_status: "stale"}), do: :stale
  defp media_status(%ExerciseMedia{cache_status: "failed"}), do: :failed
  defp media_status(_media), do: :other

  defp source_external_id(template, payload) do
    template.source_id ||
      existing_wger_source_id(template) ||
      Map.get(payload || %{}, "id") ||
      Map.get(payload || %{}, :id)
  end

  defp existing_wger_source_id(template) do
    template.template_sources
    |> Enum.find_value(fn
      %{source: "wger", external_id: external_id} -> external_id
      _source -> nil
    end)
  end

  defp source_payload(template) do
    template.template_sources
    |> Enum.sort_by(fn source -> if(source.source == "wger", do: 0, else: 1) end)
    |> Enum.find_value(fn source ->
      case source.payload do
        payload when is_map(payload) and map_size(payload) > 0 -> payload
        _other -> nil
      end
    end)
    |> Kernel.||(%{})
  end

  defp muscle_refs(template, payload) do
    primary_refs = payload_muscle_refs(payload, "muscles", "primary", 0)

    secondary_from_primary =
      primary_refs |> Enum.drop(1) |> Enum.map(&Map.put(&1, :role, "secondary"))

    primary_refs = Enum.take(primary_refs, 1)

    secondary_refs =
      payload_muscle_refs(
        payload,
        "muscles_secondary",
        "secondary",
        length(secondary_from_primary) + 1
      )

    refs =
      primary_refs ++
        secondary_from_primary ++
        secondary_refs ++
        legacy_muscle_refs(template)

    refs
    |> Enum.reject(&blank?(&1.name))
    |> Enum.uniq_by(&Normalizer.normalize_text(&1.name))
    |> Enum.with_index()
    |> Enum.map(fn {ref, position} -> %{ref | position: position} end)
  end

  defp payload_muscle_refs(payload, key, role, position_offset) do
    payload
    |> Map.get(key, [])
    |> List.wrap()
    |> Enum.with_index(position_offset)
    |> Enum.flat_map(fn {entry, position} ->
      case extract_name(entry) do
        nil ->
          []

        name ->
          [
            %{
              name: normalize_muscle_group(name),
              role: role,
              position: position,
              region: muscle_region(name),
              source: "wger",
              source_id: source_entry_id(entry)
            }
          ]
      end
    end)
  end

  defp legacy_muscle_refs(template) do
    primary =
      if blank?(template.primary_muscle) do
        []
      else
        [
          %{
            name: normalize_muscle_group(template.primary_muscle),
            role: "primary",
            position: 0,
            region: muscle_region(template.primary_muscle),
            source: nil,
            source_id: nil
          }
        ]
      end

    secondary =
      template.secondary_muscles
      |> List.wrap()
      |> Enum.with_index(1)
      |> Enum.reject(fn {name, _position} -> blank?(name) end)
      |> Enum.map(fn {name, position} ->
        %{
          name: normalize_muscle_group(name),
          role: "secondary",
          position: position,
          region: muscle_region(name),
          source: nil,
          source_id: nil
        }
      end)

    primary ++ secondary
  end

  defp equipment_refs(template, payload) do
    refs =
      payload_equipment_refs(payload) ++ legacy_equipment_refs(template)

    refs
    |> Enum.reject(&blank?(&1.name))
    |> Enum.uniq_by(&Normalizer.normalize_text(&1.name))
    |> Enum.with_index()
    |> Enum.map(fn {ref, position} -> %{ref | position: position} end)
  end

  defp payload_equipment_refs(payload) do
    payload
    |> Map.get("equipment", [])
    |> List.wrap()
    |> Enum.with_index()
    |> Enum.flat_map(fn {entry, position} ->
      case extract_name(entry) do
        nil ->
          []

        name ->
          normalized_name = normalize_equipment(name)

          [
            %{
              name: normalized_name,
              position: position,
              category: equipment_category(normalized_name),
              source: "wger",
              source_id: source_entry_id(entry)
            }
          ]
      end
    end)
  end

  defp legacy_equipment_refs(template) do
    if blank?(template.equipment) do
      []
    else
      normalized_name = normalize_equipment(template.equipment)

      [
        %{
          name: normalized_name,
          position: 0,
          category: equipment_category(normalized_name),
          source: nil,
          source_id: nil
        }
      ]
    end
  end

  defp normalize_muscle_group(nil), do: nil

  defp normalize_muscle_group(target) do
    case String.downcase(target) do
      "pectorals" -> "Chest"
      "biceps" -> "Biceps"
      "triceps" -> "Triceps"
      "quadriceps" -> "Quads"
      "hamstrings" -> "Hamstrings"
      "glutes" -> "Glutes"
      "calves" -> "Calves"
      "shoulders" -> "Shoulders"
      "abdominals" -> "Abs"
      "rectus abdominis" -> "Abs"
      "lats" -> "Back"
      "latissimus dorsi" -> "Back"
      "traps" -> "Traps"
      "rhomboids" -> "Back"
      "delts" -> "Shoulders"
      other -> String.capitalize(other)
    end
  end

  defp normalize_equipment(nil), do: nil

  defp normalize_equipment(equipment) do
    case String.downcase(equipment) do
      "body weight" -> "Bodyweight"
      "bodyweight" -> "Bodyweight"
      "dumbbell" -> "Dumbbell"
      "dumbbells" -> "Dumbbell"
      "barbell" -> "Barbell"
      "barbells" -> "Barbell"
      "cable" -> "Cable"
      "cable machine" -> "Cable"
      "machine" -> "Machine"
      "kettlebell" -> "Kettlebell"
      "kettlebells" -> "Kettlebell"
      "resistance band" -> "Band"
      "resistance bands" -> "Band"
      "pull-up bar" -> "Pull-up bar"
      other -> String.capitalize(other)
    end
  end

  defp muscle_region(name) do
    case Normalizer.normalize_text(name) do
      normalized
      when normalized in ["chest", "back", "shoulders", "biceps", "triceps", "traps"] ->
        "upper_body"

      normalized when normalized in ["quads", "quadriceps", "hamstrings", "glutes", "calves"] ->
        "lower_body"

      normalized when normalized in ["abs", "core", "abdominals", "rectus abdominis"] ->
        "core"

      _other ->
        nil
    end
  end

  defp equipment_category(name) do
    case Normalizer.normalize_text(name) do
      "bodyweight" -> "bodyweight"
      normalized when normalized in ["barbell", "dumbbell", "kettlebell"] -> "free_weight"
      normalized when normalized in ["machine", "cable"] -> "machine"
      "band" -> "accessory"
      _other -> nil
    end
  end

  defp extract_name(%{"name_en" => name_en, "name" => name}) do
    present_string(name_en) || present_string(name)
  end

  defp extract_name(%{"name_en" => name_en}), do: present_string(name_en)
  defp extract_name(%{"name" => name}), do: present_string(name)
  defp extract_name(value) when is_binary(value), do: present_string(value)
  defp extract_name(_value), do: nil

  defp source_entry_id(%{"id" => id}) when not is_nil(id), do: to_string(id)
  defp source_entry_id(_entry), do: nil

  defp present_string(value) when is_binary(value) do
    value = String.trim(value)
    if value == "", do: nil, else: value
  end

  defp present_string(_value), do: nil

  defp normalize_opts(opts) do
    opts
    |> normalize_optional_positive_integer(:limit)
    |> normalize_optional_positive_integer(:template_id)
  end

  defp normalize_optional_positive_integer(opts, key) do
    Keyword.update(opts, key, nil, fn
      nil -> nil
      value when is_integer(value) and value > 0 -> value
      value when is_binary(value) -> parse_integer(value)
      _invalid -> nil
    end)
  end

  defp parse_integer(nil), do: nil

  defp parse_integer(value) do
    case Integer.parse(to_string(value)) do
      {integer, ""} when integer > 0 -> integer
      _invalid -> nil
    end
  end

  defp failure_report(template_id, reason) do
    @empty_report
    |> Map.update!(:errors, &(&1 + 1))
    |> Map.update!(:failures, &[%{template_id: template_id, error: reason} | &1])
  end

  defp changeset_errors(changeset) do
    Enum.into(changeset.errors, %{}, fn {field, {message, opts}} ->
      rendered =
        Enum.reduce(opts, message, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)

      {field, rendered}
    end)
  end

  defp merge_reports(left, right) do
    Map.merge(left, right, fn
      :failures, left_failures, right_failures -> right_failures ++ left_failures
      _key, left_value, right_value -> left_value + right_value
    end)
  end

  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(value), do: is_nil(value)
end
