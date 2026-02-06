defmodule Fittrack.Training.Normalizer do
  @moduledoc false

  def normalize_text(nil), do: ""

  def normalize_text(text) when is_binary(text) do
    text
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
    |> String.downcase()
  end
end
