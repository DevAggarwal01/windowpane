defmodule WindowpaneWeb.LandingLive do
  use WindowpaneWeb, :live_view

  alias Windowpane.Projects
  alias Windowpane.MuxToken
  alias Windowpane.Ownership
  alias WindowpaneWeb.{LandingRowComponent, FilmModalComponent}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Discover Amazing Content")
      |> assign(:selected_film, nil)
      |> assign(:is_premiere, false)

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

    # Determine if this is a premiere based on the source
    is_premiere = params["source"] == "premieres"

    socket =
      socket
      |> assign(:selected_film, selected_film)
      |> assign(:trailer_token, trailer_token)
      |> assign(:user_owns_film, user_owns_film)
      |> assign(:ownership_id, ownership_id)
      |> assign(:is_premiere, is_premiere)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:close_film_modal, socket) do
    IO.puts("DEBUG: close_film_modal message received in LandingLive")
    # Close the modal by removing the id parameter from the URL
    {:noreply, push_patch(socket, to: ~p"/")}
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
          is_premiere={@is_premiere}
        />
      <% end %>
      <!-- Current Premieres Row -->
      <.live_component
        module={LandingRowComponent}
        id="current-premieres"
        title="Watch Now: Live Premieres"
        query_module={Projects}
        query_function={:list_minimal_current_premieres}
        query_params={6}
        show_more_path={~p"/premieres"}
        is_premiere={true}
      />
      <!-- Upcoming Premieres Row -->
      <.live_component
        module={LandingRowComponent}
        id="upcoming-premieres"
        title="Upcoming Premieres"
        query_module={Projects}
        query_function={:list_minimal_upcoming_premieres}
        query_params={6}
        show_more_path={~p"/premieres"}
        is_premiere={true}
      />



      <!-- Films Row -->
      <.live_component
        module={LandingRowComponent}
        id="films"
        title="Films"
        query_module={Projects}
        query_function={:list_minimal_published_films}
        query_params={6}
        show_more_path={~p"/browse"}
        is_premiere={false}
      />

      <!-- Additional Content Sections -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mt-12">
        <!-- Call to Action for Creators -->
        <div class="bg-gradient-to-r from-accent to-highlight rounded-lg p-6">
          <h3 class="text-xl font-bold text-white mb-2">Share Your Story</h3>
          <p class="text-blue-100 mb-4">
            Join thousands of creators sharing their films with audiences worldwide.
          </p>
          <.link
            href="http://studio.windowpane.tv"
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
    </main>
    """
  end
end
