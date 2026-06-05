defmodule FittrackWeb.WorkoutPlanLive.GeneratorTest do
  use FittrackWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fittrack.TrainingFixtures
  import Fittrack.AccountsFixtures

  defmodule SourceClientStub do
    def get(_url, _opts) do
      {:ok,
       %{
         status: 200,
         body: """
         <html><body>
           <h1>Push workout</h1>
           Warm up first, then use supersets, drop sets, AMRAP finishers, and rest-pause work.
         </body></html>
         """
       }}
    end
  end

  defmodule EmptySourceClientStub do
    def get(_url, _opts) do
      {:ok, %{status: 200, body: "<html><body>No exercise list here.</body></html>"}}
    end
  end

  defmodule EmptyYoutubeSourceClientStub do
    def get(_url, _opts) do
      {:ok, %{status: 200, body: "<html><body><script>window.yt = {}</script></body></html>"}}
    end
  end

  defmodule EmptyWorkoutParserStub do
    def parse_workout_text(_text, _context) do
      {:ok, %{"summary" => "No exercises found", "exercises" => []}}
    end
  end

  defmodule WorkoutParserStub do
    def parse_workout_text(_text, _context) do
      {:ok,
       %{
         "title" => "Parsed Push Plan",
         "summary" => "Structured from linked training content.",
         "safety_notes" => ["Kept failure work away from complex lifts."],
         "exercises" => [
           %{
             "name" => "WGER Bench Press",
             "scheduled_day" => "Monday",
             "target_sets" => 4,
             "target_reps_min" => 6,
             "target_reps_max" => 8,
             "rest_seconds" => 120,
             "target_kind" => "straight_set",
             "notes" => "Main strength movement from source."
           },
           %{
             "name" => "WGER Push-up",
             "scheduled_day" => "Monday",
             "target_sets" => 2,
             "target_reps_min" => 12,
             "target_reps_max" => 20,
             "rest_seconds" => 45,
             "target_kind" => "amrap",
             "notes" => "Source finisher."
           }
         ]
       }}
    end
  end

  defmodule AliasWorkoutParserStub do
    def parse_workout_text(_text, _context) do
      {:ok,
       %{
         "exercises" => [
           %{
             "exercise" => "Bench Press",
             "day" => "Tuesday",
             "sets" => 5,
             "reps" => "5-7",
             "rest" => 150,
             "set_type" => "straight_set"
           }
         ]
       }}
    end
  end

  defp create_exercise(_) do
    user = user_fixture()
    scope = %Fittrack.Accounts.Scope{user: user}
    exercise = exercise_fixture(scope)

    %{exercise: exercise, user: user}
  end

  describe "AI Workout Generator" do
    setup [:create_exercise]

    test "renders generator and creates a plan", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, generator_live, html} = live(conn, ~p"/workout-plans/generator")

      assert html =~ "AI Workout Generator"
      assert html =~ "Training Split"
      assert html =~ "Available Equipment"
      assert html =~ "Source Guide"

      assert has_element?(
               generator_live,
               "#ai-workout-generator-form input[name='ai_workout[duration_minutes]']"
             )

      assert has_element?(
               generator_live,
               "#ai-workout-generator-form input[name='ai_workout[source_url]']"
             )

      assert has_element?(
               generator_live,
               "#ai-workout-generator-form textarea[name='ai_workout[source_transcript]']"
             )

      assert has_element?(generator_live, ~s(button[name="intent"][value="analyze_source"]))

      params = %{
        "primary_goal" => "strength",
        "secondary_goal" => "endurance",
        "training_styles" => ["strength", "mobility"],
        "training_split" => ["upper_lower", "hybrid"],
        "experience" => "beginner",
        "equipment" => ["bodyweight", "dumbbell"],
        "days_per_week" => "3",
        "duration_minutes" => "60"
      }

      html =
        generator_live
        |> form("#ai-workout-generator-form", ai_workout: params)
        |> render_submit()

      assert html =~ "Review Draft"
      assert has_element?(generator_live, "#ai-workout-draft-form")

      assert generator_live
             |> form("#ai-workout-draft-form")
             |> render_submit()

      [plan | _] = Fittrack.Training.list_workout_plans(%Fittrack.Accounts.Scope{user: user})
      assert plan.primary_goal == "strength"
      assert plan.secondary_goal == "endurance"
      assert plan.training_styles == ["strength", "mobility"]
      assert plan.training_split == ["upper_lower", "hybrid"]
      assert plan.estimated_duration_minutes == 60
      assert Enum.any?(plan.workout_plan_exercises, &(&1.target_kind == "top_set"))
    end

    test "requires linked source content to provide detectable exercises", %{
      conn: conn,
      user: user
    } do
      original_client = Application.get_env(:fittrack, :ai_workout_source_http_client)
      Application.put_env(:fittrack, :ai_workout_source_http_client, SourceClientStub)

      on_exit(fn ->
        if original_client do
          Application.put_env(:fittrack, :ai_workout_source_http_client, original_client)
        else
          Application.delete_env(:fittrack, :ai_workout_source_http_client)
        end
      end)

      conn = log_in_user(conn, user)
      {:ok, generator_live, _html} = live(conn, ~p"/workout-plans/generator")

      params = %{
        "primary_goal" => "hypertrophy",
        "training_styles" => ["hypertrophy"],
        "training_split" => ["full_body"],
        "experience" => "intermediate",
        "equipment" => ["bodyweight"],
        "days_per_week" => "3",
        "duration_minutes" => "45",
        "source_url" => "https://example.com/push-workout"
      }

      html =
        generator_live
        |> form("#ai-workout-generator-form", ai_workout: params)
        |> render_submit()

      assert html =~ "Could not detect structured exercises from that link"
      refute has_element?(generator_live, "#ai-workout-draft-form")
      assert Fittrack.Training.list_workout_plans(%Fittrack.Accounts.Scope{user: user}) == []
    end

    test "parses linked content into a structured reviewed FitTrack plan", %{
      conn: conn,
      user: user
    } do
      original_source_client = Application.get_env(:fittrack, :ai_workout_source_http_client)
      original_parser_client = Application.get_env(:fittrack, :ai_workout_parser_client)

      Application.put_env(:fittrack, :ai_workout_source_http_client, SourceClientStub)
      Application.put_env(:fittrack, :ai_workout_parser_client, WorkoutParserStub)

      on_exit(fn ->
        if original_source_client do
          Application.put_env(:fittrack, :ai_workout_source_http_client, original_source_client)
        else
          Application.delete_env(:fittrack, :ai_workout_source_http_client)
        end

        if original_parser_client do
          Application.put_env(:fittrack, :ai_workout_parser_client, original_parser_client)
        else
          Application.delete_env(:fittrack, :ai_workout_parser_client)
        end
      end)

      insert_template("WGER Bench Press", "Barbell")
      insert_template("WGER Push-up", "Bodyweight")

      conn = log_in_user(conn, user)
      {:ok, generator_live, _html} = live(conn, ~p"/workout-plans/generator")

      params = %{
        "primary_goal" => "strength",
        "training_styles" => ["strength"],
        "training_split" => ["full_body"],
        "experience" => "intermediate",
        "equipment" => ["bodyweight", "barbell"],
        "days_per_week" => "3",
        "duration_minutes" => "45",
        "source_url" => "https://example.com/parsed-push-plan"
      }

      html =
        generator_live
        |> form("#ai-workout-generator-form", ai_workout: params)
        |> render_submit()

      assert html =~ "WGER Bench Press"
      assert html =~ "WGER Push-up"
      assert html =~ "AMRAP Set"

      assert generator_live
             |> form("#ai-workout-draft-form")
             |> render_submit()

      [plan | _] = Fittrack.Training.list_workout_plans(%Fittrack.Accounts.Scope{user: user})
      names = Enum.map(plan.workout_plan_exercises, & &1.exercise.name)

      assert "WGER Bench Press" in names
      assert "WGER Push-up" in names
      assert Enum.any?(plan.workout_plan_exercises, &(&1.target_kind == "amrap"))
      assert plan.description =~ "Kept failure work away from complex lifts."
    end

    test "analyzes a pasted source link into a draft without requiring goal fields", %{
      conn: conn,
      user: user
    } do
      original_source_client = Application.get_env(:fittrack, :ai_workout_source_http_client)
      original_parser_client = Application.get_env(:fittrack, :ai_workout_parser_client)

      Application.put_env(:fittrack, :ai_workout_source_http_client, SourceClientStub)
      Application.put_env(:fittrack, :ai_workout_parser_client, WorkoutParserStub)

      on_exit(fn ->
        if original_source_client do
          Application.put_env(:fittrack, :ai_workout_source_http_client, original_source_client)
        else
          Application.delete_env(:fittrack, :ai_workout_source_http_client)
        end

        if original_parser_client do
          Application.put_env(:fittrack, :ai_workout_parser_client, original_parser_client)
        else
          Application.delete_env(:fittrack, :ai_workout_parser_client)
        end
      end)

      insert_template("WGER Bench Press", "Barbell")
      insert_template("WGER Push-up", "Bodyweight")

      conn = log_in_user(conn, user)
      {:ok, generator_live, _html} = live(conn, ~p"/workout-plans/generator")

      html =
        render_submit(generator_live, :generate, %{
          "intent" => "analyze_source",
          "ai_workout" => %{"source_url" => "https://example.com/source-only-plan"}
        })

      assert html =~ "Review Draft"
      assert html =~ "WGER Bench Press"
      assert html =~ "WGER Push-up"
      assert html =~ "Link analyzed"
    end

    test "does not auto-fill random exercises when source analysis finds none", %{
      conn: conn,
      user: user
    } do
      original_source_client = Application.get_env(:fittrack, :ai_workout_source_http_client)
      original_parser_client = Application.get_env(:fittrack, :ai_workout_parser_client)

      Application.put_env(:fittrack, :ai_workout_source_http_client, EmptySourceClientStub)
      Application.put_env(:fittrack, :ai_workout_parser_client, EmptyWorkoutParserStub)

      on_exit(fn ->
        if original_source_client do
          Application.put_env(:fittrack, :ai_workout_source_http_client, original_source_client)
        else
          Application.delete_env(:fittrack, :ai_workout_source_http_client)
        end

        if original_parser_client do
          Application.put_env(:fittrack, :ai_workout_parser_client, original_parser_client)
        else
          Application.delete_env(:fittrack, :ai_workout_parser_client)
        end
      end)

      conn = log_in_user(conn, user)
      {:ok, generator_live, _html} = live(conn, ~p"/workout-plans/generator")
      insert_template("Generic Squat", "Barbell")
      insert_template("Generic Row", "Cable")

      html =
        render_submit(generator_live, :generate, %{
          "intent" => "analyze_source",
          "ai_workout" => %{"source_url" => "https://example.com/no-exercises"}
        })

      assert html =~ "Could not detect structured exercises from that link"
      refute has_element?(generator_live, "#ai-workout-draft-form")
      refute has_element?(generator_live, "#ai-workout-draft-review")
      refute html =~ "Generic Squat"
      refute html =~ "Generic Row"
    end

    test "shows a useful failure for YouTube links without readable transcript text", %{
      conn: conn,
      user: user
    } do
      original_source_client = Application.get_env(:fittrack, :ai_workout_source_http_client)
      original_parser_client = Application.get_env(:fittrack, :ai_workout_parser_client)

      Application.put_env(:fittrack, :ai_workout_source_http_client, EmptyYoutubeSourceClientStub)
      Application.put_env(:fittrack, :ai_workout_parser_client, EmptyWorkoutParserStub)

      on_exit(fn ->
        restore_env(:ai_workout_source_http_client, original_source_client)
        restore_env(:ai_workout_parser_client, original_parser_client)
      end)

      conn = log_in_user(conn, user)
      {:ok, generator_live, _html} = live(conn, ~p"/workout-plans/generator")

      html =
        render_submit(generator_live, :generate, %{
          "intent" => "analyze_source",
          "ai_workout" => %{"source_url" => "https://www.youtube.com/embed/missing-transcript"}
        })

      assert html =~
               "Could not read workout details from that video. If it is a YouTube link, the transcript or page text may be unavailable."

      refute has_element?(generator_live, "#ai-workout-draft-review")
      assert has_element?(generator_live, "#ai-workout-generator-form")
      assert has_element?(generator_live, ~s(input[name="ai_workout[source_url]"]))
      assert has_element?(generator_live, ~s(textarea[name="ai_workout[source_transcript]"]))
    end

    test "uses pasted transcript text when a YouTube link has no readable page workout", %{
      conn: conn,
      user: user
    } do
      original_source_client = Application.get_env(:fittrack, :ai_workout_source_http_client)
      original_parser_client = Application.get_env(:fittrack, :ai_workout_parser_client)

      Application.put_env(:fittrack, :ai_workout_source_http_client, EmptyYoutubeSourceClientStub)
      Application.put_env(:fittrack, :ai_workout_parser_client, WorkoutParserStub)

      on_exit(fn ->
        restore_env(:ai_workout_source_http_client, original_source_client)
        restore_env(:ai_workout_parser_client, original_parser_client)
      end)

      insert_template("WGER Bench Press", "Barbell")
      insert_template("WGER Push-up", "Bodyweight")

      conn = log_in_user(conn, user)
      {:ok, generator_live, _html} = live(conn, ~p"/workout-plans/generator")

      html =
        render_submit(generator_live, :generate, %{
          "intent" => "analyze_source",
          "ai_workout" => %{
            "source_url" => "https://www.youtube.com/embed/missing-transcript",
            "source_transcript" => """
            Bench press 4 sets of 6 to 8 reps, rest two minutes.
            Push-up 2 AMRAP sets, rest 45 seconds.
            """
          }
        })

      assert has_element?(generator_live, "#ai-workout-draft-review")
      assert html =~ "Link analyzed"
      assert html =~ "WGER Bench Press"
      assert html =~ "WGER Push-up"
      assert html =~ ~s(name="draft_plan[workout_plan_exercises][0][target_sets]" value="4")
    end

    test "accepts common parser aliases and fuzzy matches WGER exercises", %{
      conn: conn,
      user: user
    } do
      original_source_client = Application.get_env(:fittrack, :ai_workout_source_http_client)
      original_parser_client = Application.get_env(:fittrack, :ai_workout_parser_client)

      Application.put_env(:fittrack, :ai_workout_source_http_client, SourceClientStub)
      Application.put_env(:fittrack, :ai_workout_parser_client, AliasWorkoutParserStub)

      on_exit(fn ->
        if original_source_client do
          Application.put_env(:fittrack, :ai_workout_source_http_client, original_source_client)
        else
          Application.delete_env(:fittrack, :ai_workout_source_http_client)
        end

        if original_parser_client do
          Application.put_env(:fittrack, :ai_workout_parser_client, original_parser_client)
        else
          Application.delete_env(:fittrack, :ai_workout_parser_client)
        end
      end)

      insert_template("WGER Bench Press", "Barbell")

      conn = log_in_user(conn, user)
      {:ok, generator_live, _html} = live(conn, ~p"/workout-plans/generator")

      params = %{
        "primary_goal" => "strength",
        "experience" => "intermediate",
        "equipment" => ["barbell"],
        "days_per_week" => "3",
        "duration_minutes" => "45",
        "source_url" => "https://example.com/alias-plan"
      }

      html =
        generator_live
        |> form("#ai-workout-generator-form", ai_workout: params)
        |> render_submit()

      assert html =~ "Bench Press"
      assert html =~ "5"
      assert html =~ "7"

      assert generator_live
             |> form("#ai-workout-draft-form")
             |> render_submit()

      [plan | _] = Fittrack.Training.list_workout_plans(%Fittrack.Accounts.Scope{user: user})
      [plan_exercise | _] = plan.workout_plan_exercises

      assert plan_exercise.exercise.name =~ "Bench Press"
      assert plan_exercise.exercise.source_template_id
      assert plan_exercise.target_sets == 5
      assert plan_exercise.target_reps_min == 5
      assert plan_exercise.target_reps_max == 7
      assert plan_exercise.rest_seconds == 150
    end

    test "source analysis populates review form volume, reps, rest, and set type fields", %{
      conn: conn,
      user: user
    } do
      original_source_client = Application.get_env(:fittrack, :ai_workout_source_http_client)
      original_parser_client = Application.get_env(:fittrack, :ai_workout_parser_client)

      Application.put_env(:fittrack, :ai_workout_source_http_client, SourceClientStub)
      Application.put_env(:fittrack, :ai_workout_parser_client, WorkoutParserStub)

      on_exit(fn ->
        restore_env(:ai_workout_source_http_client, original_source_client)
        restore_env(:ai_workout_parser_client, original_parser_client)
      end)

      insert_template("WGER Bench Press", "Barbell")
      insert_template("WGER Push-up", "Bodyweight")

      conn = log_in_user(conn, user)
      {:ok, generator_live, _html} = live(conn, ~p"/workout-plans/generator")

      html =
        render_submit(generator_live, :generate, %{
          "intent" => "analyze_source",
          "ai_workout" => %{"source_url" => "https://example.com/article-push-plan"}
        })

      assert has_element?(generator_live, "#ai-workout-draft-review")
      assert html =~ "Linked source was analyzed"
      assert html =~ "WGER Bench Press"
      assert html =~ ~s(name="draft_plan[workout_plan_exercises][0][target_sets]" value="4")
      assert html =~ ~s(name="draft_plan[workout_plan_exercises][0][target_reps_min]" value="6")
      assert html =~ ~s(name="draft_plan[workout_plan_exercises][0][target_reps_max]" value="8")
      assert html =~ ~s(name="draft_plan[workout_plan_exercises][0][rest_seconds]" value="120")
      assert html =~ ~s(value="straight_set" selected)
    end

    test "rejects duplicate goal selections", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, generator_live, _html} = live(conn, ~p"/workout-plans/generator")

      params = %{
        "primary_goal" => "strength",
        "secondary_goal" => "strength",
        "training_styles" => ["strength"],
        "training_split" => ["full_body"],
        "experience" => "beginner",
        "equipment" => ["bodyweight"],
        "days_per_week" => "3"
      }

      html =
        generator_live
        |> form("#ai-workout-generator-form", ai_workout: params)
        |> render_submit()

      assert html =~ "Each goal must be unique."
      assert Fittrack.Training.list_workout_plans(%Fittrack.Accounts.Scope{user: user}) == []
    end
  end

  defp insert_template(name, equipment) do
    %Fittrack.Training.ExerciseTemplate{}
    |> Fittrack.Training.ExerciseTemplate.changeset(%{
      name: name,
      primary_muscle: "Chest",
      equipment: equipment,
      difficulty: "beginner",
      notes: "WGER imported template"
    })
    |> Fittrack.Repo.insert!()
  end

  defp restore_env(key, nil), do: Application.delete_env(:fittrack, key)
  defp restore_env(key, value), do: Application.put_env(:fittrack, key, value)
end
