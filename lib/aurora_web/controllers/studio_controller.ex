defmodule AuroraWeb.StudioController do
  use AuroraWeb, :controller
  require Logger

  def home(conn, _params) do
    render(conn, :home, layout: false)
  end
end
