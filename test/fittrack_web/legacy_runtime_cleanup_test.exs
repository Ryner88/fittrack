defmodule FittrackWeb.LegacyRuntimeCleanupTest do
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)
  @legacy_name "spar" <> "ky"
  @legacy_runtime @legacy_name <> "fitness"
  @historical_reference_files MapSet.new([
                                "docs/diagrams/ARCHITECTURE.puml",
                                "docs/FIXED_WORK.md",
                                "docs/FUTURE_TASKS.md"
                              ])
  @ignored_dirs MapSet.new([
                  ".agents",
                  ".codex",
                  ".elixir_ls",
                  ".git",
                  "_build",
                  "deps",
                  "node_modules",
                  "storage"
                ])
  @text_extensions MapSet.new([
                     ".conf",
                     ".css",
                     ".ex",
                     ".exs",
                     ".heex",
                     ".html",
                     ".js",
                     ".json",
                     ".lock",
                     ".md",
                     ".puml",
                     ".service",
                     ".sh",
                     ".svg",
                     ".txt"
                   ])

  test "router metadata and route lookups do not expose the legacy runtime" do
    route_values =
      FittrackWeb.Router
      |> Phoenix.Router.routes()
      |> Enum.flat_map(fn route ->
        [route.path, route.helper, route.verb, inspect(route.plug), inspect(route.plug_opts)]
      end)

    assert_no_legacy_strings(route_values, "router route metadata")
    assert_no_helper_exports()
    assert_no_legacy_strings(FittrackWeb.static_paths(), "verified static route paths")

    for path <- legacy_route_probes() do
      assert Phoenix.Router.route_info(FittrackWeb.Router, "GET", path, "localhost") == :error
    end
  end

  test "asset source files, static files, and digest manifest are free of legacy references" do
    assert_no_legacy_paths(files_under(["assets", "priv/static"]), "asset file paths")

    ["assets", "priv/static"]
    |> text_files_in()
    |> assert_no_legacy_file_contents("asset source and digested files")

    manifest_path = root_path("priv/static/cache_manifest.json")
    manifest = manifest_path |> File.read!() |> Jason.decode!()

    manifest
    |> strings_from()
    |> assert_no_legacy_strings("static cache manifest")
  end

  test "app config and deployment scripts are free of legacy runtime references" do
    files =
      text_files_in(["config"]) ++
        Enum.map(
          [
            "mix.exs",
            "deploy.sh",
            "lib/fittrack/application.ex",
            "lib/fittrack_web.ex",
            "lib/fittrack_web/endpoint.ex"
          ],
          &root_path/1
        )

    assert_no_legacy_file_contents(files, "app config and deployment scripts")
  end

  test "only historical documentation files mention the legacy runtime" do
    matches =
      @root
      |> project_text_files()
      |> Enum.filter(&legacy_reference?/1)
      |> Enum.map(&relative_path/1)
      |> Enum.sort()

    unexpected = Enum.reject(matches, &MapSet.member?(@historical_reference_files, &1))

    assert unexpected == [],
           "expected only historical docs to mention the legacy runtime, got:\n" <>
             Enum.join(unexpected, "\n")
  end

  defp assert_no_helper_exports do
    helper_module = Module.concat(FittrackWeb.Router, Helpers)

    if Code.ensure_loaded?(helper_module) do
      helper_exports =
        helper_module.__info__(:functions)
        |> Enum.map(fn {name, arity} -> "#{name}/#{arity}" end)

      assert_no_legacy_strings(helper_exports, "router helper exports")
    else
      assert true
    end
  end

  defp legacy_route_probes do
    [
      "/" <> @legacy_name,
      "/" <> @legacy_name <> "/",
      "/" <> @legacy_runtime,
      "/" <> @legacy_runtime <> "/",
      "/" <> @legacy_runtime <> "/assets/app.js"
    ]
  end

  defp assert_no_legacy_file_contents(paths, context) do
    matches =
      paths
      |> Enum.filter(&legacy_reference?/1)
      |> Enum.map(&relative_path/1)
      |> Enum.sort()

    assert matches == [],
           "#{context} contain legacy runtime references:\n#{Enum.join(matches, "\n")}"
  end

  defp assert_no_legacy_paths(paths, context) do
    paths
    |> Enum.map(&relative_path/1)
    |> assert_no_legacy_strings(context)
  end

  defp assert_no_legacy_strings(values, context) do
    matches =
      values
      |> List.wrap()
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&to_string/1)
      |> Enum.filter(&Regex.match?(legacy_pattern(), &1))
      |> Enum.sort()

    assert matches == [],
           "#{context} contain legacy runtime references:\n#{Enum.join(matches, "\n")}"
  end

  defp files_under(relative_dirs) do
    relative_dirs
    |> Enum.flat_map(fn relative_dir -> root_path(relative_dir) |> files_under_dir() end)
    |> Enum.sort()
  end

  defp text_files_in(relative_dirs) do
    relative_dirs
    |> files_under()
    |> Enum.filter(&text_file?/1)
  end

  defp project_text_files(root) do
    root
    |> files_under_dir()
    |> Enum.filter(&text_file?/1)
  end

  defp files_under_dir(dir) do
    dir
    |> File.ls!()
    |> Enum.flat_map(fn entry ->
      path = Path.join(dir, entry)

      cond do
        File.dir?(path) and ignored_dir?(entry) -> []
        File.dir?(path) -> files_under_dir(path)
        File.regular?(path) -> [path]
        true -> []
      end
    end)
  end

  defp ignored_dir?(entry), do: MapSet.member?(@ignored_dirs, entry)

  defp text_file?(path), do: MapSet.member?(@text_extensions, Path.extname(path))

  defp legacy_reference?(path) do
    Regex.match?(legacy_pattern(), File.read!(path))
  end

  defp strings_from(value) when is_map(value) do
    Enum.flat_map(value, fn {key, nested_value} ->
      [to_string(key) | strings_from(nested_value)]
    end)
  end

  defp strings_from(value) when is_list(value), do: Enum.flat_map(value, &strings_from/1)
  defp strings_from(value) when is_binary(value), do: [value]
  defp strings_from(value) when is_atom(value), do: [to_string(value)]
  defp strings_from(value) when is_number(value), do: [to_string(value)]
  defp strings_from(_value), do: []

  defp root_path(relative_path), do: Path.join(@root, relative_path)
  defp relative_path(path), do: Path.relative_to(path, @root)

  defp legacy_pattern do
    [@legacy_runtime, @legacy_name]
    |> Enum.map(&Regex.escape/1)
    |> Enum.join("|")
    |> Regex.compile!("i")
  end
end
