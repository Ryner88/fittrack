defmodule FittrackWeb.RelationshipMetaHelpers do
  @moduledoc false

  def relationship_meta(relationship) do
    [
      relationship_kind(relationship),
      metadata_score("Match", relationship.similarity_score),
      metadata_score("Reason", Map.get(relationship, :reason_quality)),
      difficulty_delta_label(relationship.difficulty_delta),
      equipment_requirement_label(relationship.equipment_requirements)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" · ")
  end

  def relationship_kind(%{relationship: relationship}), do: format_label(relationship)
  def relationship_kind(%{reason: reason}), do: format_label(reason)
  def relationship_kind(_relationship), do: nil

  def metadata_score(_label, nil), do: nil
  def metadata_score(label, score), do: "#{label} #{score}/100"

  def difficulty_delta_label(nil), do: nil
  def difficulty_delta_label(0), do: "Same difficulty"
  def difficulty_delta_label(delta) when delta > 0, do: "+#{delta} difficulty"
  def difficulty_delta_label(delta), do: "#{delta} difficulty"

  def equipment_requirement_label([]), do: nil
  def equipment_requirement_label(nil), do: nil
  def equipment_requirement_label(equipment), do: "Needs #{Enum.join(equipment, ", ")}"

  defp format_label(nil), do: nil
  defp format_label(""), do: nil

  defp format_label(value) do
    value
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
