defmodule WindowpaneWeb.PageController do
  use WindowpaneWeb, :controller

  def home(conn, _params) do
    render(conn, :studio_home, layout: false)
  end
end
