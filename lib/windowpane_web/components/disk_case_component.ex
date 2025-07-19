defmodule WindowpaneWeb.DiskCaseComponent do
  @moduledoc """
  A disk case component that displays a DVD case with a cover image.

  ## Usage

      <.live_component
        module={WindowpaneWeb.DiskCaseComponent}
        id="disk-case-123"
        id={123}
      />

  ## Parameters

  - `id` (required): The project ID used to retrieve the cover image

  """
  use WindowpaneWeb, :live_component

  alias Windowpane.Uploaders.CoverUploader

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # Check if cover exists for this ID
    cover_exists = CoverUploader.cover_exists?(assigns.id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:cover_exists, cover_exists)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"disk-case-#{@id}"} class="relative w-full max-w-[300px] aspect-[2/3]">
    <!-- Cover -->
    <div class="absolute inset-0 flex items-center justify-center">
      <div class="w-[100%]">
        <%= if @cover_exists do %>
          <img
            src={CoverUploader.cover_url(%{id: @id})}
            alt="Cover"
            class="w-full h-auto"
          />
        <% else %>
          <div class="w-full aspect-[3/4] bg-gray-200 flex items-center justify-center">
            <div class="text-center">
              <span class="text-2xl mb-1 block">🎬</span>
              <span class="text-xs text-gray-500 font-medium">No Cover</span>
            </div>
          </div>
        <% end %>
      </div>
    </div>

    <!-- DVD Case -->
    <img
      src={~p"/images/dvd_case.png"}
      alt="DVD Case"
      class="absolute inset-0 w-full h-full object-contain"
    />
  </div>
    """
  end
end
