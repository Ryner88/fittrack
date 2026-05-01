defmodule FittrackWeb.ExerciseLiveTest do
  use FittrackWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fittrack.TrainingFixtures

  alias Fittrack.Repo
  alias Fittrack.Training
  alias Fittrack.Training.ExerciseTemplate

  @create_attrs %{
    name: "some name",
    primary_muscle: "some primary_muscle",
    equipment: "some equipment",
    notes: "some notes"
  }
  @update_attrs %{
    name: "some updated name",
    primary_muscle: "some updated primary_muscle",
    equipment: "some updated equipment",
    notes: "some updated notes"
  }
  @invalid_attrs %{name: nil, primary_muscle: nil, equipment: nil, notes: nil}
  defp create_exercise(_) do
    user = Fittrack.AccountsFixtures.user_fixture()
    scope = %Fittrack.Accounts.Scope{user: user}
    exercise = exercise_fixture(scope)

    %{exercise: exercise, user: user}
  end

  describe "Index" do
    setup [:create_exercise]

    test "lists all exercises", %{conn: conn, exercise: exercise, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _index_live, html} = live(conn, ~p"/exercises")

      assert html =~ "Listing Exercises"
      assert html =~ exercise.name
    end

    test "renders exercise images through the local proxy", %{conn: conn, user: user} do
      scope = %Fittrack.Accounts.Scope{user: user}

      {:ok, template} =
        %ExerciseTemplate{}
        |> ExerciseTemplate.changeset(%{
          name: "Pull-up",
          primary_muscle: "Back",
          equipment: "Pull-up bar",
          image_url: "https://wger.de/media/exercise-images/2002/main.jpg"
        })
        |> Repo.insert()

      {:ok, exercise} = Training.add_template_to_user(scope, template.id)

      conn = log_in_user(conn, user)
      {:ok, _index_live, html} = live(conn, ~p"/exercises")

      assert html =~ ~s(src="/exercise-template-images/#{template.id}")
      refute html =~ template.image_url

      {:ok, _show_live, show_html} = live(conn, ~p"/exercises/#{exercise}")
      assert show_html =~ ~s(src="/exercise-template-images/#{template.id}")
      refute show_html =~ template.image_url
    end

    test "saves new exercise", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, form_live, _html} = live(conn, ~p"/exercises/new")

      assert render(form_live) =~ "New Exercise"

      assert form_live
             |> form("#exercise-form", exercise: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      form_live
      |> form("#exercise-form", exercise: @create_attrs)
      |> render_submit()

      scope = %Fittrack.Accounts.Scope{user: user}
      assert Enum.any?(Fittrack.Training.list_exercises(scope), &(&1.name == "some name"))

      {:ok, index_live, _html} = live(conn, ~p"/exercises")

      html = render(index_live)
      assert html =~ "some name"
    end

    test "updates exercise in listing", %{conn: conn, exercise: exercise, user: user} do
      conn = log_in_user(conn, user)
      {:ok, index_live, _html} = live(conn, ~p"/exercises")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#exercises-#{exercise.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/exercises/#{exercise}/edit")

      assert render(form_live) =~ "Edit Exercise"

      assert form_live
             |> form("#exercise-form", exercise: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#exercise-form", exercise: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/exercises")

      html = render(index_live)
      assert html =~ "Exercise updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes exercise in listing", %{conn: conn, exercise: exercise, user: user} do
      conn = log_in_user(conn, user)
      {:ok, index_live, _html} = live(conn, ~p"/exercises")

      assert index_live |> element("#exercises-#{exercise.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#exercises-#{exercise.id}")
    end
  end

  describe "Show" do
    setup [:create_exercise]

    test "displays exercise", %{conn: conn, exercise: exercise, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _show_live, html} = live(conn, ~p"/exercises/#{exercise}")

      assert html =~ "Show Exercise"
      assert html =~ exercise.name
    end

    test "updates exercise and returns to show", %{conn: conn, exercise: exercise, user: user} do
      conn = log_in_user(conn, user)
      {:ok, show_live, _html} = live(conn, ~p"/exercises/#{exercise}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/exercises/#{exercise}/edit?return_to=show")

      assert render(form_live) =~ "Edit Exercise"

      assert form_live
             |> form("#exercise-form", exercise: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#exercise-form", exercise: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/exercises/#{exercise}")

      html = render(show_live)
      assert html =~ "Exercise updated successfully"
      assert html =~ "some updated name"
    end
  end
end
