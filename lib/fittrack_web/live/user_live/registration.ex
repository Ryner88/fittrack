defmodule FittrackWeb.UserLive.Registration do
  use FittrackWeb, :live_view

  alias Fittrack.Accounts
  alias Fittrack.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-[calc(100vh-4rem)] bg-gray-100 flex items-center justify-center px-4 py-10">
        <div class="w-full max-w-md bg-white rounded-2xl shadow-sm border border-gray-200 p-8">
          <div class="mb-6">
            <h1 class="text-2xl font-semibold text-gray-900">Create account</h1>

            <p class="mt-1 text-sm text-gray-600">
              Already have an account?
              <.link navigate={~p"/users/log-in"} class="text-blue-600 hover:underline">
                Sign in
              </.link>
            </p>
          </div>

          <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
            <div class="space-y-4">
              <div>
                <label for={@form[:email].id} class="block text-sm font-medium text-gray-700">
                  Email address
                </label>

                <div class="mt-1 relative">
                  <span class="pointer-events-none absolute inset-y-0 left-3 flex items-center text-gray-400">
                    <.icon name="hero-envelope" class="h-5 w-5" />
                  </span>

                  <.input
                    field={@form[:email]}
                    type="email"
                    autocomplete="username"
                    required
                    phx-mounted={JS.focus()}
                    placeholder="Email Address"
                    class="w-full rounded-xl border border-gray-200 bg-gray-50 pl-10 pr-3 py-3 text-gray-900 placeholder:text-gray-400 focus:bg-white focus:border-gray-300 focus:ring-2 focus:ring-gray-200 outline-none"
                    error_class="border-red-300 focus:border-red-300 focus:ring-red-100"
                  />
                </div>
              </div>

              <div>
                <label for={@form[:password].id} class="block text-sm font-medium text-gray-700">
                  Create password
                </label>

                <div class="mt-1 relative" id="registration_password_field" phx-hook="PasswordToggle">
                  <span class="pointer-events-none absolute inset-y-0 left-3 flex items-center text-gray-400">
                    <.icon name="hero-lock-closed" class="h-5 w-5" />
                  </span>

                  <.input
                    field={@form[:password]}
                    type="password"
                    autocomplete="new-password"
                    required
                    placeholder="Create password"
                    data-password-input
                    class="w-full rounded-xl border border-gray-200 bg-gray-50 pl-10 pr-12 py-3 text-gray-900 placeholder:text-gray-400 focus:bg-white focus:border-gray-300 focus:ring-2 focus:ring-gray-200 outline-none"
                    error_class="border-red-300 focus:border-red-300 focus:ring-red-100"
                  />

                  <button
                    type="button"
                    class="absolute inset-y-0 right-3 flex items-center text-gray-500 hover:text-gray-700"
                    aria-label="Show password"
                    data-password-toggle
                  >
                    <.icon name="hero-eye" class="h-5 w-5" />
                  </button>
                </div>
              </div>

              <div>
                <label for={@form[:password_confirmation].id} class="block text-sm font-medium text-gray-700">
                  Retype password
                </label>

                <div
                  class="mt-1 relative"
                  id="registration_password_confirmation_field"
                  phx-hook="PasswordToggle"
                >
                  <span class="pointer-events-none absolute inset-y-0 left-3 flex items-center text-gray-400">
                    <.icon name="hero-lock-closed" class="h-5 w-5" />
                  </span>

                  <.input
                    field={@form[:password_confirmation]}
                    type="password"
                    autocomplete="new-password"
                    required
                    placeholder="Retype password"
                    data-password-input
                    class="w-full rounded-xl border border-gray-200 bg-gray-50 pl-10 pr-12 py-3 text-gray-900 placeholder:text-gray-400 focus:bg-white focus:border-gray-300 focus:ring-2 focus:ring-gray-200 outline-none"
                    error_class="border-red-300 focus:border-red-300 focus:ring-red-100"
                  />

                  <button
                    type="button"
                    class="absolute inset-y-0 right-3 flex items-center text-gray-500 hover:text-gray-700"
                    aria-label="Show password"
                    data-password-toggle
                  >
                    <.icon name="hero-eye" class="h-5 w-5" />
                  </button>
                </div>
              </div>

              <button
                type="submit"
                phx-disable-with="Creating account..."
                class="w-full rounded-full bg-black text-white py-3 font-medium hover:bg-gray-900 transition-colors focus:outline-none focus:ring-2 focus:ring-gray-300"
              >
                Create account
              </button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: FittrackWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{}, %{}, validate_unique: false, hash_password: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{user.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      Accounts.change_user_registration(%User{}, user_params,
        validate_unique: false,
        hash_password: false
      )

    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
