defmodule FittrackWeb.RedirectController do
  use FittrackWeb, :controller

  @impl true
  def init(opts), do: opts

  def workouts_redirect(conn, _params) do
    redirect(conn, to: ~p"/workouts")
  end

  def new_workout_redirect(conn, _params) do
    redirect(conn, to: ~p"/workouts/new")
  end

  def workout_redirect(conn, %{"id" => id}) do
    redirect(conn, to: ~p"/workouts/#{id}")
  end
end
