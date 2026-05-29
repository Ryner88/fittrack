defmodule Fittrack.Repo.Migrations.AddExtendedNutritionFields do
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
        ADD COLUMN IF NOT EXISTS fiber_per_unit numeric(8, 2),
        ADD COLUMN IF NOT EXISTS sugar_per_unit numeric(8, 2),
        ADD COLUMN IF NOT EXISTS sodium_mg_per_unit numeric(10, 2),
        ADD COLUMN IF NOT EXISTS micronutrients jsonb;
      END IF;
    END $$;
    """)

    alter table(:meal_items) do
      add :fiber_g, :decimal, precision: 8, scale: 2
      add :sugar_g, :decimal, precision: 8, scale: 2
      add :sodium_mg, :decimal, precision: 10, scale: 2
      add :micronutrients, :map
    end
  end

  def down do
    alter table(:meal_items) do
      remove :fiber_g
      remove :sugar_g
      remove :sodium_mg
      remove :micronutrients
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
        DROP COLUMN IF EXISTS fiber_per_unit,
        DROP COLUMN IF EXISTS sugar_per_unit,
        DROP COLUMN IF EXISTS sodium_mg_per_unit,
        DROP COLUMN IF EXISTS micronutrients;
      END IF;
    END $$;
    """)
  end
end
