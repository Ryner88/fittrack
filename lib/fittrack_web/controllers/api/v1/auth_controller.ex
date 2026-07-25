defmodule FittrackWeb.Api.V1.AuthController do
  use FittrackWeb, :controller

  alias Fittrack.Accounts
  alias FittrackWeb.Api.V1.JSONHelpers

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{errors: %{detail: "Invalid email or password"}})

      user ->
        token = Accounts.generate_user_mobile_api_token(user)

        json(conn, %{
          data: %{
            token: token,
            token_type: "Bearer",
            user: JSONHelpers.user_json(user)
          }
        })
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{detail: "Email and password are required"}})
  end

  def me(conn, _params) do
    json(conn, %{data: JSONHelpers.user_json(conn.assigns.current_scope.user)})
  end

  def logout(conn, _params) do
    conn
    |> bearer_token()
    |> Accounts.revoke_mobile_api_token()

    send_resp(conn, :no_content, "")
  end

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> String.trim(token)
      _ -> nil
    end
  end
end
