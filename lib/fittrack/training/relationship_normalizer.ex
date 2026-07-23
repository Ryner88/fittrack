defmodule Fittrack.Training.RelationshipNormalizer do
  @moduledoc false

  def normalize_list(values) when is_list(values) do
    values
    |> Enum.map(&normalize_text/1)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  def normalize_list(_values), do: []

  def normalize_text(value) when is_binary(value), do: String.trim(value)
  def normalize_text(_value), do: nil
end
