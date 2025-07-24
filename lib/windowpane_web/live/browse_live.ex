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
      |> assign(:show_login_modal, false)

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
  def handle_event("show_login_modal", _params, socket) do
    {:noreply, assign(socket, show_login_modal: true)}
  end

  @impl true
  def handle_info(:close_login_modal, socket) do
    {:noreply, assign(socket, show_login_modal: false)}
  end

  @impl true
  def handle_info({:login_success, _user, _token}, socket) do
    {:noreply, redirect(socket, to: "/")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Main Content -->
    <main class="min-h-screen w-full px-4 py-6" style="background-color: #000000;">
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

      <!-- Filter Buttons (commented out) -->

      <div class="flex justify-center gap-4 mb-8">
        <button class="px-6 py-2 border-2 border-white bg-black text-white font-bold uppercase tracking-wider text-sm rounded-none transition-transform duration-150 hover:scale-110 focus:outline-none focus:ring-2 focus:ring-accent" style="letter-spacing: 0.08em;">All</button>
        <%#
        <button class="px-6 py-2 border-2 border-white bg-black text-white font-bold uppercase tracking-wider text-sm rounded-none transition-transform duration-150 hover:scale-110 focus:outline-none focus:ring-2 focus:ring-accent" style="letter-spacing: 0.08em;">Films</button>
        <button class="px-6 py-2 border-2 border-white bg-black text-white font-bold uppercase tracking-wider text-sm rounded-none transition-transform duration-150 hover:scale-110 focus:outline-none focus:ring-2 focus:ring-accent" style="letter-spacing: 0.08em;">Livestreams</button>
        %>
      </div>

      <!-- Search Bar (commented out) -->
      <%#
      <div class="flex justify-center w-full mt-2 mb-10">
        <div class="relative w-full max-w-lg">
          <input
            type="text"
            placeholder="SEARCH"
            class="w-full pl-10 pr-10 py-2 bg-white border border-accent rounded-none text-gray-900 placeholder-gray-700 shadow-lg focus:outline-none focus:ring-2 focus:ring-accent text-base font-bold uppercase tracking-wider font-mono"
            style="letter-spacing: 0.08em; border-width: 2px;"
          />
          <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <svg class="h-5 w-5 text-accent" fill="none" stroke="currentColor" viewBox="0 0 24 24" style="border-radius:0;">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
          </div>
          <button class="absolute inset-y-0 right-0 pr-3 flex items-center" style="border-radius:0;">
            <svg class="h-5 w-5 text-accent hover:text-accent-dark" fill="none" stroke="currentColor" viewBox="0 0 24 24" style="border-radius:0;">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
          </button>
        </div>
      </div>
      %>
      <!-- Films Grid -->
      <%= if @films == [] do %>
        <!-- Empty State -->
        <div class="text-center py-16">
          <div class="mx-auto h-24 w-24 text-gray-400 mb-4">
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2h4a1 1 0 110 2h-1v14a2 2 0 01-2 2H6a2 2 0 01-2-2V6H3a1 1 0 110-2h4z"></path>
            </svg>
          </div>
        </div>
      <% else %>
        <!-- Films Grid with White Grid Lines -->
        <div class="p-8 bg-black">
          <style>
            .films-grid {
              display: grid;
              grid-template-columns: repeat(2, 1fr);
              background-color: black;
              border-top: 2px solid white;
            }

            @media (min-width: 640px) {
              .films-grid {
                grid-template-columns: repeat(3, 1fr);
              }
            }

            @media (min-width: 768px) {
              .films-grid {
                grid-template-columns: repeat(4, 1fr);
              }
            }

            @media (min-width: 1024px) {
              .films-grid {
                grid-template-columns: repeat(5, 1fr);
              }
            }

            @media (min-width: 1280px) {
              .films-grid {
                grid-template-columns: repeat(6, 1fr);
              }
            }

            .film-item {
              background-color: black;
              transition: all 0.15s ease-in-out;
              border-right: 2px solid white;
              border-bottom: 2px solid white;
            }

            .film-item:hover {
              transform: scale(1.05);
              border: 2px solid white;
              z-index: 10;
              position: relative;
            }

            /* Remove right border from last column items */
            .film-item:nth-child(2n) {
              border-right: none;
            }

            @media (min-width: 640px) {
              .film-item:nth-child(2n) {
                border-right: 2px solid white;
              }
              .film-item:nth-child(3n) {
                border-right: none;
              }
            }

            @media (min-width: 768px) {
              .film-item:nth-child(3n) {
                border-right: 2px solid white;
              }
              .film-item:nth-child(4n) {
                border-right: none;
              }
            }

            @media (min-width: 1024px) {
              .film-item:nth-child(4n) {
                border-right: 2px solid white;
              }
              .film-item:nth-child(5n) {
                border-right: none;
              }
            }

            @media (min-width: 1280px) {
              .film-item:nth-child(5n) {
                border-right: 2px solid white;
              }
              .film-item:nth-child(6n) {
                border-right: none;
              }
            }
          </style>

          <div class="films-grid">
            <%= for film <- @films do %>
              <.link patch={~p"/info?trailer_id=#{film.id}"} class="group film-item">
                <!-- Cover -->
                <div class="aspect-square relative overflow-hidden bg-black">
                  <%= if CoverUploader.cover_exists?(%{id: film.id}) do %>
                    <img
                      src={CoverUploader.cover_url(%{id: film.id})}
                      alt="Film cover"
                      class="w-full h-full object-cover"
                      loading="lazy"
                    />
                  <% else %>
                    <div class="flex items-center justify-center w-full h-full">
                      <span class="text-4xl">🎬</span>
                    </div>
                  <% end %>
                </div>
              </.link>
            <% end %>
          </div>
        </div>
      <% end %>
    </main>
    """
  end
end
