defmodule Fittrack.Repo.Migrations.AddNutritionImportMetadata do
  use Ecto.Migration

  def change do
    alter table(:foods) do
      add :source_image_metadata, :map
      add :parsed_values, :map
    end

    alter table(:meal_items) do
      add :source_image_metadata, :map
      add :parsed_values, :map
    end
  end
end
