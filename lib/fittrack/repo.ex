defmodule Fittrack.Repo do
  use Ecto.Repo,
    otp_app: :fittrack,
    adapter: Ecto.Adapters.Postgres
end
