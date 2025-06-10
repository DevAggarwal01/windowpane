defmodule WindowpaneWeb.CreatorConfirmationLive do
  use WindowpaneWeb, :live_view

  alias Windowpane.Creators

  def render(%{live_action: :new} = assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Resend confirmation instructions
      </.header>

      <.simple_form for={@form} id="resend_confirmation_form" phx-submit="send_instructions">
        <.input field={@form[:email]} type="email" placeholder="Email" required />
        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Resend confirmation instructions
          </.button>
        </:actions>
      </.simple_form>

      <p class="text-center mt-4">
        <.link href={~p"/creators/log_in"}>Log in</.link>
      </p>
    </div>
    """
  end

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Confirm Account</.header>

      <.simple_form for={@form} id="confirmation_form" phx-submit="confirm_account">
        <.input field={@form[:token]} type="text" class="hidden" />
        <:actions>
          <.button phx-disable-with="Confirming..." class="w-full">Confirm my account</.button>
        </:actions>
      </.simple_form>

      <p class="text-center mt-4">
        <.link href={~p"/creators/log_in"}>Log in</.link>
      </p>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    form = to_form(%{"token" => token}, as: "creator")
    {:ok, assign(socket, form: form), temporary_assigns: [form: nil]}
  end

  def mount(_params, _session, socket) do
    form = to_form(%{}, as: "creator")
    {:ok, assign(socket, form: form), temporary_assigns: [form: nil]}
  end

  def handle_event("confirm_account", %{"creator" => %{"token" => token}}, socket) do
    case Creators.confirm_creator(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Creator confirmed successfully.")
         |> redirect(to: ~p"/creators/log_in")}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Confirmation link is invalid or it has expired.")
         |> redirect(to: ~p"/")}
    end
  end

  def handle_event("send_instructions", %{"creator" => %{"email" => email}}, socket) do
    if creator = Creators.get_creator_by_email(email) do
      Creators.deliver_creator_confirmation_instructions(
        creator,
        &url(~p"/confirm/#{&1}")
      )
    end

    {:noreply,
     socket
     |> put_flash(
       :info,
       "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."
     )
     |> redirect(to: ~p"/")}
  end
end
