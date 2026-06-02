defmodule Fittrack.Repo.Migrations.CreateNormalizedExerciseLibrary do
  use Ecto.Migration

  def change do
    create table(:exercise_muscles) do
      add :name, :string, null: false
      add :normalized_name, :string, null: false
      add :region, :string
      add :source, :string
      add :source_id, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:exercise_muscles, [:normalized_name])
    create index(:exercise_muscles, [:region])

    create unique_index(:exercise_muscles, [:source, :source_id],
             where: "source IS NOT NULL AND source_id IS NOT NULL"
           )

    create table(:exercise_equipment) do
      add :name, :string, null: false
      add :normalized_name, :string, null: false
      add :category, :string
      add :source, :string
      add :source_id, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:exercise_equipment, [:normalized_name])
    create index(:exercise_equipment, [:category])

    create unique_index(:exercise_equipment, [:source, :source_id],
             where: "source IS NOT NULL AND source_id IS NOT NULL"
           )

    create table(:exercise_template_sources) do
      add :exercise_template_id, references(:exercise_templates, on_delete: :delete_all),
        null: false

      add :source, :string, null: false
      add :external_id, :string, null: false
      add :source_url, :string
      add :payload, :map, default: %{}
      add :imported_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:exercise_template_sources, [:exercise_template_id])
    create unique_index(:exercise_template_sources, [:source, :external_id])

    alter table(:exercise_templates) do
      add :slug, :string
      add :canonical_slug, :string
      add :search_vector, :tsvector
      add :weighted_tags, {:array, :string}, default: []
      add :is_verified, :boolean, null: false, default: false
      add :is_ai_generated, :boolean, null: false, default: false
      add :is_deprecated, :boolean, null: false, default: false
      add :quality_score, :integer, null: false, default: 0
      add :is_unilateral, :boolean
      add :is_compound, :boolean
      add :movement_direction, :string
      add :fatigue_score, :integer
      add :skill_requirement, :string
    end

    create unique_index(:exercise_templates, [:slug], where: "slug IS NOT NULL")
    create index(:exercise_templates, [:canonical_slug])
    create index(:exercise_templates, [:is_verified])
    create index(:exercise_templates, [:is_deprecated])
    create index(:exercise_templates, [:quality_score])
    create index(:exercise_templates, [:movement_direction])
    create index(:exercise_templates, [:is_unilateral])
    create index(:exercise_templates, [:is_compound])

    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm", ""

    execute """
            CREATE INDEX exercise_templates_name_trgm_idx
            ON exercise_templates
            USING GIN (name gin_trgm_ops)
            """,
            """
            DROP INDEX exercise_templates_name_trgm_idx
            """

    execute """
            CREATE INDEX exercise_templates_weighted_tags_gin_idx
            ON exercise_templates
            USING GIN (weighted_tags)
            """,
            """
            DROP INDEX exercise_templates_weighted_tags_gin_idx
            """

    execute """
            CREATE INDEX exercise_templates_search_vector_gin_idx
            ON exercise_templates
            USING GIN (search_vector)
            """,
            """
            DROP INDEX exercise_templates_search_vector_gin_idx
            """

    execute """
            WITH normalized AS (
              SELECT 
                id,
                regexp_replace(lower(trim(name)), '[^a-z0-9]+', '-', 'g') as base_slug,
                ROW_NUMBER() OVER (PARTITION BY regexp_replace(lower(trim(name)), '[^a-z0-9]+', '-', 'g') ORDER BY id) as rn,
                to_tsvector(
                  'simple',
                  coalesce(name, '') || ' ' ||
                  coalesce(primary_muscle, '') || ' ' ||
                  coalesce(equipment, '') || ' ' ||
                  coalesce(notes, '')
                ) as search_vec
              FROM exercise_templates
              WHERE slug IS NULL
            )
            UPDATE exercise_templates et
            SET 
              slug = CASE 
                WHEN normalized.rn > 1 THEN normalized.base_slug || '-' || normalized.rn
                ELSE normalized.base_slug
              END,
              canonical_slug = normalized.base_slug,
              search_vector = normalized.search_vec
            FROM normalized
            WHERE et.id = normalized.id
            """,
            ""

    create table(:exercise_aliases) do
      add :exercise_template_id, references(:exercise_templates, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :normalized_name, :string, null: false
      add :slug, :string, null: false
      add :kind, :string, null: false, default: "alias"
      add :source, :string
      add :weight, :integer, null: false, default: 1

      timestamps(type: :utc_datetime)
    end

    create index(:exercise_aliases, [:exercise_template_id])
    create index(:exercise_aliases, [:kind])
    create index(:exercise_aliases, [:weight])
    create unique_index(:exercise_aliases, [:exercise_template_id, :normalized_name])
    create unique_index(:exercise_aliases, [:slug])

    execute """
            CREATE INDEX exercise_aliases_name_trgm_idx
            ON exercise_aliases
            USING GIN (name gin_trgm_ops)
            """,
            """
            DROP INDEX exercise_aliases_name_trgm_idx
            """

    create table(:exercise_variations) do
      add :base_exercise_template_id, references(:exercise_templates, on_delete: :delete_all),
        null: false

      add :variation_exercise_template_id,
          references(:exercise_templates, on_delete: :delete_all),
          null: false

      add :relationship, :string, null: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:exercise_variations, [:base_exercise_template_id])
    create index(:exercise_variations, [:variation_exercise_template_id])
    create index(:exercise_variations, [:relationship])

    create unique_index(:exercise_variations, [
             :base_exercise_template_id,
             :variation_exercise_template_id,
             :relationship
           ])

    create constraint(:exercise_variations, :exercise_variations_no_self_reference,
             check: "base_exercise_template_id <> variation_exercise_template_id"
           )

    create table(:exercise_substitutions) do
      add :exercise_template_id, references(:exercise_templates, on_delete: :delete_all),
        null: false

      add :substitute_exercise_template_id,
          references(:exercise_templates, on_delete: :delete_all),
          null: false

      add :reason, :string
      add :priority, :integer, null: false, default: 0
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:exercise_substitutions, [:exercise_template_id])
    create index(:exercise_substitutions, [:substitute_exercise_template_id])
    create index(:exercise_substitutions, [:reason])
    create index(:exercise_substitutions, [:priority])

    create unique_index(:exercise_substitutions, [
             :exercise_template_id,
             :substitute_exercise_template_id
           ])

    create constraint(:exercise_substitutions, :exercise_substitutions_no_self_reference,
             check: "exercise_template_id <> substitute_exercise_template_id"
           )

    create table(:exercise_template_muscles) do
      add :exercise_template_id, references(:exercise_templates, on_delete: :delete_all),
        null: false

      add :exercise_muscle_id, references(:exercise_muscles, on_delete: :restrict), null: false
      add :role, :string, null: false
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:exercise_template_muscles, [:exercise_template_id])
    create index(:exercise_template_muscles, [:exercise_muscle_id])
    create index(:exercise_template_muscles, [:role])

    create unique_index(:exercise_template_muscles, [
             :exercise_template_id,
             :exercise_muscle_id,
             :role
           ])

    create table(:exercise_template_equipment) do
      add :exercise_template_id, references(:exercise_templates, on_delete: :delete_all),
        null: false

      add :exercise_equipment_id, references(:exercise_equipment, on_delete: :restrict),
        null: false

      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:exercise_template_equipment, [:exercise_template_id])
    create index(:exercise_template_equipment, [:exercise_equipment_id])

    create unique_index(:exercise_template_equipment, [
             :exercise_template_id,
             :exercise_equipment_id
           ])

    create table(:exercise_media) do
      add :exercise_template_id, references(:exercise_templates, on_delete: :delete_all),
        null: false

      add :kind, :string, null: false
      add :source, :string
      add :source_id, :string
      add :source_url, :string
      add :storage_key, :string
      add :content_hash, :string
      add :provider_attribution, :string
      add :cache_status, :string, null: false, default: "remote_only"
      add :cached_at, :utc_datetime
      add :mime_type, :string
      add :width, :integer
      add :height, :integer
      add :is_primary, :boolean, null: false, default: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:exercise_media, [:exercise_template_id])
    create index(:exercise_media, [:kind])
    create index(:exercise_media, [:is_primary])
    create index(:exercise_media, [:cache_status])
    create index(:exercise_media, [:cached_at])
    create unique_index(:exercise_media, [:content_hash], where: "content_hash IS NOT NULL")

    create unique_index(:exercise_media, [:source, :source_id],
             where: "source IS NOT NULL AND source_id IS NOT NULL"
           )

    create unique_index(:exercise_media, [:source_url], where: "source_url IS NOT NULL")

    alter table(:exercises) do
      add :slug, :string
      add :instructions, :text
      add :is_custom, :boolean, null: false, default: false
      add :is_private, :boolean, null: false, default: true
      add :custom_media, :map, default: %{}
      add :search_vector, :tsvector
    end

    create unique_index(:exercises, [:user_id, :slug], where: "slug IS NOT NULL")
    create index(:exercises, [:is_custom])

    execute """
            CREATE INDEX exercises_name_trgm_idx
            ON exercises
            USING GIN (name gin_trgm_ops)
            """,
            """
            DROP INDEX exercises_name_trgm_idx
            """

    execute """
            CREATE INDEX exercises_search_vector_gin_idx
            ON exercises
            USING GIN (search_vector)
            """,
            """
            DROP INDEX exercises_search_vector_gin_idx
            """
  end
end
