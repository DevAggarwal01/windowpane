defmodule WindowpaneWeb.LandingLive do
  use WindowpaneWeb, :live_view

  alias Windowpane.Projects
  alias Windowpane.MuxToken

  @impl true
  def mount(_params, _session, socket) do
    # Fetch a limited number of published films for the landing page
    published_films = Projects.list_published_films(12)

    socket =
      socket
      |> assign(:published_films, published_films)
      |> assign(:page_title, "Discover Amazing Content")
      |> assign(:selected_film, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    selected_film =
      case params["id"] do
        nil -> nil
        id ->
          # Find the film by ID from the published films or fetch from database
          case Enum.find(socket.assigns.published_films, &(&1.id == String.to_integer(id))) do
            nil -> Projects.get_project(id) # Fallback to database if not in current list
            film -> film
          end
      end

    # Generate trailer token if film has trailer playback ID
    trailer_token = if selected_film && selected_film.film && selected_film.film.trailer_playback_id do
      MuxToken.generate_playback_token(selected_film.film.trailer_playback_id)
    else
      nil
    end

    socket =
      socket
      |> assign(:selected_film, selected_film)
      |> assign(:trailer_token, trailer_token)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Main Content -->
    <main class="max-w-7xl mx-auto px-4 py-6">
      <!-- Films Section -->
      <div class="mb-8">
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-2xl font-bold text-white">Films</h2>
          <%= if length(@published_films) > 0 do %>
            <.link
              navigate={~p"/browse"}
              class="text-accent hover:text-highlight font-medium"
            >
              Show more
            </.link>
          <% end %>
        </div>

        <%= if @published_films == [] do %>
          <!-- Empty State -->
          <div class="text-center py-16">
            <div class="mx-auto h-24 w-24 text-gray-400 mb-4">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2h4a1 1 0 110 2h-1v14a2 2 0 01-2 2H6a2 2 0 01-2-2V6H3a1 1 0 110-2h4z"></path>
              </svg>
            </div>
            <h3 class="text-lg font-medium text-white mb-2">No films available yet</h3>
            <p class="text-gray-400">Check back soon for new releases!</p>
          </div>
        <% else %>
          <!-- Films Grid -->
          <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
            <%= for film <- @published_films do %>
              <.link patch={~p"/?id=#{film.id}"} class="group">
                <div class="bg-gray-800 rounded-lg overflow-hidden transition-transform hover:scale-105">
                  <!-- Film Cover -->
                  <div class="aspect-[3/4] relative overflow-hidden bg-gray-700">
                    <%= if Windowpane.Uploaders.CoverUploader.cover_exists?(film) do %>
                      <img
                        src={Windowpane.Uploaders.CoverUploader.cover_url(film)}
                        alt={"Cover for #{film.title}"}
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

                  <!-- Film Info -->
                  <div class="p-3">
                    <h3 class="text-white font-medium text-sm truncate mb-1">
                      <%= film.title %>
                    </h3>
                    <p class="text-gray-400 text-xs truncate">
                      <%= film.creator.name %>
                    </p>
                  </div>
                </div>
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Additional Content Sections (similar to Twitch's layout) -->
      <%= if @published_films != [] do %>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mt-12">
          <!-- Call to Action for Creators -->
          <div class="bg-gradient-to-r from-accent to-highlight rounded-lg p-6">
            <h3 class="text-xl font-bold text-white mb-2">Share Your Story</h3>
            <p class="text-blue-100 mb-4">
              Join thousands of creators sharing their films with audiences worldwide.
            </p>
            <.link
              href="http://studio.windowpane.com"
              class="inline-flex items-center px-4 py-2 bg-white text-accent rounded-md font-medium hover:bg-gray-100 transition-colors"
            >
              Start Creating
              <svg class="ml-2 w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7l5 5m0 0l-5 5m5-5H6" />
              </svg>
            </.link>
          </div>

          <!-- Features Highlight -->
          <div class="bg-gray-800 rounded-lg p-6">
            <h3 class="text-xl font-bold text-white mb-4">Why Windowpane?</h3>
            <div class="space-y-3">
              <div class="flex items-center text-gray-300">
                <svg class="w-5 h-5 text-accent mr-3" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                High-quality streaming
              </div>
              <div class="flex items-center text-gray-300">
                <svg class="w-5 h-5 text-accent mr-3" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                Support independent creators
              </div>
              <div class="flex items-center text-gray-300">
                <svg class="w-5 h-5 text-accent mr-3" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                Discover unique content
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </main>

    <!-- Film Modal -->
    <%= if @selected_film do %>
      <.live_component
        module={WindowpaneWeb.FilmModalComponent}
        id="film-modal"
        film={@selected_film}
        trailer_token={@trailer_token}
        current_user={@current_user}
      />
    <% end %>
    """
  end
end
