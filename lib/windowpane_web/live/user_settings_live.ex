defmodule WindowpaneWeb.UserSettingsLive do
  use WindowpaneWeb, :live_view

  alias Windowpane.Accounts

  def render(assigns) do
    ~H"""
    <style>
      /* Force all form elements and their containers to have black background */
      form, form *, .simple-form, .simple-form *,
      [data-phx-component], [data-phx-component] *,
      .form-group, .form-group *, .field, .field *,
      input[type="email"] + *, input[type="password"] + *,
      input[type="email"]:after, input[type="password"]:after {
        background: black !important;
        background-color: black !important;
      }
    </style>
    <div class="min-h-screen bg-black" style="background: black !important; background-color: black !important;">
      <div class="container mx-auto px-4 py-8" style="background: black !important; background-color: black !important;">
        <div class="text-center mb-8" style="background: black !important; background-color: black !important;">
          <h1 class="text-3xl font-bold text-white mb-4">Account Settings</h1>
          <p class="text-white">Manage your account email address and password settings</p>
        </div>

        <div class="space-y-12 divide-y divide-gray-800 max-w-2xl mx-auto" style="background: black !important; background-color: black !important;">
          <!-- Email Form -->
          <div class="pt-8" style="background: black !important; background-color: black !important;">
            <form phx-submit="update_email" phx-change="validate_email" style="background: black !important; background-color: black !important;">
              <div class="space-y-4" style="background: black !important; background-color: black !important;">
                <div style="background: black !important; background-color: black !important;">
                  <label style="display: block; color: white !important; font-weight: bold; margin-bottom: 0.5rem; background: black !important; background-color: black !important;">Email</label>
                  <input
                    type="email"
                    name="user[email]"
                    value={@email_form[:email].value}
                    required
                    class="w-full bg-gray-900 border border-white/80 rounded-none px-4 py-2 text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white text-base"
                    style="font-family: inherit; letter-spacing: 0.01em; background: rgb(17 24 39) !important;"
                  />
                </div>
                <div style="background: black !important; background-color: black !important;">
                  <label style="display: block; color: white !important; font-weight: bold; margin-bottom: 0.5rem; background: black !important; background-color: black !important;">Current password</label>
                  <input
                    name="current_password"
                    id="current_password_for_email"
                    type="password"
                    value={@email_form_current_password}
                    required
                    class="w-full bg-gray-900 border border-white/80 rounded-none px-4 py-2 text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white text-base"
                    style="font-family: inherit; letter-spacing: 0.01em; background: rgb(17 24 39) !important;"
                  />
                </div>
              </div>
              <div class="mt-6" style="background: black !important; background-color: black !important;">
                <button type="submit" class="w-full text-lg border border-white rounded-none py-2 hover:bg-white/10 transition text-white font-bold">
                  Change Email
                </button>
              </div>
            </form>
          </div>

          <!-- Password Form -->
          <div class="pt-8" style="background: black !important; background-color: black !important;">
            <form
              action={~p"/users/log_in?_action=password_updated"}
              method="post"
              phx-change="validate_password"
              phx-submit="update_password"
              phx-trigger-action={@trigger_submit}
              style="background: black !important; background-color: black !important;"
            >
              <input
                name={@password_form[:email].name}
                type="hidden"
                id="hidden_user_email"
                value={@current_email}
              />
              <div class="space-y-4" style="background: black !important; background-color: black !important;">
                <div style="background: black !important; background-color: black !important;">
                  <label style="display: block; color: white !important; font-weight: bold; margin-bottom: 0.5rem; background: black !important; background-color: black !important;">New password</label>
                  <input
                    type="password"
                    name="user[password]"
                    value={@password_form[:password].value}
                    required
                    class="w-full bg-gray-900 border border-white/80 rounded-none px-4 py-2 text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white text-base"
                    style="font-family: inherit; letter-spacing: 0.01em; background: rgb(17 24 39) !important;"
                  />
                </div>
                <div style="background: black !important; background-color: black !important;">
                  <label style="display: block; color: white !important; font-weight: bold; margin-bottom: 0.5rem; background: black !important; background-color: black !important;">Confirm new password</label>
                  <input
                    type="password"
                    name="user[password_confirmation]"
                    value={@password_form[:password_confirmation].value}
                    class="w-full bg-gray-900 border border-white/80 rounded-none px-4 py-2 text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white text-base"
                    style="font-family: inherit; letter-spacing: 0.01em; background: rgb(17 24 39) !important;"
                  />
                </div>
                <div style="background: black !important; background-color: black !important;">
                  <label style="display: block; color: white !important; font-weight: bold; margin-bottom: 0.5rem; background: black !important; background-color: black !important;">Current password</label>
                  <input
                    name="current_password"
                    type="password"
                    value={@current_password}
                    id="current_password_for_password"
                    required
                    class="w-full bg-gray-900 border border-white/80 rounded-none px-4 py-2 text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white text-base"
                    style="font-family: inherit; letter-spacing: 0.01em; background: rgb(17 24 39) !important;"
                  />
                </div>
              </div>
              <div class="mt-6" style="background: black !important; background-color: black !important;">
                <button type="submit" class="w-full text-lg border border-white rounded-none py-2 hover:bg-white/10 transition text-white font-bold">
                  Change Password
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end
end
