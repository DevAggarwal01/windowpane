defmodule WindowpaneWeb.LandingRowComponent do
  use WindowpaneWeb, :live_component

  alias Windowpane.Uploaders.CoverUploader
  alias WindowpaneWeb.DiskCaseComponent

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :items, [])}
  end

  @impl true
  def update(assigns, socket) do
    # Debug: Log the incoming assigns
    IO.puts("LandingRowComponent update for #{assigns.id} with query: #{inspect(assigns.query_function)}")

    # Fetch items using the provided query function
    items = apply(assigns.query_module, assigns.query_function, [assigns.query_params])

    # Debug: Log the items received
    IO.puts("Items received for #{assigns.id}: #{inspect(items, pretty: true)}")

    {:ok, assign(socket, assigns) |> assign(:items, items)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-8">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-2xl font-bold text-black"><%= @title %></h2>
        <%= if length(@items) > 0 and @show_more_path do %>
          <.link
            navigate={@show_more_path}
            class="text-accent hover:text-highlight font-medium"
          >
            Show more
          </.link>
        <% end %>
      </div>

      <%= if @items == [] do %>
        <!-- Empty State -->
        <div class="text-center py-16">
          <div class="mx-auto h-24 w-24 text-gray-400 mb-4">
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2h4a1 1 0 110 2h-1v14a2 2 0 01-2 2H6a2 2 0 01-2-2V6H3a1 1 0 110-2h4z"></path>
            </svg>
          </div>
          <h3 class="text-lg font-medium text-white mb-2">No items available yet</h3>
          <p class="text-gray-400">Check back soon for new content!</p>
        </div>
      <% else %>
        <!-- Grid -->
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
          <%= for item <- @items do %>
            <.link patch={~p"/?id=#{item.id}&source=#{if @is_premiere, do: "premieres", else: "films"}"} class="group">
              <!-- Disk Case Component - No wrapper, no styling, just the clickable image -->
              <.live_component
                module={DiskCaseComponent}
                id={"disk-case-#{item.id}"}
                id={item.id}
              />
            </.link>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
