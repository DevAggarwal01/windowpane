defmodule WindowpaneWeb.PageController do
  use WindowpaneWeb, :controller
  require Logger

  def home(conn, _params) do
    host = List.first(get_req_header(conn, "host")) || ""
    Logger.info("Host header: #{inspect(host)}")

    cond do
      # Match if host starts with "studio.windowpane.com"
      String.starts_with?(host, "studio.windowpane.com") ->
        Logger.info("Rendering studio_home")
        render(conn, :studio_home, layout: false)

      # Match if host starts with "windowpane.com"
      String.starts_with?(host, "windowpane.com") ->
        Logger.info("Rendering home")
        render(conn, :home, layout: false)

      # Default case
      true ->
        Logger.info("Default: Rendering home")
        render(conn, :home, layout: false)
    end
  end
end
