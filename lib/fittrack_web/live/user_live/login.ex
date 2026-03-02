defmodule FittrackWeb.UserLive.Login do
  use FittrackWeb, :live_view

  alias Fittrack.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-[calc(100vh-4rem)] bg-gray-100 flex items-center justify-center px-4 py-10">
        <div class="w-full max-w-md bg-white rounded-2xl shadow-sm border border-gray-200 p-8">
          <!-- Header -->
          <div class="mb-6">
            <h1 class="text-2xl font-semibold text-gray-900">Sign in</h1>

            <p class="mt-1 text-sm text-gray-600">
              <%= if @current_scope do %>
                You need to reauthenticate to perform sensitive actions on your account.
              <% else %>
                New user?
                <.link navigate={~p"/users/register"} class="text-blue-600 hover:underline">
                  Create an account
                </.link>
              <% end %>
            </p>
          </div>
          
    <!-- Local mail adapter note (kept, but styled to match Design B) -->
          <div
            :if={local_mail_adapter?()}
            class="mb-6 rounded-xl border border-blue-200 bg-blue-50 p-4 text-sm text-blue-900"
          >
            <div class="flex gap-3">
              <.icon name="hero-information-circle" class="size-5 shrink-0 text-blue-700" />
              <div>
                <p class="font-medium">You are running the local mail adapter.</p>
                <p class="mt-1">
                  To see sent emails, visit <.link href="/dev/mailbox" class="text-blue-700 underline">
                    the mailbox page
                  </.link>.
                </p>
              </div>
            </div>
          </div>
          
    <!-- Password login (primary) -->
          <.form
            :let={f}
            for={@form}
            id="login_form_password"
            action={~p"/users/log-in"}
            method="post"
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
          >
            <div class="space-y-4">
              <!-- Email -->
              <div>
                <label for="user_email" class="block text-sm font-medium text-gray-700">
                  Email Address
                </label>

                <div class="mt-1 relative">
                  <span class="pointer-events-none absolute inset-y-0 left-3 flex items-center text-gray-400">
                    <!-- envelope icon -->
                    <svg
                      viewBox="0 0 24 24"
                      class="h-5 w-5"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path d="M4 4h16v16H4z" />
                      <path d="M22 6l-10 7L2 6" />
                    </svg>
                  </span>

                  <input
                    id="user_email"
                    name={f[:email].name}
                    value={f[:email].value}
                    type="email"
                    autocomplete="email"
                    required
                    readonly={!!@current_scope}
                    phx-mounted={JS.focus()}
                    placeholder="Email Address"
                    class="w-full rounded-xl border border-gray-200 bg-gray-50 pl-10 pr-3 py-3 text-gray-900 placeholder:text-gray-400 focus:bg-white focus:border-gray-300 focus:ring-2 focus:ring-gray-200 outline-none"
                  />
                </div>
              </div>
              
    <!-- Password -->
              <div>
                <label for="user_password" class="block text-sm font-medium text-gray-700">
                  Password
                </label>

                <div class="mt-1 relative" id="password_field" phx-hook="PasswordToggle">
                  <span class="pointer-events-none absolute inset-y-0 left-3 flex items-center text-gray-400">
                    <!-- lock icon -->
                    <svg
                      viewBox="0 0 24 24"
                      class="h-5 w-5"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path d="M7 11V8a5 5 0 0110 0v3" />
                      <path d="M6 11h12v10H6z" />
                    </svg>
                  </span>

                  <input
                    id="user_password"
                    name={@form[:password].name}
                    value={@form[:password].value}
                    type="password"
                    autocomplete="current-password"
                    required
                    placeholder="Password"
                    data-password-input
                    class="w-full rounded-xl border border-gray-200 bg-gray-50 pl-10 pr-12 py-3 text-gray-900 placeholder:text-gray-400 focus:bg-white focus:border-gray-300 focus:ring-2 focus:ring-gray-200 outline-none"
                  />

                  <button
                    type="button"
                    class="absolute inset-y-0 right-3 flex items-center text-gray-500 hover:text-gray-700"
                    aria-label="Show password"
                    data-password-toggle
                  >
                    <!-- eye icon -->
                    <svg
                      viewBox="0 0 24 24"
                      class="h-5 w-5"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7z" />
                      <path d="M12 15a3 3 0 100-6 3 3 0 000 6z" />
                    </svg>
                  </button>
                </div>

                <p class="mt-2 text-sm text-gray-500">
                  Need help signing in? Contact support.
                </p>
              </div>
              
    <!-- Remember me -->
              <label class="flex items-center gap-2 text-sm text-gray-700">
                <input
                  type="checkbox"
                  name={@form[:remember_me].name}
                  value="true"
                  class="rounded border-gray-300"
                /> Remember me
              </label>
              
    <!-- CTA -->
              <button
                type="submit"
                class="w-full rounded-full bg-black text-white py-3 font-medium hover:bg-gray-900 focus:outline-none focus:ring-2 focus:ring-gray-300"
              >
                Login
              </button>
            </div>
          </.form>
          
    <!-- Divider -->
          <div class="my-6 flex items-center gap-3">
            <div class="h-px flex-1 bg-gray-200"></div>
            <div class="text-sm text-gray-500">or</div>
            <div class="h-px flex-1 bg-gray-200"></div>
          </div>
          
    <!-- Magic link (secondary, but still supported) -->
          <.form
            :let={f}
            for={@form}
            id="login_form_magic"
            action={~p"/users/log-in"}
            method="post"
            phx-submit="submit_magic"
          >
            <div class="space-y-3">
              <p class="text-sm text-gray-600 text-center">
                Email me a magic login link
              </p>

              <div class="relative">
                <span class="pointer-events-none absolute inset-y-0 left-3 flex items-center text-gray-400">
                  <svg
                    viewBox="0 0 24 24"
                    class="h-5 w-5"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                  >
                    <path d="M4 4h16v16H4z" />
                    <path d="M22 6l-10 7L2 6" />
                  </svg>
                </span>

                <input
                  id="user_email_magic"
                  name={f[:email].name}
                  value={f[:email].value}
                  type="email"
                  autocomplete="email"
                  required
                  readonly={!!@current_scope}
                  placeholder="Email Address"
                  class="w-full rounded-xl border border-gray-200 bg-gray-50 pl-10 pr-3 py-3 text-gray-900 placeholder:text-gray-400 focus:bg-white focus:border-gray-300 focus:ring-2 focus:ring-gray-200 outline-none"
                />
              </div>

              <button
                type="submit"
                class="w-full rounded-full border border-gray-200 bg-white text-gray-900 py-3 font-medium hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-gray-200"
              >
                Send magic link
              </button>
            </div>
          </.form>
          
    <!-- Social (UI-only placeholders for now) -->
          <div class="mt-8 text-center">
            <p class="text-sm text-gray-600">Join With Your Favorite Social Media Account</p>

            <div class="mt-4 flex items-center justify-center gap-3">
              <a
                href="#"
                class="h-11 w-11 rounded-full border border-gray-200 bg-white hover:bg-gray-50 flex items-center justify-center text-blue-600"
                aria-label="Continue with Google"
              >
                <svg viewBox="0 0 24 24" class="h-5 w-5" fill="currentColor">
                  <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
                  <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
                  <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" />
                  <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
                </svg>
              </a>
              <a
                href="#"
                class="h-11 w-11 rounded-full border border-gray-200 bg-white hover:bg-gray-50 flex items-center justify-center text-blue-600"
                aria-label="Continue with Facebook"
              >
                <svg viewBox="0 0 24 24" class="h-5 w-5" fill="currentColor">
                  <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
                </svg>
              </a>
              <a
                href="#"
                class="h-11 w-11 rounded-full border border-gray-200 bg-white hover:bg-gray-50 flex items-center justify-center text-gray-900"
                aria-label="Continue with X"
              >
                <svg viewBox="0 0 24 24" class="h-5 w-5" fill="currentColor">
                  <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24h-6.627l-5.1-6.694-5.846 6.694H2.556l7.73-8.835L1.25 2.25h6.803l4.713 6.231 5.722-6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
                </svg>
              </a>
              <a
                href="#"
                class="h-11 w-11 rounded-full border border-gray-200 bg-white hover:bg-gray-50 flex items-center justify-center text-gray-900"
                aria-label="Continue with Apple"
              >
                <svg viewBox="0 0 24 24" class="h-5 w-5" fill="currentColor">
                  <path d="M17.05 20.28c-.98.95-2.05.88-3.08.4-1.09-.5-2.08-.48-3.24 0-1.44.62-2.2.44-3.06-.4C2.79 15.25 3.51 7.59 9.05 7.31c1.35.05 2.29.74 3.08.88.78-.12 2.33-.8 3.48-.73.86.05 1.67.36 2.07.89-1.96 2.42-1.59 5.93.13 7.36-.72.97-1.34 1.26-2.76 2.27l-.05.05zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z" />
                </svg>
              </a>
            </div>
          </div>
          
    <!-- Footer microcopy -->
          <p class="mt-6 text-center text-xs text-gray-500">
            By signing in with an account, you agree to our
            <a href="#" class="text-blue-600 hover:underline">Terms of Service</a>
            and <a href="#" class="text-blue-600 hover:underline">Privacy Policy</a>.
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:fittrack, Fittrack.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
