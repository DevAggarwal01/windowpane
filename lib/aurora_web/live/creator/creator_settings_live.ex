defmodule AuroraWeb.CreatorSettingsLive do
  use AuroraWeb, :live_view

  alias Aurora.Creators

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Account Settings
      <:subtitle>Manage your account email address and password settings</:subtitle>
    </.header>

    <div class="space-y-12 divide-y max-w-2xl mx-auto">
      <div>
        <.simple_form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <.input field={@email_form[:email]} type="email" label="Email" required />
          <.input
            field={@email_form[:current_password]}
            name="current_password"
            id="current_password_for_email"
            type="password"
            label="Current password"
            value={@email_form_current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Change Email</.button>
          </:actions>
        </.simple_form>
      </div>
      <div>
        <.simple_form
          for={@password_form}
          id="password_form"
          action={~p"/creators/log_in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            field={@password_form[:email]}
            type="text"
            style="display: none;"
            id="hidden_creator_email"
            value={@current_email}
          />
          <.input field={@password_form[:password]} type="password" label="New password" required />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label="Confirm new password"
          />
          <.input
            field={@password_form[:current_password]}
            name="current_password"
            type="password"
            label="Current password"
            id="current_password_for_password"
            value={@password_form_current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Change Password</.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Creators.update_creator_email(socket.assigns.current_creator, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/settings")}
  end

  def mount(_params, _session, socket) do
    creator = socket.assigns.current_creator
    email_changeset = Creators.change_creator_email(creator)
    password_changeset = Creators.change_creator_password(creator)

    socket =
      socket
      |> assign(:current_email, creator.email)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_password_for_email, nil)
      |> assign(:password_form_current_password, nil)
      |> assign(:current_password_for_password, nil)
      |> assign(:trigger_submit, false)
      |> assign_form(:password_form, password_changeset)
      |> assign_form(:email_form, email_changeset)

    {:ok, socket}
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "creator" => creator_params} = params
    email_changeset = Creators.change_creator_email(socket.assigns.current_creator, creator_params)

    socket =
      assign(socket,
        email_form: to_form(email_changeset),
        email_form_current_password: password
      )

    {:noreply, socket}
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "creator" => creator_params} = params
    password_changeset = Creators.change_creator_password(socket.assigns.current_creator, creator_params)

    {:noreply,
     socket
     |> assign(:password_form, to_form(password_changeset))
     |> assign(:password_form_current_password, password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "creator" => creator_params} = params
    creator = socket.assigns.current_creator

    case Creators.apply_creator_email(creator, password, creator_params) do
      {:ok, applied_creator} ->
        Creators.deliver_creator_update_email_instructions(
          applied_creator,
          creator.email,
          &url(~p"/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "creator" => creator_params} = params
    creator = socket.assigns.current_creator

    case Creators.update_creator_password(creator, password, creator_params) do
      {:ok, creator} ->
        password_changeset = Creators.change_creator_password(creator)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(:password_form, password_changeset)}

      {:error, changeset} ->
        {:noreply, assign(socket, :password_form, to_form(changeset))}
    end
  end

  defp assign_form(socket, name, %Ecto.Changeset{} = changeset) do
    assign(socket, name, to_form(changeset))
  end
end
