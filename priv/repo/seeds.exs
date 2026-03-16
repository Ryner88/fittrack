alias Fittrack.Repo
alias Fittrack.Training.ExerciseTemplate

now = DateTime.utc_now() |> DateTime.truncate(:second)

templates =
  [
    %{
      name: "Barbell Bench Press",
      primary_muscle: "Chest",
      equipment: "Barbell",
      difficulty: "intermediate",
      notes: nil,
      normalized_name: "barbell bench press",
      normalized_equipment: "barbell"
    },
    %{
      name: "Back Squat",
      primary_muscle: "Quads",
      equipment: "Barbell",
      difficulty: "intermediate",
      notes: nil,
      normalized_name: "back squat",
      normalized_equipment: "barbell"
    },
    %{
      name: "Deadlift",
      primary_muscle: "Posterior Chain",
      equipment: "Barbell",
      difficulty: "advanced",
      notes: nil,
      normalized_name: "deadlift",
      normalized_equipment: "barbell"
    },
    %{
      name: "Lat Pulldown",
      primary_muscle: "Back",
      equipment: "Cable",
      difficulty: "beginner",
      notes: nil,
      normalized_name: "lat pulldown",
      normalized_equipment: "cable"
    },
    %{
      name: "Dumbbell Shoulder Press",
      primary_muscle: "Shoulders",
      equipment: "Dumbbells",
      difficulty: "intermediate",
      notes: nil,
      normalized_name: "dumbbell shoulder press",
      normalized_equipment: "dumbbells"
    },
    %{
      name: "Pull-ups",
      primary_muscle: "Back",
      equipment: "Bodyweight",
      difficulty: "advanced",
      notes: nil,
      normalized_name: "pull-ups",
      normalized_equipment: "bodyweight"
    },
    %{
      name: "Push-ups",
      primary_muscle: "Chest",
      equipment: "Bodyweight",
      difficulty: "beginner",
      notes: nil,
      normalized_name: "push-ups",
      normalized_equipment: "bodyweight"
    },
    %{
      name: "Romanian Deadlift",
      primary_muscle: "Hamstrings",
      equipment: "Barbell",
      difficulty: "intermediate",
      notes: nil,
      normalized_name: "romanian deadlift",
      normalized_equipment: "barbell"
    },
    %{
      name: "Bicep Curls",
      primary_muscle: "Biceps",
      equipment: "Dumbbells",
      difficulty: "beginner",
      notes: nil,
      normalized_name: "bicep curls",
      normalized_equipment: "dumbbells"
    },
    %{
      name: "Tricep Dips",
      primary_muscle: "Triceps",
      equipment: "Bodyweight",
      difficulty: "beginner",
      notes: nil,
      normalized_name: "tricep dips",
      normalized_equipment: "bodyweight"
    }
  ]
  |> Enum.map(fn t -> Map.merge(t, %{inserted_at: now, updated_at: now}) end)

Repo.insert_all(
  ExerciseTemplate,
  templates,
  on_conflict: :nothing,
  conflict_target: [:normalized_name, :normalized_equipment]
)

IO.puts("Seeded exercise_templates: #{length(templates)} (duplicates ignored)")
