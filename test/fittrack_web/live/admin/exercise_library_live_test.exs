defmodule FittrackWeb.Admin.ExerciseLibraryLiveTest do
  use FittrackWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fittrack.Repo
  alias Fittrack.Training
  alias Fittrack.Training.ExerciseAlias
  alias Fittrack.Training.ExerciseEquipment
  alias Fittrack.Training.ExerciseMedia
  alias Fittrack.Training.ExerciseMuscle
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.ExerciseTemplateEquipment
  alias Fittrack.Training.ExerciseTemplateImporter
  alias Fittrack.Training.ExerciseTemplateMuscle
  alias Fittrack.Training.ExerciseTemplateSource

  setup %{conn: conn} do
    user = Fittrack.AccountsFixtures.user_fixture(%{is_admin: true})
    {:ok, conn: log_in_user(conn, user), user: user}
  end

  test "admin can list and search templates by alias/source/tag/muscle/equipment/media status", %{
    conn: conn
  } do
    bench =
      template_fixture(%{
        name: "Barbell Bench Press",
        primary_muscle: "Chest",
        equipment: "Barbell",
        weighted_tags: ["horizontal_push"]
      })

    squat =
      template_fixture(%{name: "Goblet Squat", primary_muscle: "Quads", equipment: "Kettlebell"})

    alias_fixture(bench, "bb bench")
    muscle_fixture(bench, "Chest")
    equipment_fixture(bench, "Barbell")
    media_fixture(bench, %{cache_status: "cached", local_path: "bench/cached.jpg"})
    source_fixture(bench, %{source: "wger", external_id: "8101"})

    {:ok, view, _html} = live(conn, ~p"/admin/exercises")

    assert has_element?(view, "#exercise-admin-metrics")
    assert has_element?(view, "#exercise-media-status-metrics")
    assert has_element?(view, "#admin-exercise-template-list")
    assert has_element?(view, "#admin-exercise-library-link")

    view
    |> form("#admin-template-filter-form",
      filters: %{
        search: "bb bench",
        source: "wger",
        tag: "horizontal_push",
        muscle_group: "Chest",
        equipment: "Barbell",
        media_status: "cached"
      }
    )
    |> render_change()

    assert_patch(
      view,
      ~p"/admin/exercises?equipment=Barbell&media_status=cached&muscle_group=Chest&search=bb+bench&source=wger&tag=horizontal_push"
    )

    assert has_element?(view, "#admin-exercise-template-#{bench.id}")
    refute has_element?(view, "#admin-exercise-template-#{squat.id}")
  end

  test "admin can create a shared exercise template", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/exercises/new")

    view
    |> form("#admin-template-form",
      template: %{
        name: "Cable Fly",
        slug: "cable-fly",
        primary_muscle: "Chest",
        equipment: "Cable",
        difficulty: "beginner",
        notes: "Keep a soft elbow.",
        weighted_tags: "chest, cable",
        aliases_text: "Cable crossover",
        muscle_names: "Chest",
        equipment_names: "Cable",
        source_name: "admin",
        source_external_id: "cable-fly",
        source_payload: ~s({"reviewed":true}),
        is_verified: "true",
        quality_score: "85"
      }
    )
    |> render_submit()

    template =
      Repo.get_by!(ExerciseTemplate, slug: "cable-fly")
      |> Repo.preload([:aliases, :template_sources])

    assert_redirect(view, ~p"/admin/exercises/#{template.id}")
    assert template.name == "Cable Fly"
    assert template.is_verified
    assert Enum.map(template.aliases, & &1.name) == ["Cable crossover"]
    assert [%{source: "admin", external_id: "cable-fly"}] = template.template_sources
  end

  test "admin can edit a shared exercise template", %{conn: conn} do
    template = template_fixture(%{name: "Low Row", slug: "low-row", primary_muscle: "Back"})
    alias_fixture(template, "seated low row")

    {:ok, view, _html} = live(conn, ~p"/admin/exercises/#{template.id}/edit")

    view
    |> form("#admin-template-form",
      template: %{
        name: "Cable Low Row",
        slug: "cable-low-row",
        primary_muscle: "Back",
        equipment: "Cable",
        difficulty: "intermediate",
        aliases_text: "seated cable row",
        weighted_tags: "back, horizontal_pull",
        muscle_names: "Back",
        equipment_names: "Cable",
        is_verified: "true",
        quality_score: "92"
      }
    )
    |> render_submit()

    updated = Training.get_admin_exercise_template!(template.id)

    assert_redirect(view, ~p"/admin/exercises/#{template.id}")
    assert updated.name == "Cable Low Row"
    assert updated.slug == "cable-low-row"
    assert updated.weighted_tags == ["back", "horizontal_pull"]
    assert Enum.map(updated.aliases, & &1.name) == ["seated cable row"]
    assert Enum.map(updated.template_equipment, & &1.exercise_equipment.name) == ["Cable"]
  end

  test "admin can review media, source, alias, and tag info", %{conn: conn} do
    attrs =
      ExerciseTemplateImporter.normalize_exercise_from_wger(%{
        "id" => 8102,
        "translations" => [
          %{"language" => 2, "name" => "Attribution Row", "description" => "Imported."}
        ],
        "muscles" => [%{"name_en" => "Chest"}],
        "equipment" => [%{"name" => "Body weight"}],
        "images" => [
          %{
            "id" => 9102,
            "image" => "https://wger.de/media/exercise-images/8102/main.jpg",
            "license_author" => "wger project"
          }
        ]
      })

    assert {:ok, :inserted, template} = ExerciseTemplateImporter.upsert_template(attrs)
    alias_fixture(template, "import row")
    media_fixture(template, %{cache_status: "failed", failure_reason: "404 from source"})

    {:ok, _view, html} = live(conn, ~p"/admin/exercises/#{template.id}")

    assert html =~ "Attribution Row"
    assert html =~ "import row"
    assert html =~ "wger"
    assert html =~ "Payload keys:"
    assert html =~ "failed"
    assert html =~ "404 from source"
    assert html =~ "wger project"
  end

  test "archive requires explicit confirmation and does not hard delete the template", %{
    conn: conn
  } do
    template = template_fixture(%{name: "Archive Candidate", slug: "archive-candidate"})

    {:ok, view, _html} = live(conn, ~p"/admin/exercises/#{template.id}")

    view
    |> form("#admin-template-archive-form", archive: %{confirm: "DELETE"})
    |> render_submit()

    refute Repo.reload!(template).is_deprecated

    view
    |> form("#admin-template-archive-form", archive: %{confirm: "ARCHIVE"})
    |> render_submit()

    assert_redirect(view, ~p"/admin/exercises/#{template.id}")
    archived = Repo.reload!(template)
    assert archived.is_deprecated
  end

  test "non-admin and unauthenticated users cannot access admin CRUD", %{conn: admin_conn} do
    user = Fittrack.AccountsFixtures.user_fixture()
    conn = admin_conn |> recycle() |> log_in_user(user)

    assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/admin/exercises")

    guest_conn = recycle(admin_conn)
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(guest_conn, ~p"/admin/exercises")
  end

  defp template_fixture(attrs) do
    attrs =
      Map.merge(
        %{
          name: "Romanian Deadlift",
          primary_muscle: "Hamstrings",
          equipment: "Barbell",
          difficulty: "intermediate",
          exercise_category: "compound"
        },
        Map.new(attrs)
      )

    %ExerciseTemplate{}
    |> ExerciseTemplate.changeset(attrs)
    |> Repo.insert!()
  end

  defp alias_fixture(template, name) do
    %ExerciseAlias{}
    |> ExerciseAlias.changeset(%{
      exercise_template_id: template.id,
      name: name,
      kind: "abbreviation",
      weight: 10
    })
    |> Repo.insert!()
  end

  defp muscle_fixture(template, name) do
    muscle =
      %ExerciseMuscle{}
      |> ExerciseMuscle.changeset(%{name: name})
      |> Repo.insert!()

    %ExerciseTemplateMuscle{}
    |> ExerciseTemplateMuscle.changeset(%{
      exercise_template_id: template.id,
      exercise_muscle_id: muscle.id,
      role: "primary",
      position: 0
    })
    |> Repo.insert!()
  end

  defp equipment_fixture(template, name) do
    equipment =
      %ExerciseEquipment{}
      |> ExerciseEquipment.changeset(%{name: name})
      |> Repo.insert!()

    %ExerciseTemplateEquipment{}
    |> ExerciseTemplateEquipment.changeset(%{
      exercise_template_id: template.id,
      exercise_equipment_id: equipment.id,
      position: 0
    })
    |> Repo.insert!()
  end

  defp source_fixture(template, attrs) do
    %ExerciseTemplateSource{}
    |> ExerciseTemplateSource.changeset(
      Map.merge(
        %{
          exercise_template_id: template.id,
          source: "admin",
          external_id: "source-#{template.id}",
          payload: %{"seed" => true}
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  defp media_fixture(template, attrs) do
    %ExerciseMedia{}
    |> ExerciseMedia.changeset(
      Map.merge(
        %{
          exercise_template_id: template.id,
          kind: "image",
          source: "wger",
          source_id: "media-#{template.id}-#{System.unique_integer([:positive])}",
          source_exercise_id: to_string(template.source_id),
          source_url: "https://wger.de/media/#{template.id}.jpg",
          cache_status: "remote_only",
          provider_attribution: "wger project",
          is_primary: true
        },
        attrs
      )
    )
    |> Repo.insert!()
  end
end
