defmodule Mix.Tasks.Fittrack.ImportExerciseTemplatesTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  setup do
    original_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    Mix.Task.reenable("fittrack.import_exercise_templates")

    on_exit(fn ->
      Mix.shell(original_shell)
      Mix.Task.reenable("fittrack.import_exercise_templates")
    end)

    :ok
  end

  test "prints deterministic failure reporting for the controlled fixture" do
    capture_log(fn ->
      Mix.Tasks.Fittrack.ImportExerciseTemplates.run(["--fixture", "controlled_failures"])
    end)

    assert_received {:mix_shell, :info,
                     ["Importing exercise templates from fixture \"controlled_failures\"..."]}

    assert_received {:mix_shell, :info, [summary]}
    assert summary =~ "Import completed successfully!"
    assert summary =~ "- Fetched: 12"
    assert summary =~ "- Attempted: 12"
    assert summary =~ "- Inserted: 0"
    assert summary =~ "- Updated: 0"
    assert summary =~ "- Failed: 12"

    assert_received {:mix_shell, :info, ["Failed records:"]}

    for _ <- 1..10 do
      assert_received {:mix_shell, :info, [failure_line]}
      assert failure_line =~ ~s(errors=%{name: "can't be blank"})
    end

    assert_received {:mix_shell, :info, ["  ... 2 more failure(s) not shown"]}
  end
end
