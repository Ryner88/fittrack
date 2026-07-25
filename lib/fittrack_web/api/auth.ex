defmodule FittrackWeb.Api.Auth do
  @moduledoc """
  Bearer-token authentication for versioned JSON API routes.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Fittrack.Accounts
  alias Fittrack.Accounts.Scope

  def init(opts), do: opts

  def call(conn, :require_mobile_api_user), do: require_mobile_api_user(conn, [])

  def require_mobile_api_user(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {user, _user_token} <- Accounts.get_user_by_mobile_api_token(String.trim(token)) do
      assign(conn, :current_scope, Scope.for_user(user))
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> put_view(json: FittrackWeb.ErrorJSON)
        |> render(:"401")
        |> halt()
    end
  end
end
