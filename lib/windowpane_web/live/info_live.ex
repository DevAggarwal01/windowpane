defmodule WindowpaneWeb.InfoLive do
  use WindowpaneWeb, :live_view
  require Logger

  alias Windowpane.Projects

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, project: nil, playback_id: nil, content_type: nil, ownership_record: nil)}
  end

  @impl true
  def handle_params(%{"trailer_id" => trailer_id}, _url, socket) do
    Logger.info("InfoLive: Starting trailer handle_params with trailer_id=#{trailer_id}")

    try do
      project_id = String.to_integer(trailer_id)
      Logger.info("InfoLive: Parsed project_id=#{project_id}")

      # Get the project with film data preloaded
      project = Projects.get_project_with_film_and_creator_name!(project_id)
      Logger.info("InfoLive: Found project id=#{project.id}, title='#{project.title}', type=#{project.type}")

      # Check if project is published
      if project.status != "published" do
        Logger.warning("InfoLive: Project not published (status=#{project.status})")
        redirect_to_home(socket)
      else
        # Check if project has a trailer
        if project.film && project.film.trailer_playback_id do
          Logger.info("InfoLive: Setting up info page for project '#{project.title}' (trailer_playback_id=#{project.film.trailer_playback_id})")
          setup_info_page(socket, project)
        else
          Logger.warning("InfoLive: No trailer available for project id=#{project.id}")
          redirect_to_home(socket)
        end
      end
    rescue
      ArgumentError ->
        # Invalid ID format
        Logger.error("InfoLive: Invalid trailer_id format for trailer_id=#{trailer_id}")
        redirect_to_home(socket)
      Ecto.NoResultsError ->
        # Project not found
        Logger.error("InfoLive: Project not found for trailer_id=#{trailer_id}")
        redirect_to_home(socket)
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  # Helper function to redirect to home page
  defp redirect_to_home(socket) do
    Logger.info("InfoLive: Redirecting to home page")
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  # Helper function to set up the info page
  defp setup_info_page(socket, project) do
    Logger.info("InfoLive: Setting up info page for project '#{project.title}' (trailer_playback_id=#{project.film.trailer_playback_id})")

    socket =
      socket
      |> assign(:project, project)
      |> assign(:playback_id, project.film.trailer_playback_id)
      |> assign(:content_type, "trailer")
      |> assign(:playback_token, nil)
      |> assign(:ownership_record, nil)
      |> assign(:page_title, project.title)
      |> assign(:invalid_type, false)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= cond do %>
      <% @project && @project.film && @project.film.trailer_playback_id && !@playback_token -> %>
        <!-- Trailer Info Container -->
        <div class="min-h-screen bg-gray-50">
          <!-- Main Content -->
          <div class="flex pl-8">
            <!-- Left Side - Video Player (maintain exact current size) -->
            <div class="w-4/5 pr-4 pb-12 flex-shrink-0">
              <!-- Player Container -->
              <div class="aspect-video bg-black">
                <mux-player
                  playback-id={@project.film.trailer_playback_id}
                  stream-type="on-demand"
                  class="w-full h-full"
                ></mux-player>
              </div>

              <!-- Creator Info Below Video -->
              <div class="mt-4">
                <p class="text-gray-900 text-lg font-medium">
                  CREATOR INFO HERE - <%= @project.creator.name %>
                </p>
              </div>
            </div>

            <!-- Right Side - Film Details Card -->
            <div class="flex-1 p-4">
              <div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden max-w-sm">
                <!-- Film Cover -->
                <div class="aspect-[3/4] bg-gray-100 relative">
                  <%= if Windowpane.Uploaders.CoverUploader.cover_exists?(@project) do %>
                    <img
                      src={Windowpane.Uploaders.CoverUploader.cover_url(@project)}
                      alt={"Cover for #{@project.title}"}
                      class="w-full h-full object-cover"
                    />
                  <% else %>
                    <div class="flex items-center justify-center w-full h-full">
                      <div class="text-center text-gray-400">
                        <span class="text-6xl mb-2 block">🎬</span>
                        <span class="text-sm font-medium">No Cover</span>
                      </div>
                    </div>
                  <% end %>
                </div>

                <!-- Film Details -->
                <div class="p-4">
                  <h1 class="text-xl font-bold text-gray-900 mb-2"><%= @project.title %></h1>
                  <p class="text-gray-600 mb-3">By <%= @project.creator.name %></p>

                  <!-- Status Badge -->
                  <div class="flex items-center gap-2 mb-4">
                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                      🎬 TRAILER
                    </span>
                  </div>

                  <!-- Film Info -->
                  <div class="space-y-2 text-sm">
                    <%= if @project.description && String.trim(@project.description) != "" do %>
                      <div>
                        <p class="text-gray-700 leading-relaxed">
                          <%= @project.description %>
                        </p>
                      </div>
                    <% end %>

                    <div class="pt-2 border-t border-gray-100">
                      <div class="space-y-1">
                        <div class="flex justify-between">
                          <span class="text-gray-500">Type:</span>
                          <span class="text-gray-800 capitalize"><%= @project.type %></span>
                        </div>
                        <%= if @project.premiere_date do %>
                          <div class="flex justify-between">
                            <span class="text-gray-500">Premiered:</span>
                            <span class="text-gray-800">
                              <%= Calendar.strftime(@project.premiere_date, "%B %Y") %>
                            </span>
                          </div>
                        <% end %>
                        <div class="flex justify-between">
                          <span class="text-gray-500">Status:</span>
                          <span class="text-blue-600 font-medium">
                            Trailer Preview
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

      <% true -> %>
        <!-- Error State -->
        <div class="min-h-screen bg-gray-50 flex items-center justify-center">
          <div class="text-center max-w-md mx-auto p-6">
            <div class="w-16 h-16 mx-auto mb-4 text-gray-400">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" class="w-full h-full">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.232 15.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">Invalid URL</h3>
            <p class="text-gray-600 mb-6">The requested content could not be found or you don't have access to it.</p>
            <.link
              navigate={~p"/"}
              class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-md font-medium hover:bg-blue-700 transition-colors"
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
