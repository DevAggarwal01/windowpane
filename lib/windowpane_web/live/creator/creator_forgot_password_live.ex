defmodule WindowpaneWeb.CreatorForgotPasswordLive do
  use WindowpaneWeb, :live_view

  alias Windowpane.Creators

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Forgot your password?
        <:subtitle>We'll send you reset password instructions</:subtitle>
      </.header>

      <.simple_form for={@form} id="reset_password_form" phx-submit="send_email">
        <.input field={@form[:email]} type="email" placeholder="Email" required />
        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Send reset password instructions
          </.button>
        </:actions>
      </.simple_form>
      <p class="text-center text-sm mt-4">
        <.link href={~p"/creators/log_in"}>Log in</.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "creator")), temporary_assigns: [form: nil]}
  end

  def handle_event("send_email", %{"creator" => %{"email" => email}}, socket) do
    if creator = Creators.get_creator_by_email(email) do
      Creators.deliver_creator_reset_password_instructions(
        creator,
        &url(~p"/creators/reset_password/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
