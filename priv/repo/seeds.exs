alias Fittrack.Repo
alias Fittrack.Training.ExerciseTemplate

now = DateTime.utc_now() |> DateTime.truncate(:second)

templates =
  [
    %{name: "Barbell Bench Press", primary_muscle: "Chest", equipment: "Barbell", notes: nil},
    %{name: "Back Squat", primary_muscle: "Quads", equipment: "Barbell", notes: nil},
    %{name: "Deadlift", primary_muscle: "Posterior Chain", equipment: "Barbell", notes: nil},
    %{name: "Lat Pulldown", primary_muscle: "Back", equipment: "Cable", notes: nil}
  ]
  |> Enum.map(fn t -> Map.merge(t, %{inserted_at: now, updated_at: now}) end)

Repo.insert_all(
  ExerciseTemplate,
  templates,
  on_conflict: :nothing,
  conflict_target: [:name, :equipment]
)

IO.puts("Seeded exercise_templates: #{length(templates)} (duplicates ignored)")
