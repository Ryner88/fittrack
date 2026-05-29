defmodule Fittrack.Training.ExerciseTemplateSource do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.ExerciseTemplate

  schema "exercise_template_sources" do
    field :source, :string
    field :external_id, :string
    field :source_url, :string
    field :payload, :map, default: %{}
    field :imported_at, :utc_datetime

    belongs_to :exercise_template, ExerciseTemplate

    timestamps(type: :utc_datetime)
  end

  def changeset(template_source, attrs) do
    template_source
    |> cast(attrs, [
      :exercise_template_id,
      :source,
      :external_id,
      :source_url,
      :payload,
      :imported_at
    ])
    |> validate_required([:exercise_template_id, :source, :external_id])
    |> update_change(:source, &String.trim/1)
    |> update_change(:external_id, &String.trim/1)
    |> update_change(:source_url, &trim_optional/1)
    |> unique_constraint([:source, :external_id])
  end

  defp trim_optional(value) when is_binary(value), do: String.trim(value)
  defp trim_optional(value), do: value
end
