defmodule WindowpaneWeb.UserLoginModalComponent do
  use WindowpaneWeb, :live_component
  alias Windowpane.Accounts
  alias Windowpane.Accounts.User

  @impl true
  def mount(socket) do
    {:ok, assign(socket, error_message: nil, signup_mode: false, changeset: nil, check_errors: false, trigger_login: false, login_email: nil, login_password: nil)}
  end

  defp current_path(assigns) do
    assigns[:current_path] || "/"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="relative w-full max-w-md border border-white rounded-lg shadow-2xl text-white p-0" style="backdrop-filter: blur(8px); background: rgba(10,10,10,0.8); padding: 2.5rem 2.5rem 2rem 2.5rem;">
        <button
          phx-click="close"
          phx-target={@myself}
          class="absolute top-3 right-4 text-white text-xl opacity-80 hover:opacity-100 focus:outline-none"
          aria-label="Close"
        >
          [x]
        </button>
        <div class="text-left">
          <%= if @signup_mode do %>
            <h2 class="text-3xl font-light mb-1 mt-2">Sign Up</h2>
            <p class="mb-6 text-base">Create your account to get started!</p>
            <%= if @check_errors do %>
              <div class="text-red-400 mb-4 text-sm text-center">Oops, something went wrong! Please check the errors below.</div>
            <% end %>
            <%= if @changeset do %>
              <% form = to_form(@changeset, as: "user") %>
              <.form
                for={form}
                id="registration_modal_form"
                phx-submit="register"
                phx-change="validate"
                phx-target={@myself}
                autocomplete="off"
                class="space-y-3"
              >
                <input type="hidden" name="_csrf_token" value={@csrf_token} />
                <input
                  name="user[email]"
                  type="email"
                  value={form[:email].value}
                  placeholder="Email"
                  required
                  class="w-full bg-black bg-opacity-60 border border-white/80 rounded-none px-4 py-2 text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white text-base mb-2"
                  style="font-family: inherit; letter-spacing: 0.01em;"
                />
                <input
                  name="user[password]"
                  type="password"
                  value={form[:password].value}
                  placeholder="Password"
                  required
                  class="w-full bg-black bg-opacity-60 border border-white/80 rounded-none px-4 py-2 text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white text-base mb-2"
                  style="font-family: inherit; letter-spacing: 0.01em;"
                />
                <p class="mt-1 text-xs text-gray-400">
                  Must be at least 12 characters with 1 upper case, 1 lower case, and 1 number or special character
                </p>
                <button type="submit" class="w-full text-lg border border-white rounded-none py-2 mt-2 hover:bg-white/10 transition">
                  [sign up]
                </button>
              </.form>
              <%= if @trigger_login do %>
                <form id="auto-login-form" method="post" action={"/users/log_in?_action=registered&redirect_to=" <> current_path(assigns)} phx-trigger-action={@trigger_login} style="display:none">
                  <input type="hidden" name="_csrf_token" value={@csrf_token} />
                  <input type="hidden" name="user[email]" value={@login_email} />
                  <input type="hidden" name="user[password]" value={@login_password} />
                </form>
              <% end %>
            <% end %>
            <div class="flex items-center justify-start text-sm mt-4 mb-2">
              <span>Already have an account? <a href="#" phx-click="toggle_mode" phx-target={@myself} class="underline hover:text-gray-300">Log in</a></span>
            </div>
          <% else %>
            <h2 class="text-3xl font-light mb-1 mt-2">Login</h2>
            <p class="mb-6 text-base">Welcome back. We all missed you :3</p>
            <%= if @error_message do %>
              <div class="text-red-400 mb-4 text-sm text-center"><%= @error_message %></div>
            <% end %>
            <form method="post" action="/users/log_in" autocomplete="off" class="space-y-3">
              <input type="hidden" name="_csrf_token" value={@csrf_token} />
              <input
                name="user[email]"
                type="text"
                placeholder="username or email"
                class="w-full bg-black bg-opacity-60 border border-white/80 rounded-none px-4 py-2 text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white text-base mb-2"
                style="font-family: inherit; letter-spacing: 0.01em;"
                required
              />
              <input
                name="user[password]"
                type="password"
                placeholder="password"
                class="w-full bg-black bg-opacity-60 border border-white/80 rounded-none px-4 py-2 text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white text-base mb-2"
                style="font-family: inherit; letter-spacing: 0.01em;"
                required
              />
              <div class="flex items-center justify-start text-sm mt-2 mb-4">
                <span>Don't have an account? <a href="#" phx-click="toggle_mode" phx-target={@myself} class="underline hover:text-gray-300">Sign up</a></span>
              </div>
              <button type="submit" class="w-full text-lg border border-white rounded-none py-2 mt-2 hover:bg-white/10 transition">
                [login]
              </button>
            </form>
          <% end %>
          <p class="mt-8 text-center text-xs text-white/70">
            By continuing, you agree to the <a href="/rules" class="underline">rules</a>.
          </p>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("close", _params, socket) do
    send(self(), :close_login_modal)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_mode", _params, socket) do
    changeset = if !socket.assigns.signup_mode, do: Accounts.change_user_registration(%User{}), else: nil
    {:noreply, assign(socket, signup_mode: !socket.assigns.signup_mode, error_message: nil, changeset: changeset, check_errors: false, trigger_login: false, login_email: nil, login_password: nil)}
  end

  @impl true
  def handle_event("register", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} = Accounts.deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
        {:noreply, assign(socket,
          trigger_login: true,
          login_email: user_params["email"],
          login_password: user_params["password"],
          changeset: socket.assigns.changeset,
          check_errors: false
        )}
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset, check_errors: true, trigger_login: false, login_email: nil, login_password: nil)}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign(socket, changeset: Map.put(changeset, :action, :validate))}
  end
end
