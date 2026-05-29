defmodule Fittrack.Repo.Migrations.AddNutritionImportMetadata do
  use Ecto.Migration

  def up do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_name = 'foods'
      ) THEN
        ALTER TABLE foods
        ADD COLUMN IF NOT EXISTS source_image_metadata jsonb,
        ADD COLUMN IF NOT EXISTS parsed_values jsonb;
      END IF;
    END $$;
    """)

    alter table(:meal_items) do
      add :source_image_metadata, :map
      add :parsed_values, :map
    end
  end

  def down do
    alter table(:meal_items) do
      remove :source_image_metadata
      remove :parsed_values
    end

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_name = 'foods'
      ) THEN
        ALTER TABLE foods
        DROP COLUMN IF EXISTS source_image_metadata,
        DROP COLUMN IF EXISTS parsed_values;
      END IF;
    END $$;
    """)
  end
end
