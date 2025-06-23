defmodule WindowpaneWeb.ProjectLive.Show do
  use WindowpaneWeb, :live_view

  alias Windowpane.Projects
  alias WindowpaneWeb.FilmSetupComponent
  alias WindowpaneWeb.LiveStreamSetupComponent
  alias WindowpaneWeb.FilmModalComponent

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    project = case get_project_with_associations(id) do
      {:ok, project} -> project
      {:error, _} -> Projects.get_project!(id)
    end

    {:ok,
     socket
     |> assign(:page_title, "Project Details")
     |> assign(:project, project)
     |> assign(:editing, false)
     |> assign(:show_film_modal, false)}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    project = case get_project_with_associations(id) do
      {:ok, project} -> project
      {:error, _} -> Projects.get_project!(id)
    end

    editing = Map.get(params, "edit", "false") == "true"

    {:noreply,
     socket
     |> assign(:project, project)
     |> assign(:editing, editing)}
  end

  @impl true
  def handle_info({:project_updated, project, editing}, socket) do
    {:noreply,
     socket
     |> assign(:project, project)
     |> assign(:editing, editing)}
  end

  @impl true
  def handle_info({:show_film_modal, project}, socket) do
    # Show the film modal with the project
    {:noreply,
     socket
     |> assign(:show_film_modal, true)
     |> assign(:modal_project, project)}
  end

  @impl true
  def handle_info(:close_film_modal, socket) do
    {:noreply, assign(socket, :show_film_modal, false)}
  end

  @impl true
  def handle_event("close_film_modal", _params, socket) do
    {:noreply, assign(socket, :show_film_modal, false)}
  end

  # Helper function to get project with appropriate associations based on type
  defp get_project_with_associations(id) do
    try do
      project = Projects.get_project!(id)
      case project.type do
        "film" ->
          {:ok, Projects.get_project_with_film_and_reviews!(id)}
        "live_event" ->
          {:ok, Projects.get_project_with_live_stream_and_reviews!(id)}
        _ ->
          {:ok, project}
      end
    rescue
      _ -> {:error, :not_found}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.flash_group flash={@flash} />

    <!-- Film Modal Component -->
    <%= if @show_film_modal do %>
      <.live_component
        module={FilmModalComponent}
        id="film-modal"
        film={@modal_project}
        trailer_token={nil}
        current_user={assigns[:current_user]}
      />
    <% end %>

    <!-- Enhanced Header Section -->
    <div class="bg-white border-b border-gray-200">
      <div class="container mx-auto px-4 py-6">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <.link
              navigate={~p"/dashboard"}
              class="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-600 bg-gray-50 rounded-lg hover:bg-gray-100 hover:text-gray-900 transition-all duration-200 group"
            >
              <svg class="w-4 h-4 mr-2 transition-transform group-hover:-translate-x-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
              Back to projects
            </.link>

            <div class="flex items-center space-x-3">
              <div class="flex items-center justify-center w-10 h-10 bg-gradient-to-br from-red-500 to-pink-600 rounded-lg">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
              </div>

              <div>
                <h1 class="text-2xl font-bold text-gray-900"><%= @project.title %></h1>
                <div class="flex items-center space-x-2 mt-1">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                    <div class="w-1.5 h-1.5 bg-red-500 rounded-full mr-1.5"></div>
                    Live Stream
                  </span>
                  <span class="text-sm text-gray-500">•</span>
                  <span class="text-sm text-gray-500 capitalize"><%= @project.status %></span>
                </div>
              </div>
            </div>
          </div>

          <div class="flex items-center space-x-3">
            <%= if @editing do %>
              <.link
                navigate={~p"/#{@project.id}"}
                class="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-600 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </.link>
            <% else %>
              <.link
                navigate={~p"/#{@project.id}?edit=true"}
                class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 transition-colors"
              >
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                </svg>
                Edit Project
              </.link>
            <% end %>
          </div>
        </div>
      </div>
    </div>

    <!-- Main Content -->
    <div class="container mx-auto px-4 py-8">
      <%= case @project.type do %>
        <% "film" -> %>
          <.live_component
            module={FilmSetupComponent}
            id="film-setup"
            project={@project}
            editing={@editing}
          />
        <% "live_event" -> %>
          <.live_component
            module={LiveStreamSetupComponent}
            id="live-stream-setup"
            project={@project}
            editing={@editing}
          />
        <% _ -> %>
          <div class="bg-white shadow rounded-lg p-6">
            <div class="text-center py-8">
              <div class="mx-auto h-16 w-16 text-gray-400 mb-4">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" class="w-full h-full">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <h3 class="text-lg font-medium text-gray-900 mb-2">Project Type Not Supported</h3>
              <p class="text-gray-600">This project type (<%= @project.type %>) is not yet supported in the interface.</p>
            </div>
          </div>
      <% end %>
    </div>
    """
  end
end
