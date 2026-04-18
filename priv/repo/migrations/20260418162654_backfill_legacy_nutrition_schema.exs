defmodule Fittrack.Repo.Migrations.BackfillLegacyNutritionSchema do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE meals
    ADD COLUMN IF NOT EXISTS eaten_at timestamp without time zone
    """)

    execute("""
    ALTER TABLE meals
    ADD COLUMN IF NOT EXISTS total_calories numeric(8, 2)
    """)

    execute("""
    ALTER TABLE meals
    ADD COLUMN IF NOT EXISTS total_protein_g numeric(8, 2)
    """)

    execute("""
    ALTER TABLE meals
    ADD COLUMN IF NOT EXISTS total_carbs_g numeric(8, 2)
    """)

    execute("""
    ALTER TABLE meals
    ADD COLUMN IF NOT EXISTS total_fats_g numeric(8, 2)
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'meals'
          AND column_name = 'date'
      ) THEN
        UPDATE meals
        SET eaten_at = COALESCE(eaten_at, date::timestamp)
        WHERE eaten_at IS NULL
          AND date IS NOT NULL;
      END IF;
    END $$;
    """)

    execute("""
    ALTER TABLE meal_items
    ADD COLUMN IF NOT EXISTS food_name character varying
    """)

    execute("""
    ALTER TABLE meal_items
    ADD COLUMN IF NOT EXISTS protein_g numeric(8, 2)
    """)

    execute("""
    ALTER TABLE meal_items
    ADD COLUMN IF NOT EXISTS carbs_g numeric(8, 2)
    """)

    execute("""
    ALTER TABLE meal_items
    ADD COLUMN IF NOT EXISTS fats_g numeric(8, 2)
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'meal_items'
          AND column_name = 'calories'
          AND data_type = 'integer'
      ) THEN
        ALTER TABLE meal_items
        ALTER COLUMN calories TYPE numeric(8, 2)
        USING calories::numeric(8, 2);
      END IF;
    END $$;
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'meal_items'
          AND column_name = 'name'
      ) THEN
        UPDATE meal_items
        SET food_name = COALESCE(food_name, name)
        WHERE food_name IS NULL
          AND name IS NOT NULL;
      END IF;
    END $$;
    """)

    execute("""
    UPDATE meal_items AS items
    SET food_name = foods.name
    FROM foods
    WHERE items.food_name IS NULL
      AND items.food_id = foods.id
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'meal_items'
          AND column_name = 'protein'
      ) THEN
        UPDATE meal_items
        SET protein_g = COALESCE(protein_g, protein::numeric(8, 2))
        WHERE protein_g IS NULL
          AND protein IS NOT NULL;
      END IF;
    END $$;
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'meal_items'
          AND column_name = 'carbs'
      ) THEN
        UPDATE meal_items
        SET carbs_g = COALESCE(carbs_g, carbs::numeric(8, 2))
        WHERE carbs_g IS NULL
          AND carbs IS NOT NULL;
      END IF;
    END $$;
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'meal_items'
          AND column_name = 'fat'
      ) THEN
        UPDATE meal_items
        SET fats_g = COALESCE(fats_g, fat::numeric(8, 2))
        WHERE fats_g IS NULL
          AND fat IS NOT NULL;
      END IF;
    END $$;
    """)

    execute("""
    UPDATE meal_items
    SET food_name = COALESCE(food_name, 'Meal item'),
        calories = COALESCE(calories, 0),
        protein_g = COALESCE(protein_g, 0),
        carbs_g = COALESCE(carbs_g, 0),
        fats_g = COALESCE(fats_g, 0)
    """)

    execute("""
    UPDATE meals AS meals
    SET total_calories = totals.total_calories,
        total_protein_g = totals.total_protein_g,
        total_carbs_g = totals.total_carbs_g,
        total_fats_g = totals.total_fats_g
    FROM (
      SELECT
        meal_id,
        COALESCE(SUM(calories), 0)::numeric(8, 2) AS total_calories,
        COALESCE(SUM(protein_g), 0)::numeric(8, 2) AS total_protein_g,
        COALESCE(SUM(carbs_g), 0)::numeric(8, 2) AS total_carbs_g,
        COALESCE(SUM(fats_g), 0)::numeric(8, 2) AS total_fats_g
      FROM meal_items
      GROUP BY meal_id
    ) AS totals
    WHERE meals.id = totals.meal_id
    """)

    execute("""
    UPDATE meals
    SET total_calories = COALESCE(total_calories, 0),
        total_protein_g = COALESCE(total_protein_g, 0),
        total_carbs_g = COALESCE(total_carbs_g, 0),
        total_fats_g = COALESCE(total_fats_g, 0)
    """)

    execute("""
    ALTER TABLE meal_plans
    ADD COLUMN IF NOT EXISTS goal character varying DEFAULT 'maintain'
    """)

    execute("""
    ALTER TABLE meal_plans
    ADD COLUMN IF NOT EXISTS daily_calories_target integer
    """)

    execute("""
    ALTER TABLE meal_plans
    ADD COLUMN IF NOT EXISTS daily_protein_g_target integer
    """)

    execute("""
    ALTER TABLE meal_plans
    ADD COLUMN IF NOT EXISTS daily_carbs_g_target integer
    """)

    execute("""
    ALTER TABLE meal_plans
    ADD COLUMN IF NOT EXISTS daily_fats_g_target integer
    """)

    execute("""
    UPDATE meal_plans
    SET goal = COALESCE(goal, 'maintain')
    """)

    execute("""
    ALTER TABLE meal_plan_meals
    ADD COLUMN IF NOT EXISTS meal_name character varying
    """)

    execute("""
    ALTER TABLE meal_plan_meals
    ADD COLUMN IF NOT EXISTS serving_count numeric(4, 1) DEFAULT 1.0
    """)

    execute("""
    ALTER TABLE meal_plan_meals
    ADD COLUMN IF NOT EXISTS calories_per_serving numeric(8, 2)
    """)

    execute("""
    ALTER TABLE meal_plan_meals
    ADD COLUMN IF NOT EXISTS protein_g_per_serving numeric(8, 2)
    """)

    execute("""
    ALTER TABLE meal_plan_meals
    ADD COLUMN IF NOT EXISTS carbs_g_per_serving numeric(8, 2)
    """)

    execute("""
    ALTER TABLE meal_plan_meals
    ADD COLUMN IF NOT EXISTS fats_g_per_serving numeric(8, 2)
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'meal_plan_meals'
          AND column_name = 'meal_id'
      ) THEN
        UPDATE meal_plan_meals AS planned
        SET meal_name = COALESCE(planned.meal_name, meals.name),
            calories_per_serving = COALESCE(planned.calories_per_serving, meals.total_calories, 0),
            protein_g_per_serving = COALESCE(planned.protein_g_per_serving, meals.total_protein_g, 0),
            carbs_g_per_serving = COALESCE(planned.carbs_g_per_serving, meals.total_carbs_g, 0),
            fats_g_per_serving = COALESCE(planned.fats_g_per_serving, meals.total_fats_g, 0)
        FROM meals
        WHERE planned.meal_id = meals.id;
      END IF;
    END $$;
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'meal_plan_meals'
          AND column_name = 'meal_type'
      ) THEN
        UPDATE meal_plan_meals
        SET meal_name = COALESCE(meal_name, initcap(meal_type), 'Planned meal'),
            serving_count = COALESCE(serving_count, 1.0),
            calories_per_serving = COALESCE(calories_per_serving, 0),
            protein_g_per_serving = COALESCE(protein_g_per_serving, 0),
            carbs_g_per_serving = COALESCE(carbs_g_per_serving, 0),
            fats_g_per_serving = COALESCE(fats_g_per_serving, 0);
      ELSE
        UPDATE meal_plan_meals
        SET meal_name = COALESCE(meal_name, 'Planned meal'),
            serving_count = COALESCE(serving_count, 1.0),
            calories_per_serving = COALESCE(calories_per_serving, 0),
            protein_g_per_serving = COALESCE(protein_g_per_serving, 0),
            carbs_g_per_serving = COALESCE(carbs_g_per_serving, 0),
            fats_g_per_serving = COALESCE(fats_g_per_serving, 0);
      END IF;
    END $$;
    """)
  end

  def down do
    :ok
  end
end
