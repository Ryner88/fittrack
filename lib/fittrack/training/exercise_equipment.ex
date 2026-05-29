defmodule Fittrack.Training.ExerciseEquipment do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.Normalizer

  schema "exercise_equipment" do
    field :name, :string
    field :normalized_name, :string
    field :category, :string
    field :source, :string
    field :source_id, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(equipment, attrs) do
    equipment
    |> cast(attrs, [:name, :category, :source, :source_id])
    |> validate_required([:name])
    |> update_change(:name, &String.trim/1)
    |> update_change(:category, &trim_optional/1)
    |> update_change(:source, &trim_optional/1)
    |> update_change(:source_id, &trim_optional/1)
    |> put_normalized_name()
    |> unique_constraint(:normalized_name)
    |> unique_constraint([:source, :source_id])
  end

  defp put_normalized_name(changeset) do
    put_change(
      changeset,
      :normalized_name,
      Normalizer.normalize_text(get_field(changeset, :name))
    )
  end

  defp trim_optional(value) when is_binary(value), do: String.trim(value)
  defp trim_optional(value), do: value
end
