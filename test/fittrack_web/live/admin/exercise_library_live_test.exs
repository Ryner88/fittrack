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

  test "admin can inspect and filter media health report", %{conn: conn} do
    cached_template = template_fixture(%{name: "Cached Media Press", primary_muscle: "Chest"})

    unsupported_template =
      template_fixture(%{name: "Unsupported Media Pull", primary_muscle: "Back"})

    failed_template = template_fixture(%{name: "Failed Media Squat", primary_muscle: "Quads"})

    cached =
      media_fixture(cached_template, %{
        cache_status: "cached",
        local_path: "cached/press.jpg",
        storage_key: "cached/press.jpg",
        file_size: 128,
        mime_type: "image/jpeg",
        checked_at: ~U[2026-06-01 12:00:00Z],
        cached_at: ~U[2026-06-01 12:00:00Z]
      })

    unsupported =
      media_fixture(unsupported_template, %{
        cache_status: "unsupported",
        source_url: "https://wger.de/media/unsupported.webp",
        failure_reason: "unsupported content type",
        checked_at: ~U[2026-06-02 12:00:00Z]
      })

    failed =
      media_fixture(failed_template, %{
        cache_status: "failed",
        source_url: "https://wger.de/media/failed.jpg",
        failure_reason: "timeout",
        checked_at: ~U[2026-06-03 12:00:00Z]
      })

    {:ok, view, html} = live(conn, ~p"/admin/exercises/media")

    assert has_element?(view, "#admin-exercise-media-report")
    assert has_element?(view, "#admin-media-filter-form")
    assert has_element?(view, "#admin-exercise-media-#{cached.id}")
    assert has_element?(view, "#admin-exercise-media-#{unsupported.id}")
    assert has_element?(view, "#admin-exercise-media-#{failed.id}")
    assert html =~ "cached/press.jpg"
    assert html =~ "unsupported content type"
    assert html =~ "https://wger.de/media/failed.jpg"

    view
    |> form("#admin-media-filter-form",
      filters: %{status: "unsupported", search: "unsupported.webp"}
    )
    |> render_change()

    assert has_element?(view, "#admin-exercise-media-#{unsupported.id}")
    refute has_element?(view, "#admin-exercise-media-#{cached.id}")
    refute has_element?(view, "#admin-exercise-media-#{failed.id}")
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

  test "admin can validate the temporary template CRUD workflow end to end", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/exercises/new")

    attrs = %{
      name: "TEMP TAXONOMY BACKFILL VALIDATION - DELETE ME",
      slug: "temp-taxonomy-backfill-validation-delete-me",
      source_id: "",
      primary_muscle: "chest",
      equipment: "bodyweight",
      difficulty: "beginner",
      movement_pattern: "push",
      exercise_category: "bodyweight",
      movement_direction: "horizontal_push",
      quality_score: "80",
      fatigue_score: "2",
      skill_requirement: "low",
      notes: "Temporary admin CRUD validation template. Safe to archive after testing.",
      image_url: "",
      aliases_text: "admin test pushup\ntest push-up\ntemporary push-up",
      weighted_tags: "horizontal_push, chest, bodyweight, admin_test",
      training_style_tags: "strength, hypertrophy, beginner",
      secondary_muscles: "triceps, shoulders",
      muscle_names: "chest\ntriceps\nshoulders",
      equipment_names: "bodyweight",
      source_name: "admin_test",
      source_external_id: "temp-taxonomy-backfill-validation",
      source_url: "",
      source_payload: ~s({"source":"admin_test","purpose":"admin CRUD validation"}),
      is_verified: "true",
      is_ai_generated: "false",
      is_deprecated: "false"
    }

    view
    |> form("#admin-template-form", template: attrs)
    |> render_submit()

    template = Repo.get_by!(ExerciseTemplate, slug: "temp-taxonomy-backfill-validation-delete-me")
    assert_redirect(view, ~p"/admin/exercises/#{template.id}")

    assert_admin_filter_matches(conn, template, %{
      search: "TEMP TAXONOMY BACKFILL VALIDATION - DELETE ME"
    })

    {:ok, edit_view, _html} = live(conn, ~p"/admin/exercises/#{template.id}/edit")

    edited_attrs =
      Map.put(attrs, :aliases_text, attrs.aliases_text <> "\ncrud validation push-up")

    edit_view
    |> form("#admin-template-form", template: edited_attrs)
    |> render_submit()

    assert_redirect(edit_view, ~p"/admin/exercises/#{template.id}")

    updated = Training.get_admin_exercise_template!(template.id)

    assert Enum.map(updated.aliases, & &1.name) == [
             "admin test pushup",
             "test push-up",
             "temporary push-up",
             "crud validation push-up"
           ]

    assert_admin_filter_matches(conn, updated, %{search: "crud validation push-up"})
    assert_admin_filter_matches(conn, updated, %{media_status: "missing_media"})
    assert_admin_filter_matches(conn, updated, %{category: "bodyweight"})
    assert_admin_filter_matches(conn, updated, %{difficulty: "beginner"})
    assert_admin_filter_matches(conn, updated, %{muscle_group: "chest"})
    assert_admin_filter_matches(conn, updated, %{equipment: "bodyweight"})
    assert_admin_filter_matches(conn, updated, %{source: "admin_test"})

    {:ok, _show_view, html} = live(conn, ~p"/admin/exercises/#{template.id}")

    assert html =~ "TEMP TAXONOMY BACKFILL VALIDATION - DELETE ME"
    assert html =~ "admin test pushup"
    assert html =~ "crud validation push-up"
    assert html =~ "horizontal_push"
    assert html =~ "admin_test"
    assert html =~ "temp-taxonomy-backfill-validation"
    assert html =~ "Payload keys: purpose, source"
    assert html =~ "chest"
    assert html =~ "triceps"
    assert html =~ "shoulders"
    assert html =~ "bodyweight"
    assert html =~ "Missing media"

    {:ok, archive_view, _html} = live(conn, ~p"/admin/exercises/#{template.id}")

    archive_view
    |> form("#admin-template-archive-form", archive: %{confirm: "DELETE"})
    |> render_submit()

    refute Repo.reload!(template).is_deprecated

    archive_view
    |> form("#admin-template-archive-form", archive: %{confirm: "ARCHIVE"})
    |> render_submit()

    assert_redirect(archive_view, ~p"/admin/exercises/#{template.id}")
    archived = Repo.reload!(template)
    assert archived.is_deprecated

    {:ok, list_view, _html} = live(conn, ~p"/admin/exercises")

    list_view
    |> form("#admin-template-filter-form",
      filters: %{search: "TEMP TAXONOMY BACKFILL VALIDATION - DELETE ME"}
    )
    |> render_change()

    assert has_element?(list_view, "#admin-exercise-template-#{template.id}", "archived")
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
    incline = template_fixture(%{name: "Admin Incline Press", equipment: "Barbell"})
    push_up = template_fixture(%{name: "Admin Push-Up", equipment: "Bodyweight"})

    assert {:ok, _variation} =
             Training.create_exercise_variation(template, incline, %{
               relationship: "angle",
               similarity_score: 87,
               equipment_requirements: ["Incline bench"],
               difficulty_delta: 1
             })

    assert {:ok, _substitution} =
             Training.create_exercise_substitution(template, push_up, %{
               reason: "home_training",
               similarity_score: 91,
               reason_quality: 82,
               equipment_requirements: ["Bodyweight"],
               difficulty_delta: -1
             })

    {:ok, _view, html} = live(conn, ~p"/admin/exercises/#{template.id}")

    assert html =~ "Attribution Row"
    assert html =~ "import row"
    assert html =~ "wger"
    assert html =~ "Payload keys:"
    assert html =~ "failed"
    assert html =~ "404 from source"
    assert html =~ "wger project"
    assert html =~ "Relationship Metadata"
    assert html =~ "Admin Incline Press"
    assert html =~ "Admin Push-Up"
    assert html =~ "Match 87/100"
    assert html =~ "Reason 82/100"
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
    assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/admin/exercises/media")

    guest_conn = recycle(admin_conn)
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(guest_conn, ~p"/admin/exercises")

    assert {:error, {:redirect, %{to: "/users/log-in"}}} =
             live(guest_conn, ~p"/admin/exercises/media")
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

  defp assert_admin_filter_matches(conn, template, filters) do
    {:ok, view, _html} = live(conn, ~p"/admin/exercises")

    view
    |> form("#admin-template-filter-form", filters: filters)
    |> render_change()

    assert has_element?(view, "#admin-exercise-template-#{template.id}")
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
