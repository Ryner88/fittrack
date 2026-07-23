defmodule Fittrack.Training.ExerciseVariation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.ExerciseTemplate

  schema "exercise_variations" do
    field :relationship, :string
    field :notes, :string
    field :similarity_score, :integer
    field :equipment_requirements, {:array, :string}, default: []
    field :difficulty_delta, :integer

    belongs_to :base_exercise_template, ExerciseTemplate
    belongs_to :variation_exercise_template, ExerciseTemplate

    timestamps(type: :utc_datetime)
  end

  def changeset(variation, attrs) do
    variation
    |> cast(attrs, [
      :base_exercise_template_id,
      :variation_exercise_template_id,
      :relationship,
      :similarity_score,
      :equipment_requirements,
      :difficulty_delta,
      :notes
    ])
    |> validate_required([
      :base_exercise_template_id,
      :variation_exercise_template_id,
      :relationship
    ])
    |> validate_inclusion(:relationship, [
      "angle",
      "implement",
      "stance",
      "progression",
      "regression"
    ])
    |> validate_number(:similarity_score,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
    |> validate_number(:difficulty_delta,
      greater_than_or_equal_to: -5,
      less_than_or_equal_to: 5
    )
    |> update_change(:equipment_requirements, &normalize_list/1)
    |> validate_not_self_referential()
    |> unique_constraint([
      :base_exercise_template_id,
      :variation_exercise_template_id,
      :relationship
    ])
    |> check_constraint(:base_exercise_template_id,
      name: :exercise_variations_no_self_reference
    )
  end

  defp validate_not_self_referential(changeset) do
    base_id = get_field(changeset, :base_exercise_template_id)
    variation_id = get_field(changeset, :variation_exercise_template_id)

    if base_id && variation_id && base_id == variation_id do
      add_error(
        changeset,
        :variation_exercise_template_id,
        "must be different from base exercise"
      )
    else
      changeset
    end
  end

  defp normalize_list(values) when is_list(values) do
    values
    |> Enum.map(&normalize_text/1)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp normalize_list(_values), do: []

  defp normalize_text(value) when is_binary(value), do: String.trim(value)
  defp normalize_text(_value), do: nil
end
