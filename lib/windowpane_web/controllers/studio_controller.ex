defmodule WindowpaneWeb.StudioController do
  use WindowpaneWeb, :controller
  require Logger

  def home(conn, _params) do
    render(conn, :home, layout: false)
  end
end
