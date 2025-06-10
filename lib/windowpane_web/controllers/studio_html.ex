defmodule WindowpaneWeb.StudioHTML do
  @moduledoc """
  This module contains pages rendered by StudioController.

  See the `studio_html` directory for all templates available.
  """
  use WindowpaneWeb, :html

  embed_templates "studio_html/*"
end
