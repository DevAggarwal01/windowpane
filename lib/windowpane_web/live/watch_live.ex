defmodule WindowpaneWeb.WatchLive do
  use WindowpaneWeb, :live_view

  alias Windowpane.Projects
  alias Windowpane.MuxToken

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, project: nil, playback_token: nil, content_type: nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    try do
      # First get basic project to check type
      basic_project = Projects.get_project!(id)

      # Validate project type
      case basic_project.type do
        type when type in ["film", "tv_show", "live_stream"] ->
          # For supported types that need film data, get project with film
          project = Projects.get_project_with_film!(id)
          |> Windowpane.Repo.preload(:creator)

          # Show the trailer if available, otherwise show full content
          {playback_id, content_type} = if project.film && project.film.trailer_playback_id do
            {project.film.trailer_playback_id, "trailer"}
          else
            if project.film && project.film.film_playback_id do
              {project.film.film_playback_id, "full"}
            else
              {nil, "content"}
            end
          end

          playback_token = if playback_id do
            MuxToken.generate_playback_token(playback_id)
          else
            nil
          end

          socket =
            socket
            |> assign(:project, project)
            |> assign(:playback_token, playback_token)
            |> assign(:content_type, content_type)
            |> assign(:playback_id, playback_id)
            |> assign(:page_title, if(project, do: project.title, else: "Watch"))
            |> assign(:invalid_type, false)

          {:noreply, socket}

        _ ->
          # Invalid project type - only need basic project data
          project = basic_project |> Windowpane.Repo.preload(:creator)

          socket =
            socket
            |> assign(:project, project)
            |> assign(:playback_token, nil)
            |> assign(:content_type, nil)
            |> assign(:playback_id, nil)
            |> assign(:page_title, "Invalid Content")
            |> assign(:invalid_type, true)

          {:noreply, socket}
      end
    rescue
      Ecto.NoResultsError ->
        socket =
          socket
          |> assign(:project, nil)
          |> assign(:playback_token, nil)
          |> assign(:content_type, nil)
          |> assign(:playback_id, nil)
          |> assign(:page_title, "Watch")
          |> assign(:invalid_type, false)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= cond do %>
      <% @invalid_type -> %>
        <!-- Invalid Content Type -->
        <div class="min-h-screen bg-gray-900 flex items-center justify-center">
          <div class="text-center">
            <div class="mx-auto h-24 w-24 text-gray-400 mb-4">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.232 15.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-white mb-2">Invalid Link</h3>
            <p class="text-gray-400 mb-6">This content type is not supported for viewing. Only films, TV shows, and live streams can be watched.</p>
            <.link
              navigate={~p"/"}
              class="inline-flex items-center px-4 py-2 bg-accent text-white rounded-md font-medium hover:bg-highlight transition-colors"
            >
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
              Back to Browse
            </.link>
          </div>
        </div>

      <% @project && @playback_id && @playback_token -> %>
        <!-- Video Player Container -->
        <div class="w-full h-screen bg-black flex flex-col">
          <!-- Back Button -->
          <div class="absolute top-4 left-4 z-20">
            <.link
              navigate={if @content_type == "trailer", do: ~p"/?id=#{@project.id}", else: ~p"/"}
              class="inline-flex items-center px-3 py-2 bg-black bg-opacity-50 hover:bg-opacity-75 text-white rounded-md transition-all"
            >
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
              Back
            </.link>
          </div>

          <!-- Video Player -->
          <div class="flex-1 flex items-center justify-center">
            <mux-player
              playback-id={@playback_id}
              playback-token={@playback_token}
              stream-type="on-demand"
              title={@project.title}
              class="w-full h-full"
            ></mux-player>
          </div>

          <!-- Content Info (shown only for full films, not trailers) -->
          <%= if @content_type == "full" do %>
            <div class="bg-black bg-opacity-90 text-white p-6">
              <div class="max-w-4xl mx-auto">
                <div class="flex items-start justify-between">
                  <div class="flex-1">
                    <h1 class="text-2xl font-bold mb-2"><%= @project.title %></h1>
                    <p class="text-gray-300 mb-4">By <%= @project.creator.name %></p>
                    <%= if @project.description && String.trim(@project.description) != "" do %>
                      <p class="text-gray-300 text-sm leading-relaxed mb-4">
                        <%= @project.description %>
                      </p>
                    <% end %>
                  </div>
                  <div class="flex space-x-3 ml-6">
                    <button
                      type="button"
                      class="inline-flex flex-col items-center px-4 py-3 bg-white text-black font-semibold rounded hover:bg-gray-200 transition-colors"
                    >
                      <span class="text-sm">Rent movie</span>
                      <span class="text-lg font-bold">
                        <%= if @project.rental_price, do: "$#{Decimal.to_string(@project.rental_price)}", else: "Free" %>
                      </span>
                    </button>
                    <button
                      type="button"
                      class="inline-flex flex-col items-center px-4 py-3 bg-white text-black font-semibold rounded hover:bg-gray-200 transition-colors"
                    >
                      <span class="text-sm">Buy</span>
                      <span class="text-lg font-bold">
                        <%= if @project.purchase_price, do: "$#{Decimal.to_string(@project.purchase_price)}", else: "Free" %>
                      </span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>

      <% true -> %>
        <!-- Error State -->
        <div class="min-h-screen bg-gray-900 flex items-center justify-center">
          <div class="text-center">
            <div class="mx-auto h-24 w-24 text-gray-400 mb-4">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-white mb-2">Content not available</h3>
            <p class="text-gray-400 mb-6">The requested content could not be found or is not available for viewing.</p>
            <.link
              navigate={~p"/"}
              class="inline-flex items-center px-4 py-2 bg-accent text-white rounded-md font-medium hover:bg-highlight transition-colors"
            >
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
              Back to Browse
            </.link>
          </div>
        </div>
    <% end %>
    """
  end
end
