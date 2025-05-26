defmodule AuroraWeb.Plugs.EnsureCreator do
  @moduledoc """
  This plug ensures that the current user has a creator role.
  It should be used after authentication is verified.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]

    # TODO: Replace this with your actual role check logic
    # This is just a placeholder - implement based on your User schema
    case user do
      %{role: "creator"} ->
        conn
      _ ->
        conn
        |> put_flash(:error, "You must be a creator to access this page.")
        |> redirect(to: "/")
        |> halt()
    end
  end
end
