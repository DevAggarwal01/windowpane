defmodule AuroraWeb.ProjectLive.Show do
  use AuroraWeb, :live_view
  require Logger

  alias Aurora.Projects

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    project = Projects.get_project!(id)
    Logger.warning("MOUNT: Setting initial editing state to false")
    Logger.warning("MOUNT: Project ID: #{id}")

    {:ok,
     socket
     |> assign(:page_title, "Project Details")
     |> assign(:project, project)
     |> assign(:editing, false)
     |> assign(:changeset, Projects.change_project(project))}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    project = Projects.get_project!(id)
    editing = Map.get(params, "edit", "false") == "true"

    Logger.warning("HANDLE_PARAMS: Params: #{inspect(params)}")
    Logger.warning("HANDLE_PARAMS: Setting editing to: #{editing}")

    {:noreply,
     socket
     |> assign(:project, project)
     |> assign(:editing, editing)
     |> assign(:changeset, Projects.change_project(project))}
  end

  @impl true
  def handle_event("save", %{"project" => project_params}, socket) do
    case Projects.update_project(socket.assigns.project, project_params) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project updated successfully")
         |> assign(:project, project)
         |> assign(:editing, false)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply,
     socket
     |> assign(:editing, false)
     |> assign(:changeset, Projects.change_project(socket.assigns.project))}
  end

  defp format_price(nil), do: "-"
  defp format_price(price) when is_struct(price, Decimal), do: "$#{Decimal.to_string(price)}"

  @impl true
  def render(assigns) do
    ~H"""
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

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div class="lg:col-span-2 space-y-6">
          <%= if @editing do %>
            <.form :let={f} for={@changeset} phx-submit="save">
              <div class="bg-white rounded-lg shadow-sm p-6">
                <div class="flex justify-between items-center mb-4">
                  <h2 class="text-xl font-semibold">Project Details</h2>
                  <.link
                    patch={~p"/projects/#{@project.id}"}
                    class="inline-flex items-center px-3 py-1 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    Cancel
                  </.link>
                </div>

                <div class="space-y-4">
                  <div>
                    <.input field={f[:title]} type="text" label="Title" required />
                  </div>
                  <div>
                    <.input field={f[:description]} type="textarea" label="Description" required />
                  </div>
                </div>
              </div>

              <div class="bg-white rounded-lg shadow-sm p-6">
                <h2 class="text-xl font-semibold mb-4">Pricing & Schedule</h2>
                <div class="grid grid-cols-2 gap-6">
                  <div>
                    <.input
                      field={f[:premiere_date]}
                      type="datetime-local"
                      label="Premiere Date"
                      required
                    />
                  </div>
                  <div>
                    <.input
                      field={f[:premiere_price]}
                      type="number"
                      label="Premiere Ticket Price"
                      step="0.01"
                      min="0"
                    />
                  </div>
                  <div>
                    <.input
                      field={f[:rental_price]}
                      type="number"
                      label="Rental Price"
                      step="0.01"
                      min="0"
                      required
                    />
                  </div>
                  <div>
                    <.input
                      field={f[:rental_window_hours]}
                      type="number"
                      label="Rental Window (hours)"
                      min="1"
                      required
                    />
                  </div>
                  <div>
                    <.input
                      field={f[:purchase_price]}
                      type="number"
                      label="Purchase Price"
                      step="0.01"
                      min="0"
                      required
                    />
                  </div>
                </div>

                <div class="flex justify-end mt-6">
                  <button
                    type="submit"
                    class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    Save Changes
                  </button>
                </div>
              </div>
            </.form>
          <% else %>
            <div class="bg-white rounded-lg shadow-sm p-6">
              <div class="flex justify-between items-center mb-4">
                <h2 class="text-xl font-semibold">Project Details</h2>
                <.link
                  patch={~p"/projects/#{@project.id}?edit=true"}
                  class="inline-flex items-center px-3 py-1 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Edit
                </.link>
              </div>

              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-500">Description</label>
                  <p class="mt-1 text-gray-900"><%= @project.description %></p>
                </div>
                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-500">Type</label>
                    <p class="mt-1 text-gray-900 capitalize"><%= @project.type %></p>
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-500">Status</label>
                    <p class="mt-1">
                      <%= case @project.status do %>
                        <% "draft" -> %>
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                            Draft
                          </span>
                        <% "published" -> %>
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                            Published
                          </span>
                        <% "archived" -> %>
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                            Archived
                          </span>
                      <% end %>
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <div class="bg-white rounded-lg shadow-sm p-6">
              <h2 class="text-xl font-semibold mb-4">Pricing & Schedule</h2>
              <div class="grid grid-cols-2 gap-6">
                <div>
                  <label class="block text-sm font-medium text-gray-500">Premiere Date</label>
                  <p class="mt-1 text-gray-900">
                    <%= Calendar.strftime(@project.premiere_date, "%B %d, %Y at %I:%M %p") %>
                  </p>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-500">Premiere Ticket Price</label>
                  <p class="mt-1 text-gray-900">
                    <%= format_price(@project.premiere_price) %>
                  </p>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-500">Rental Price</label>
                  <p class="mt-1 text-gray-900">
                    <%= format_price(@project.rental_price) %>
                  </p>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-500">Rental Window</label>
                  <p class="mt-1 text-gray-900"><%= @project.rental_window_hours %> hours</p>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-500">Purchase Price</label>
                  <p class="mt-1 text-gray-900">
                    <%= format_price(@project.purchase_price) %>
                  </p>
                </div>
              </div>
            </div>
          <% end %>

          <div class="bg-white rounded-lg shadow-sm p-6">
            <h2 class="text-xl font-semibold mb-4">Trailer</h2>
            <div class="aspect-w-16 aspect-h-9 bg-gray-100 rounded-lg">
              <div class="flex items-center justify-center">
                <p class="text-gray-500">Trailer will appear here</p>
              </div>
            </div>
            <div class="mt-4">
              <button class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
                <svg class="mr-2 -ml-1 h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                </svg>
                Upload Trailer
              </button>
            </div>
          </div>

          <div class="bg-white rounded-lg shadow-sm p-6">
            <h2 class="text-xl font-semibold mb-4">Film</h2>
            <div class="aspect-w-16 aspect-h-9 bg-gray-100 rounded-lg">
              <div class="flex items-center justify-center">
                <p class="text-gray-500">Film will appear here</p>
              </div>
            </div>
            <div class="mt-4">
              <button class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
                <svg class="mr-2 -ml-1 h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                </svg>
                Upload Film
              </button>
            </div>
          </div>
        </div>

        <div class="space-y-6">
          <div class="bg-white rounded-lg shadow-sm p-6">
            <h2 class="text-xl font-semibold mb-4">Actions</h2>
            <div class="space-y-4">
              <%= if @project.status == "draft" do %>
                <button
                  phx-click="deploy"
                  class="w-full inline-flex justify-center items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
                >
                  <svg class="mr-2 -ml-1 h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                  </svg>
                  Deploy Project
                </button>
              <% end %>
            </div>
          </div>

          <div class="bg-white rounded-lg shadow-sm p-6">
            <h2 class="text-xl font-semibold mb-4">Project Stats</h2>
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-500">Created</label>
                <p class="mt-1 text-gray-900">
                  <%= Calendar.strftime(@project.inserted_at, "%B %d, %Y") %>
                </p>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-500">Last Updated</label>
                <p class="mt-1 text-gray-900">
                  <%= Calendar.strftime(@project.updated_at, "%B %d, %Y") %>
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
