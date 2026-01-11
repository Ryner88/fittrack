defmodule FittrackWeb.PageController do
  use FittrackWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
