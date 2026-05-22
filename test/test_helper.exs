ExUnit.start()

unless System.get_env("SKIP_DB_SETUP") do
  Ecto.Adapters.SQL.Sandbox.mode(Fittrack.Repo, :manual)
end
