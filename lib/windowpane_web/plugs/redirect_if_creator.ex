defmodule WindowpaneWeb.Plugs.RedirectIfCreator do
  @moduledoc """
  This plug redirects to the home page if the current user is already a creator.
  Non-creator authenticated users are allowed to proceed (to upgrade their account).
  """
  import Phoenix.Controller
  import Plug.Conn

  def on_mount(:redirect_if_creator, _params, session, socket) do
    if user = session["current_user"] do
      # TODO: Replace with your actual role check
      case user do
        %{role: "creator"} ->
          {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
        _ ->
          {:cont, socket}
      end
    else
      {:cont, socket}
    end
  end

  def init(opts), do: opts

  def call(conn, _opts) do
    if user = conn.assigns[:current_user] do
      # TODO: Replace with your actual role check
      case user do
        %{role: "creator"} ->
          conn
          |> redirect(to: "/")
          |> halt()
        _ ->
          conn
      end
    else
      conn
    end
  end
end
