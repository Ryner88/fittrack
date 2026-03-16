defmodule Fittrack.Training.ExerciseTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.Normalizer

  schema "exercise_templates" do
    field :name, :string
    field :primary_muscle, :string
    field :equipment, :string
    field :difficulty, :string
    field :notes, :string
    field :normalized_name, :string
    field :normalized_equipment, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name, :primary_muscle, :equipment, :difficulty, :notes])
    |> validate_required([:name])
    |> validate_inclusion(:difficulty, ["beginner", "intermediate", "advanced"])
    |> update_change(:name, &String.trim/1)
    |> update_change(:primary_muscle, &String.trim/1)
    |> update_change(:equipment, &String.trim/1)
    |> update_change(:difficulty, &String.trim/1)
    |> update_change(:notes, &String.trim/1)
    |> normalize_fields()
    |> unique_constraint([:name, :equipment])
    |> unique_constraint([:normalized_name, :normalized_equipment])
  end

  defp normalize_fields(changeset) do
    normalized_name = Normalizer.normalize_text(get_field(changeset, :name))
    normalized_equipment = Normalizer.normalize_text(get_field(changeset, :equipment))

    changeset
    |> put_change(:normalized_name, normalized_name)
    |> put_change(:normalized_equipment, normalized_equipment)
  end
end
