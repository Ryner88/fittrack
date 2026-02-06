defmodule Fittrack.Training.Exercise do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Accounts.User
  alias Fittrack.Training.Normalizer
  alias Fittrack.Training.WorkoutSet

  schema "exercises" do
    field :name, :string
    field :primary_muscle, :string
    field :equipment, :string
    field :notes, :string
    field :normalized_name, :string
    field :normalized_equipment, :string

    belongs_to :user, User
    has_many :workout_sets, WorkoutSet

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(exercise, attrs) do
    exercise
    |> cast(attrs, [:name, :primary_muscle, :equipment, :notes])
    |> validate_required([:name, :primary_muscle, :equipment])
    |> update_change(:name, &String.trim/1)
    |> update_change(:primary_muscle, &String.trim/1)
    |> update_change(:equipment, &String.trim/1)
    |> update_change(:notes, &String.trim/1)
    |> normalize_fields()
    |> unique_constraint([:user_id, :normalized_name, :normalized_equipment])
  end

  defp normalize_fields(changeset) do
    normalized_name = Normalizer.normalize_text(get_field(changeset, :name))
    normalized_equipment = Normalizer.normalize_text(get_field(changeset, :equipment))

    changeset
    |> put_change(:normalized_name, normalized_name)
    |> put_change(:normalized_equipment, normalized_equipment)
  end
end
