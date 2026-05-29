defmodule Fittrack.Training.ExerciseTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.Normalizer
  alias Fittrack.Training.Slug

  schema "exercise_templates" do
    field :source_id, :integer
    field :name, :string
    field :primary_muscle, :string
    field :secondary_muscles, {:array, :string}, default: []
    field :equipment, :string
    field :difficulty, :string
    field :image_url, :string
    field :notes, :string
    field :normalized_name, :string
    field :normalized_equipment, :string
    field :slug, :string
    field :canonical_slug, :string
    field :weighted_tags, {:array, :string}, default: []
    field :is_verified, :boolean, default: false
    field :is_ai_generated, :boolean, default: false
    field :is_deprecated, :boolean, default: false
    field :quality_score, :integer, default: 0
    field :is_unilateral, :boolean
    field :is_compound, :boolean
    field :movement_direction, :string
    field :fatigue_score, :integer
    field :skill_requirement, :string

    field :movement_pattern, :string
    field :exercise_category, :string
    field :training_style_tags, {:array, :string}, default: []

    has_many :template_sources, Fittrack.Training.ExerciseTemplateSource
    has_many :template_muscles, Fittrack.Training.ExerciseTemplateMuscle
    has_many :template_equipment, Fittrack.Training.ExerciseTemplateEquipment
    has_many :media, Fittrack.Training.ExerciseMedia
    has_many :aliases, Fittrack.Training.ExerciseAlias

    has_many :variations, Fittrack.Training.ExerciseVariation,
      foreign_key: :base_exercise_template_id

    has_many :substitutions, Fittrack.Training.ExerciseSubstitution

    timestamps(type: :utc_datetime)
  end

  @movement_patterns ~w(push pull squat hinge lunge carry rotation core isolation)
  @exercise_categories ~w(compound isolation bodyweight machine cardio mobility plyometric accessory)
  @training_styles ~w(bodybuilding powerlifting powerbuilding strength hypertrophy conditioning athletic olympic_weightlifting calisthenics mobility rehab beginner)
  @movement_directions ~w(horizontal_push vertical_push horizontal_pull vertical_pull squat hinge lunge carry rotation anti_rotation flexion extension)
  @skill_requirements ~w(low moderate high)

  def changeset(template, attrs) do
    template
    |> cast(attrs, [
      :source_id,
      :name,
      :primary_muscle,
      :secondary_muscles,
      :equipment,
      :difficulty,
      :image_url,
      :notes,
      :slug,
      :canonical_slug,
      :weighted_tags,
      :is_verified,
      :is_ai_generated,
      :is_deprecated,
      :quality_score,
      :is_unilateral,
      :is_compound,
      :movement_direction,
      :fatigue_score,
      :skill_requirement,
      :movement_pattern,
      :exercise_category,
      :training_style_tags
    ])
    |> validate_required([:name])
    |> validate_inclusion(:difficulty, ["beginner", "intermediate", "advanced"])
    |> validate_inclusion(:movement_pattern, @movement_patterns)
    |> validate_inclusion(:exercise_category, @exercise_categories)
    |> validate_inclusion(:movement_direction, @movement_directions)
    |> validate_inclusion(:skill_requirement, @skill_requirements)
    |> validate_number(:quality_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:fatigue_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
    |> validate_array_subset(:training_style_tags, @training_styles)
    |> update_change(:name, &String.trim/1)
    |> update_change(:primary_muscle, &String.trim/1)
    |> update_change(:equipment, &String.trim/1)
    |> update_change(:difficulty, &String.trim/1)
    |> update_change(:image_url, fn value ->
      if is_binary(value), do: String.trim(value), else: value
    end)
    |> update_change(:notes, &String.trim/1)
    |> update_change(:slug, &Slug.slugify/1)
    |> update_change(:canonical_slug, &Slug.slugify/1)
    |> normalize_fields()
    |> unique_constraint(:source_id)
    |> unique_constraint(:slug)
    |> unique_constraint([:name, :equipment])
    |> unique_constraint([:normalized_name, :normalized_equipment])
  end

  defp normalize_fields(changeset) do
    normalized_name = Normalizer.normalize_text(get_field(changeset, :name))
    normalized_equipment = Normalizer.normalize_text(get_field(changeset, :equipment))

    changeset
    |> put_change(:normalized_name, normalized_name)
    |> put_change(:normalized_equipment, normalized_equipment)
    |> put_default_slug()
    |> put_default_canonical_slug()
  end

  defp put_default_slug(changeset) do
    case get_field(changeset, :slug) do
      nil -> put_change(changeset, :slug, Slug.slugify(get_field(changeset, :name)))
      "" -> put_change(changeset, :slug, Slug.slugify(get_field(changeset, :name)))
      _slug -> changeset
    end
  end

  defp put_default_canonical_slug(changeset) do
    case get_field(changeset, :canonical_slug) do
      nil -> put_change(changeset, :canonical_slug, get_field(changeset, :slug))
      "" -> put_change(changeset, :canonical_slug, get_field(changeset, :slug))
      _slug -> changeset
    end
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
