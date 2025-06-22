defmodule WindowpaneWeb.ProjectLive.Show do
  use WindowpaneWeb, :live_view
  require Logger

  alias Windowpane.Projects
  alias WindowpaneWeb.FilmSetupComponent

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    project = Projects.get_project_with_film_and_reviews!(id)
    Logger.warning("MOUNT: Setting initial editing state to false")
    Logger.warning("MOUNT: Project ID: #{id}")

    {:ok,
     socket
     |> assign(:page_title, "Project Details")
     |> assign(:project, project)
     |> assign(:editing, false)}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    project = Projects.get_project_with_film_and_reviews!(id)
    editing = Map.get(params, "edit", "false") == "true"

    Logger.warning("HANDLE_PARAMS: Params: #{inspect(params)}")
    Logger.warning("HANDLE_PARAMS: Setting editing to: #{editing}")

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
  def render(assigns) do
    ~H"""
    <.flash_group flash={@flash} />
    <div class="container mx-auto px-4 py-8">
      <div class="flex items-center gap-4 mb-8">
        <.link
          navigate={~p"/dashboard"}
          class="text-gray-600 hover:text-gray-900"
        >
          ← Back to projects
        </.link>
        <h1 class="text-3xl font-bold"><%= @project.title %></h1>
      </div>

      <.live_component
        module={FilmSetupComponent}
        id="film-setup"
        project={@project}
        editing={@editing}
      />
    </div>
    """
  end
end
