defmodule Fittrack.Repo.Migrations.CreateFoodsAndUpdateMealItems do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE IF NOT EXISTS foods (
      id bigserial PRIMARY KEY,
      name character varying(255) NOT NULL,
      unit character varying(255) NOT NULL DEFAULT 'g',
      unit_amount numeric(8, 2) NOT NULL DEFAULT 100.0,
      calories_per_unit numeric(8, 2) NOT NULL,
      protein_per_unit numeric(8, 2) DEFAULT 0.0,
      carbs_per_unit numeric(8, 2) DEFAULT 0.0,
      fats_per_unit numeric(8, 2) DEFAULT 0.0,
      fiber_per_unit numeric(8, 2),
      sugar_per_unit numeric(8, 2),
      sodium_mg_per_unit numeric(10, 2),
      micronutrients jsonb,
      source_image_metadata jsonb,
      parsed_values jsonb,
      user_id bigint NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      inserted_at timestamp(0) without time zone NOT NULL,
      updated_at timestamp(0) without time zone NOT NULL
    )
    """)

    create_if_not_exists index(:foods, [:user_id])

    execute("""
    ALTER TABLE meal_items
    ADD COLUMN IF NOT EXISTS food_id bigint
    """)

    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'meal_items_food_id_fkey'
      ) THEN
        ALTER TABLE meal_items
        ADD CONSTRAINT meal_items_food_id_fkey
        FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE SET NULL;
      END IF;
    END $$;
    """)

    create_if_not_exists index(:meal_items, [:food_id])
  end

  def down do
    drop_if_exists index(:meal_items, [:food_id])

    execute("""
    ALTER TABLE meal_items
    DROP CONSTRAINT IF EXISTS meal_items_food_id_fkey
    """)

    alter table(:meal_items) do
      remove :food_id
    end

    drop_if_exists index(:foods, [:user_id])
    drop_if_exists table(:foods)
  end
end
