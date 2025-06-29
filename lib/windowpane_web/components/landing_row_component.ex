defmodule WindowpaneWeb.LandingRowComponent do
  use WindowpaneWeb, :live_component

  alias Windowpane.Uploaders.CoverUploader

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :items, [])}
  end

  @impl true
  def update(assigns, socket) do
    # Fetch items using the provided query function
    items = apply(assigns.query_module, assigns.query_function, [assigns.query_params])

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
            <.link patch={~p"/?id=#{item.id}"} class="group">
              <div class="bg-gray-800 rounded-lg overflow-hidden transition-transform hover:scale-105">
                <!-- Cover -->
                <div class="aspect-[3/4] relative overflow-hidden bg-gray-700">
                  <%= if CoverUploader.cover_exists?(%{id: item.id}) do %>
                    <img
                      src={CoverUploader.cover_url(%{id: item.id})}
                      alt="Cover"
                      class="w-full h-full object-cover"
                      loading="lazy"
                    />
                  <% else %>
                    <div class="flex items-center justify-center w-full h-full">
                      <div class="text-center">
                        <span class="text-4xl mb-2 block">🎬</span>
                        <span class="text-xs text-gray-400 font-medium">No Cover</span>
                      </div>
                    </div>
                  <% end %>

                  <!-- Hover overlay with play icon -->
                  <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-40 transition-all duration-300 flex items-center justify-center">
                    <div class="opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                      <div class="w-12 h-12 bg-white bg-opacity-90 rounded-full flex items-center justify-center">
                        <svg class="w-6 h-6 text-gray-900 ml-1" fill="currentColor" viewBox="0 0 20 20">
                          <path d="M8 5v10l8-5-8-5z"/>
                        </svg>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="p-3">
                  <p class="text-gray-400 text-xs truncate">
                    <%= item.creator_name %>
                  </p>
                  <%= if Map.has_key?(item, :start_time) do %>
                    <p class="text-accent text-xs mt-1">
                      <%= Calendar.strftime(item.start_time, "%B %d, %Y") %>
                    </p>
                  <% end %>
                </div>
              </div>
            </.link>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
