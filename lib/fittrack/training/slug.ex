defmodule Fittrack.Training.Slug do
  @moduledoc false

  alias Fittrack.Training.Normalizer

  def slugify(nil), do: nil

  def slugify(value) do
    value
    |> Normalizer.normalize_text()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> case do
      "" -> nil
      slug -> slug
    end
  end
end
