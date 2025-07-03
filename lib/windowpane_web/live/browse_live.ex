defmodule WindowpaneWeb.BrowseLive do
  use WindowpaneWeb, :live_view

  alias Windowpane.Projects
  alias Windowpane.MuxToken
  alias Windowpane.Ownership
  alias Windowpane.Uploaders.CoverUploader
  alias WindowpaneWeb.FilmModalComponent

  @impl true
  def mount(_params, _session, socket) do
    # Fetch 30 published films
    films = Projects.list_published_films_with_creator_names(30)

    socket =
      socket
      |> assign(:page_title, "Browse Films")
      |> assign(:films, films)
      |> assign(:selected_film, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    selected_film =
      case params["id"] do
        nil -> nil
        id ->
          # Fetch just the basic project info for the modal
          Projects.get_project_with_associations_and_creator_name!(String.to_integer(id))
      end

    # Check if current user owns this film and get ownership record ID
    {user_owns_film, ownership_id} = if selected_film && socket.assigns[:current_user] do
      if Ownership.user_owns_project?(socket.assigns.current_user.id, selected_film.id) do
        # Get the active ownership record ID
        ownership_record = Ownership.get_active_ownership_record(socket.assigns.current_user.id, selected_film.id)
        {true, ownership_record && ownership_record.id}
      else
        {false, nil}
      end
    else
      {false, nil}
    end

    # Generate trailer token efficiently using Projects.get_playback_id
    trailer_token = if selected_film && selected_film.type == "film" do
      case Projects.get_playback_id(selected_film, "trailer") do
        nil -> nil
        playback_id -> MuxToken.generate_playback_token(playback_id)
      end
    else
      nil
    end

    socket =
      socket
      |> assign(:selected_film, selected_film)
      |> assign(:trailer_token, trailer_token)
      |> assign(:user_owns_film, user_owns_film)
      |> assign(:ownership_id, ownership_id)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:close_film_modal, socket) do
    # Close the modal by removing the id parameter from the URL
    {:noreply, push_patch(socket, to: ~p"/browse")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Main Content -->
    <main class="max-w-7xl mx-auto px-4 py-6">
      <!-- Film Modal Component -->
      <%= if @selected_film do %>
        <.live_component
          module={FilmModalComponent}
          id="film-modal"
          film={@selected_film}
          trailer_token={@trailer_token}
          current_user={@current_user}
          user_owns_film={@user_owns_film}
          ownership_id={@ownership_id}
          is_premiere={false}
        />
      <% end %>

      <!-- Page Header -->
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-black">Browse Films</h1>
        <p class="text-gray-600 mt-2">Discover amazing independent films from creators around the world</p>
      </div>

      <!-- Films Grid -->
      <%= if @films == [] do %>
        <!-- Empty State -->
        <div class="text-center py-16">
          <div class="mx-auto h-24 w-24 text-gray-400 mb-4">
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2h4a1 1 0 110 2h-1v14a2 2 0 01-2 2H6a2 2 0 01-2-2V6H3a1 1 0 110-2h4z"></path>
            </svg>
          </div>
          <h3 class="text-lg font-medium text-gray-900 mb-2">No films available yet</h3>
          <p class="text-gray-500">Check back soon for new content!</p>
        </div>
      <% else %>
        <!-- Films Grid -->
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-6">
          <%= for film <- @films do %>
            <.link patch={~p"/browse?id=#{film.id}"} class="group">
              <div class="bg-gray-800 rounded-lg overflow-hidden transition-transform hover:scale-105 shadow-lg">
                <!-- Cover -->
                <div class="aspect-[3/4] relative overflow-hidden bg-gray-700">
                  <%= if CoverUploader.cover_exists?(%{id: film.id}) do %>
                    <img
                      src={CoverUploader.cover_url(%{id: film.id})}
                      alt={film.title || "Film cover"}
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
                  <h3 class="text-white text-sm font-medium truncate mb-1">
                    <%= film.title || "Untitled" %>
                  </h3>
                  <p class="text-gray-400 text-xs truncate">
                    <%= film.creator.name %>
                  </p>
                  <%= if film.premiere_date do %>
                    <p class="text-accent text-xs mt-1">
                      <%= Calendar.strftime(film.premiere_date, "%B %d, %Y") %>
                    </p>
                  <% end %>
                </div>
              </div>
            </.link>
          <% end %>
        </div>
      <% end %>
    </main>
    """
  end
end
