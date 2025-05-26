defmodule AuroraWeb.StudioHTML do
  @moduledoc """
  This module contains pages rendered by StudioController.

  See the `studio_html` directory for all templates available.
  """
  use AuroraWeb, :html

  embed_templates "studio_html/*"
end
