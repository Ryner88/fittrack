defmodule Fittrack.Repo.Migrations.AddCacheFieldsToExerciseMedia do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:exercise_media, [:content_hash],
                     where: "content_hash IS NOT NULL"
                   )

    alter table(:exercise_media) do
      add :source_exercise_id, :string
      add :local_path, :string
      add :file_size, :integer
      add :failure_reason, :text
      add :checked_at, :utc_datetime
      add :display_order, :integer, null: false, default: 0
      add :duration_seconds, :integer
    end

    create index(:exercise_media, [:source_exercise_id])
    create index(:exercise_media, [:display_order])
    create index(:exercise_media, [:checked_at])
    create index(:exercise_media, [:content_hash], where: "content_hash IS NOT NULL")
  end
end
