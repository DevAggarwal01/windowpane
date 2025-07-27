defmodule WindowpaneWeb.BrowseLive do
  use WindowpaneWeb, :live_view

  alias Windowpane.Projects
  alias WindowpaneWeb.FilmsGridComponent

  @impl true
  def mount(_params, _session, socket) do
    # Fetch 30 published films
    films = Projects.list_published_films_with_creator_names(30)
    project_ids = Enum.map(films, & &1.id)

    socket =
      socket
      |> assign(:page_title, "Browse Films")
      |> assign(:project_ids, project_ids)
      |> assign(:show_login_modal, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
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
      <.live_component
        module={FilmsGridComponent}
        id="films-grid"
        project_ids={@project_ids}
      />
    </main>
    """
  end
end
