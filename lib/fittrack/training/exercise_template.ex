defmodule Fittrack.Training.ExerciseTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.Normalizer

  schema "exercise_templates" do
    field :name, :string
    field :primary_muscle, :string
    field :secondary_muscles, {:array, :string}, default: []
    field :equipment, :string
    field :difficulty, :string
    field :notes, :string
    field :normalized_name, :string
    field :normalized_equipment, :string

    field :movement_pattern, :string
    field :exercise_category, :string
    field :training_style_tags, {:array, :string}, default: []

    timestamps(type: :utc_datetime)
  end

  @movement_patterns ~w(push pull squat hinge lunge carry rotation core isolation)
  @exercise_categories ~w(compound isolation bodyweight machine cardio mobility plyometric accessory)
  @training_styles ~w(bodybuilding powerlifting powerbuilding strength hypertrophy conditioning athletic olympic_weightlifting calisthenics mobility rehab beginner)

  def changeset(template, attrs) do
    template
    |> cast(attrs, [
      :name,
      :primary_muscle,
      :secondary_muscles,
      :equipment,
      :difficulty,
      :notes,
      :movement_pattern,
      :exercise_category,
      :training_style_tags
    ])
    |> validate_required([:name])
    |> validate_inclusion(:difficulty, ["beginner", "intermediate", "advanced"])
    |> validate_inclusion(:movement_pattern, @movement_patterns)
    |> validate_inclusion(:exercise_category, @exercise_categories)
    |> validate_array_subset(:training_style_tags, @training_styles)
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

  defp validate_array_subset(changeset, field, allowed_values) do
    values = get_field(changeset, field, [])

    if Enum.all?(values, &(&1 in allowed_values)) do
      changeset
    else
      add_error(changeset, field, "contains invalid values")
    end
  end
end
