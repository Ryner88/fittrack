defmodule Mix.Tasks.FittrackBackfillExerciseTaxonomyTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  defmodule BackfillOptionStub do
    def run(opts) do
      send(Process.get(:taxonomy_backfill_test_pid), {:backfill_opts, opts})

      {:ok,
       %{
         total_templates_inspected: 1,
         templates_updated: 1,
         muscles_created: 1,
         muscle_joins_created: 1,
         equipment_created: 1,
         equipment_joins_created: 1,
         sources_created: 1,
         source_links_updated: 0,
         media_cached: 1,
         media_missing: 0,
         media_stale: 0,
         media_failed: 0,
         skipped_records: 0,
         errors: 0,
         failures: []
       }}
    end
  end

  test "task passes parsed options to the backfill" do
    Process.put(:taxonomy_backfill_test_pid, self())

    capture_io(fn ->
      Mix.Tasks.Fittrack.BackfillExerciseTaxonomy.run(
        ["--dry-run", "--limit", "5", "--template-id", "12"],
        BackfillOptionStub
      )
    end)

    assert_received {:backfill_opts, opts}
    assert Keyword.fetch!(opts, :dry_run)
    assert Keyword.fetch!(opts, :limit) == 5
    assert Keyword.fetch!(opts, :template_id) == 12
  after
    Process.delete(:taxonomy_backfill_test_pid)
  end

  test "task prints requested report counts" do
    output =
      capture_io(fn ->
        Mix.Tasks.Fittrack.BackfillExerciseTaxonomy.print_report(%{
          total_templates_inspected: 2,
          templates_updated: 1,
          muscles_created: 1,
          muscle_joins_created: 2,
          equipment_created: 1,
          equipment_joins_created: 1,
          sources_created: 1,
          source_links_updated: 1,
          media_cached: 3,
          media_missing: 4,
          media_stale: 5,
          media_failed: 6,
          skipped_records: 1,
          errors: 0,
          failures: []
        })
      end)

    assert output =~ "Exercise taxonomy/source backfill complete"
    assert output =~ "Total templates inspected: 2"
    assert output =~ "Templates updated: 1"
    assert output =~ "Muscles created: 1"
    assert output =~ "Muscle joins created: 2"
    assert output =~ "Equipment created: 1"
    assert output =~ "Equipment joins created: 1"
    assert output =~ "Sources created: 1"
    assert output =~ "Source links updated: 1"
    assert output =~ "Media cached: 3"
    assert output =~ "Media missing: 4"
    assert output =~ "Media stale: 5"
    assert output =~ "Media failed: 6"
    assert output =~ "Skipped records: 1"
    assert output =~ "Errors/failures: 0"
  end
end
