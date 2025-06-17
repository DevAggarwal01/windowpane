defmodule WindowpaneWeb.BrowseLive do
  use WindowpaneWeb, :live_view

  import WindowpaneWeb.NavComponents
  alias Windowpane.Projects
  alias Windowpane.Uploaders.CoverUploader

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user] || socket.assigns[:current_creator]
    is_creator = !!socket.assigns[:current_creator]

    # TODO pagination

    # Fetch published films with initial limit of 7
    published_films = Projects.list_published_films(7)
    total_films_count = Projects.count_published_films()

    {:ok, assign(socket,
      user: user,
      is_creator: is_creator,
      current_path: socket.assigns.live_action,
      published_films: published_films,
      total_films_count: total_films_count,
      displayed_films_count: min(7, total_films_count)
    )}
  end

  @impl true
  def handle_event("show_more_films", _params, socket) do
    current_count = socket.assigns.displayed_films_count
    new_count = min(current_count + 14, socket.assigns.total_films_count)

    # Fetch films up to the new count
    published_films = Projects.list_published_films(new_count)

    {:noreply, assign(socket,
      published_films: published_films,
      displayed_films_count: new_count
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100">
      <.main_header current_path={@current_path} is_creator={@is_creator} />

      <div class="container mx-auto px-4 py-8">
        <!-- Hero Section -->
        <div class="text-center mb-12">
          <h1 class="text-4xl font-bold text-gray-900 mb-4">Discover Amazing Films</h1>
          <p class="text-xl text-gray-600 max-w-2xl mx-auto">
            Explore our curated collection of independent films from talented creators around the world.
          </p>
        </div>

        <!-- Films Section -->
        <div class="mb-12">
          <div class="flex items-center justify-between mb-8">
            <h2 class="text-3xl font-bold text-gray-900">Featured Films</h2>
            <div class="text-sm text-gray-500">
              <%= @total_films_count %> films available
            </div>
          </div>

          <%= if @published_films == [] do %>
            <div class="text-center py-16">
              <div class="mx-auto h-24 w-24 text-gray-400 mb-4">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2h4a1 1 0 110 2h-1v14a2 2 0 01-2 2H6a2 2 0 01-2-2V6H3a1 1 0 110-2h4z"></path>
                </svg>
              </div>
              <h3 class="text-lg font-medium text-gray-900 mb-2">No films available yet</h3>
              <p class="text-gray-500">Check back soon for new releases!</p>
            </div>
          <% else %>
            <div class="grid grid-cols-3 md:grid-cols-5 lg:grid-cols-7 xl:grid-cols-7 gap-3">
              <%= for film <- @published_films do %>
                <.link navigate={~p"/#{film.id}"} class="group">
                  <div class="bg-white rounded-lg shadow-md hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1 overflow-hidden">
                    <!-- Cover Image -->
                    <div class="aspect-[2/3] relative overflow-hidden bg-gray-100">
                      <%= if CoverUploader.cover_exists?(film) do %>
                        <img
                          src={CoverUploader.cover_url(film)}
                          alt={"Cover for #{film.title}"}
                          class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                          loading="lazy"
                        />
                      <% else %>
                        <div class="flex items-center justify-center w-full h-full bg-gradient-to-br from-gray-200 to-gray-300">
                          <div class="text-center">
                            <span class="text-3xl mb-2 block">🎬</span>
                            <span class="text-xs text-gray-500 font-medium">No Cover</span>
                          </div>
                        </div>
                      <% end %>

                      <!-- Hover overlay -->
                      <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-20 transition-all duration-300">
                      </div>
                    </div>

                    <!-- Film Info -->
                    <div class="p-3">
                      <p class="text-xs text-gray-600 text-center truncate">
                        by <%= film.creator.name %>
                      </p>
                    </div>
                  </div>
                </.link>
              <% end %>
            </div>

            <%= if @displayed_films_count < @total_films_count do %>
              <div class="flex justify-center mt-8">
                <button
                  phx-click="show_more_films"
                  class="inline-flex items-center px-6 py-3 bg-white text-gray-700 rounded-lg border border-gray-300 hover:bg-gray-50 hover:border-gray-400 transition-colors duration-200 shadow-sm"
                >
                  <span class="mr-2">Show more</span>
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
              </div>
            <% end %>
          <% end %>
        </div>

        <!-- Additional Sections -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mt-16">
          <!-- Coming Soon -->
          <div class="bg-white rounded-xl shadow-lg p-8">
            <h3 class="text-2xl font-bold text-gray-900 mb-4">Coming Soon</h3>
            <p class="text-gray-600 mb-6">
              More exciting content types are on the way! Stay tuned for TV shows, live events, and more.
            </p>
            <div class="flex space-x-4">
              <div class="flex items-center text-sm text-gray-500">
                <span class="text-2xl mr-2">📺</span>
                TV Shows
              </div>
              <div class="flex items-center text-sm text-gray-500">
                <span class="text-2xl mr-2">🎤</span>
                Live Events
              </div>
              <div class="flex items-center text-sm text-gray-500">
                <span class="text-2xl mr-2">📚</span>
                Books
              </div>
            </div>
          </div>

          <!-- Creator Spotlight -->
          <div class="bg-gradient-to-r from-blue-500 to-purple-600 rounded-xl shadow-lg p-8 text-white">
            <h3 class="text-2xl font-bold mb-4">For Creators</h3>
            <p class="mb-6 opacity-90">
              Share your creative work with the world. Join our platform and start showcasing your films today.
            </p>
            <.link
              navigate={~p"/"}
              class="inline-flex items-center px-4 py-2 bg-white text-blue-600 rounded-lg font-semibold hover:bg-gray-100 transition-colors"
            >
              Get Started
              <svg class="ml-2 w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7l5 5m0 0l-5 5m5-5H6" />
              </svg>
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp format_price(nil), do: "0.00"
  defp format_price(price) when is_struct(price, Decimal), do: Decimal.to_string(price)
  defp format_price(price), do: "#{price}"

  defp format_date(nil), do: ""
  defp format_date(date) do
    Calendar.strftime(date, "%b %Y")
  end
end
