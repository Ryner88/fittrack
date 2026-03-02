defmodule Mix.Tasks.Fittrack.ImportTemplates do
  use Mix.Task

  alias Fittrack.Repo
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.Normalizer

  @shortdoc "Imports exercise templates from JSON or CSV"

  @moduledoc """
  Import exercise templates from a JSON or CSV file.

  ## Examples

      mix fittrack.import_templates priv/data/exercise_templates.json
      mix fittrack.import_templates priv/data/exercise_templates.csv
  """

  @impl true
  def run([path]) do
    Mix.Task.run("app.start")

    path
    |> Path.expand()
    |> import_file()
  end

  def run(_args) do
    Mix.raise("Usage: mix fittrack.import_templates <path_to_json_or_csv>")
  end

  defp import_file(path) do
    case Path.extname(path) do
      ".json" ->
        path
        |> load_json()
        |> upsert_templates(path)

      ".csv" ->
        path
        |> load_csv()
        |> upsert_templates(path)

      ext ->
        Mix.raise("Unsupported file extension: #{ext}. Use .json or .csv")
    end
  end

  defp load_json(path) do
    path
    |> File.read!()
    |> Jason.decode!()
    |> normalize_entries()
  end

  defp load_csv(path) do
    alias NimbleCSV.RFC4180, as: CSV

    rows =
      path
      |> File.stream!()
      |> CSV.parse_stream()
      |> Enum.to_list()

    case rows do
      [] ->
        []

      [header | data_rows] ->
        header_map =
          header
          |> Enum.map(&String.trim/1)
          |> Enum.with_index()
          |> Map.new()

        data_rows
        |> Enum.map(&csv_row_to_entry(&1, header_map))
        |> Enum.reject(&is_nil/1)
    end
  end

  defp normalize_entries(entries) when is_list(entries) do
    entries
    |> Enum.map(&normalize_entry/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_entries(_entries) do
    Mix.raise("JSON file must contain an array of objects")
  end

  defp csv_row_to_entry(row, header_map) do
    name = csv_value(row, header_map, "name")

    if is_nil(name) or name == "" do
      nil
    else
      %{
        name: name,
        primary_muscle: csv_value(row, header_map, "primary_muscle"),
        equipment: csv_value(row, header_map, "equipment"),
        notes: csv_value(row, header_map, "notes")
      }
    end
  end

  defp csv_value(row, header_map, key) do
    case Map.fetch(header_map, key) do
      {:ok, index} ->
        row
        |> Enum.at(index)
        |> normalize_field()

      :error ->
        nil
    end
  end

  defp normalize_entry(entry) when is_map(entry) do
    normalized_entry =
      Map.new(entry, fn {key, value} -> {to_string(key), value} end)

    name = normalize_field(Map.get(normalized_entry, "name"))

    if is_nil(name) or name == "" do
      nil
    else
      %{
        name: name,
        primary_muscle: normalize_field(Map.get(normalized_entry, "primary_muscle")),
        equipment: normalize_field(Map.get(normalized_entry, "equipment")),
        notes: normalize_field(Map.get(normalized_entry, "notes"))
      }
    end
  end

  defp normalize_entry(_entry), do: nil

  defp normalize_field(nil), do: nil

  defp normalize_field(value) when is_binary(value) do
    value
    |> String.trim()
  end

  defp normalize_field(value), do: value |> to_string() |> String.trim()

  defp upsert_templates([], path) do
    Mix.shell().info("No templates found in #{path}")
  end

  defp upsert_templates(entries, path) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    rows =
      Enum.map(entries, fn entry ->
        normalized_name = Normalizer.normalize_text(entry.name)
        normalized_equipment = Normalizer.normalize_text(entry.equipment)

        %{
          name: entry.name,
          primary_muscle: entry.primary_muscle,
          equipment: entry.equipment,
          notes: entry.notes,
          normalized_name: normalized_name,
          normalized_equipment: normalized_equipment,
          inserted_at: now,
          updated_at: now
        }
      end)

    {count, _} =
      Repo.insert_all(ExerciseTemplate, rows,
        on_conflict:
          {:replace,
           [
             :name,
             :primary_muscle,
             :equipment,
             :notes,
             :normalized_name,
             :normalized_equipment,
             :updated_at
           ]},
        conflict_target: [:normalized_name, :normalized_equipment]
      )

    Mix.shell().info("Imported #{count} templates from #{path}")
  end
end
