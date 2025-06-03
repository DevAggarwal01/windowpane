defmodule AuroraWeb.Admin.AdminSettingsLive do
  use AuroraWeb, :live_view

  alias Aurora.Administration

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Admin Settings",
       email_form_changeset: Administration.change_admin_email(socket.assigns.current_admin),
       password_form_changeset: Administration.change_admin_password(socket.assigns.current_admin)
     )}
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Administration.update_admin_email(socket.assigns.current_admin, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/settings")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl space-y-12 py-12">
      <.header class="text-center">
        Account Settings
        <:subtitle>Manage your account email and password settings</:subtitle>
      </.header>

      <div class="space-y-12">
        <div class="bg-white shadow sm:rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-base font-semibold leading-6 text-gray-900">Change Email</h3>
            <div class="mt-2 max-w-xl text-sm text-gray-500">
              <p>Change your account email address.</p>
            </div>
            <.simple_form
              for={@email_form_changeset}
              id="email_form"
              phx-submit="update_email"
              class="mt-5 sm:flex sm:items-center"
            >
              <.input field={@email_form_changeset[:email]} type="email" label="New Email" required />
              <.input
                field={@email_form_changeset[:current_password]}
                name="current_password"
                type="password"
                label="Current Password"
                required
              />
              <:actions>
                <.button phx-disable-with="Changing...">Change Email</.button>
              </:actions>
            </.simple_form>
          </div>
        </div>

        <div class="bg-white shadow sm:rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-base font-semibold leading-6 text-gray-900">Change Password</h3>
            <div class="mt-2 max-w-xl text-sm text-gray-500">
              <p>Ensure your account is using a strong password.</p>
            </div>
            <.simple_form
              for={@password_form_changeset}
              id="password_form"
              action={~p"/settings"}
              method="put"
              phx-submit="update_password"
              class="mt-5 space-y-4"
            >
              <.input
                field={@password_form_changeset[:password]}
                type="password"
                label="New Password"
                required
              />
              <.input
                field={@password_form_changeset[:password_confirmation]}
                type="password"
                label="Confirm New Password"
                required
              />
              <.input
                field={@password_form_changeset[:current_password]}
                name="current_password"
                type="password"
                label="Current Password"
                required
              />
              <:actions>
                <.button phx-disable-with="Changing...">Change Password</.button>
              </:actions>
            </.simple_form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "admin" => admin_params} = params
    admin = socket.assigns.current_admin

    case Administration.apply_admin_email(admin, password, admin_params) do
      {:ok, applied_admin} ->
        Administration.deliver_admin_update_email_instructions(
          applied_admin,
          admin.email,
          &url(~p"/settings/confirm_email/#{&1}")
        )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "A link to confirm your email change has been sent to the new address."
         )
         |> assign(email_form_changeset: Administration.change_admin_email(admin))}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form_changeset, changeset)}
    end
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "admin" => admin_params} = params
    admin = socket.assigns.current_admin

    case Administration.update_admin_password(admin, password, admin_params) do
      {:ok, admin} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password updated successfully.")
         |> assign(
           password_form_changeset: Administration.change_admin_password(admin)
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, :password_form_changeset, changeset)}
    end
  end
end
