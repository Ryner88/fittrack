defmodule Fittrack.Training.ExerciseMedia do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.ExerciseTemplate

  schema "exercise_media" do
    field :kind, :string
    field :source, :string
    field :source_id, :string
    field :source_exercise_id, :string
    field :source_url, :string
    field :storage_key, :string
    field :local_path, :string
    field :content_hash, :string
    field :provider_attribution, :string
    field :cache_status, :string, default: "remote_only"
    field :cached_at, :utc_datetime
    field :checked_at, :utc_datetime
    field :failure_reason, :string
    field :mime_type, :string
    field :file_size, :integer
    field :width, :integer
    field :height, :integer
    field :duration_seconds, :integer
    field :display_order, :integer, default: 0
    field :is_primary, :boolean, default: false
    field :metadata, :map, default: %{}

    belongs_to :exercise_template, ExerciseTemplate

    timestamps(type: :utc_datetime)
  end

  def changeset(media, attrs) do
    media
    |> cast(attrs, [
      :exercise_template_id,
      :kind,
      :source,
      :source_id,
      :source_exercise_id,
      :source_url,
      :storage_key,
      :local_path,
      :content_hash,
      :provider_attribution,
      :cache_status,
      :cached_at,
      :checked_at,
      :failure_reason,
      :mime_type,
      :file_size,
      :width,
      :height,
      :duration_seconds,
      :display_order,
      :is_primary,
      :metadata
    ])
    |> validate_required([:exercise_template_id, :kind])
    |> validate_inclusion(:kind, ["image", "video", "thumbnail"])
    |> validate_inclusion(:cache_status, [
      "remote_only",
      "queued",
      "cached",
      "missing",
      "skipped",
      "failed",
      "stale"
    ])
    |> validate_number(:file_size, greater_than: 0)
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_number(:duration_seconds, greater_than: 0)
    |> validate_number(:display_order, greater_than_or_equal_to: 0)
    |> update_change(:source, &trim_optional/1)
    |> update_change(:source_id, &trim_optional/1)
    |> update_change(:source_exercise_id, &trim_optional/1)
    |> update_change(:source_url, &trim_optional/1)
    |> update_change(:storage_key, &trim_optional/1)
    |> update_change(:local_path, &trim_optional/1)
    |> update_change(:content_hash, &trim_optional/1)
    |> update_change(:provider_attribution, &trim_optional/1)
    |> update_change(:failure_reason, &trim_optional/1)
    |> update_change(:mime_type, &trim_optional/1)
    |> unique_constraint([:source, :source_id])
    |> unique_constraint(:source_url)
  end

  defp trim_optional(value) when is_binary(value), do: String.trim(value)
  defp trim_optional(value), do: value
end
