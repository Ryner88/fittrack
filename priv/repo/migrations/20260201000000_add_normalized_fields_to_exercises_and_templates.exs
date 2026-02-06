defmodule Fittrack.Repo.Migrations.AddNormalizedFieldsToExercisesAndTemplates do
  use Ecto.Migration

  def up do
    alter table(:exercise_templates) do
      add :normalized_name, :string, null: false, default: ""
      add :normalized_equipment, :string, null: false, default: ""
    end

    alter table(:exercises) do
      add :normalized_name, :string, null: false, default: ""
      add :normalized_equipment, :string, null: false, default: ""
    end

    execute """
    UPDATE exercise_templates
    SET normalized_name = lower(regexp_replace(trim(name), '\\s+', ' ', 'g')),
        normalized_equipment = lower(regexp_replace(trim(coalesce(equipment, '')), '\\s+', ' ', 'g'))
    """

    execute """
    UPDATE exercises
    SET normalized_name = lower(regexp_replace(trim(name), '\\s+', ' ', 'g')),
        normalized_equipment = lower(regexp_replace(trim(coalesce(equipment, '')), '\\s+', ' ', 'g'))
    """

    alter table(:exercise_templates) do
      modify :normalized_name, :string, null: false, default: nil
      modify :normalized_equipment, :string, null: false, default: nil
    end

    alter table(:exercises) do
      modify :normalized_name, :string, null: false, default: nil
      modify :normalized_equipment, :string, null: false, default: nil
    end

    create unique_index(:exercise_templates, [:normalized_name, :normalized_equipment])
    create unique_index(:exercises, [:user_id, :normalized_name, :normalized_equipment])
  end

  def down do
    drop unique_index(:exercises, [:user_id, :normalized_name, :normalized_equipment])
    drop unique_index(:exercise_templates, [:normalized_name, :normalized_equipment])

    alter table(:exercises) do
      remove :normalized_name
      remove :normalized_equipment
    end

    alter table(:exercise_templates) do
      remove :normalized_name
      remove :normalized_equipment
    end
  end
end
