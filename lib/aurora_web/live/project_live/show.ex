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
     |> assign(:trailer_upload_url, nil)
     |> assign(:trailer_upload_id, nil)
     |> assign(:film_upload_url, nil)
     |> assign(:film_upload_id, nil)
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

  @impl true
  def handle_event("init_trailer_upload", _, socket) do
    Logger.warning("INIT_TRAILER_UPLOAD: Project ID: #{socket.assigns.project.id}")
    client = Mux.client()
    params = %{
      "new_asset_settings" => %{
        "playback_policies" => ["signed"]
      },
      "cors_origin" => "http://studio.aurora.com:4000",
      "passthrough" => "type:trailer;project_id:#{socket.assigns.project.id}"
    }

    # if trailer upload url is already set, then delete the existing upload before creating a new one
    # if socket.assigns.project.trailer_upload_id do
    #   case Mux.Video.Assets.delete(client, socket.assigns.project.trailer_asset_id) do
    #     {:ok, _} ->
    #       Logger.warning("Previous trailer upload deleted successfully")
    #     {:error, error} ->
    #       Logger.error("Failed to delete trailer upload: #{inspect(error)}")
    #       {:noreply, put_flash(socket, :error, "Failed to delete previous trailer upload")}
    #   end
    # end

    case Mux.Video.Uploads.create(client, params) do
      {:ok, %{"url" => url, "id" => id}, _env} ->
        IO.puts("Mux Upload URL: #{url}")
        IO.puts("Upload ID: #{id}")

        # Update the project with the upload URL and ID
        case Projects.update_project(socket.assigns.project, %{
          "trailer_upload_id" => id
        }) do
          {:ok, updated_project} ->
            {:noreply,
             socket
             |> assign(:project, updated_project)
             |> assign(:trailer_upload_url, url)
             |> assign(:trailer_upload_id, id)
             |> put_flash(:info, "Upload URL generated")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to save upload URL")}
        end

      error ->
        IO.inspect(error, label: "Upload creation failed")
        {:noreply, put_flash(socket, :error, "Failed to generate upload URL")}
    end
  end

  @impl true
  def handle_event("init_film_upload", _, socket) do
    Logger.warning("INIT_FILM_UPLOAD: Project ID: #{socket.assigns.project.id}")
    client = Mux.client()
    params = %{
      "new_asset_settings" => %{
        "playback_policies" => ["signed"]
      },
      "cors_origin" => "http://studio.aurora.com:4000",
      "passthrough" => "type:film;project_id:#{socket.assigns.project.id}"
    }

    # if film upload url is already set, then delete the existing upload before creating a new one
    # if socket.assigns.project.film_upload_id do
    #   case Mux.Video.Assets.delete(client, socket.assigns.project.film_asset_id) do
    #     {:ok, _} ->
    #       Logger.warning("Previous film upload deleted successfully")
    #     {:error, error} ->
    #       Logger.error("Failed to delete film upload: #{inspect(error)}")
    #       {:noreply, put_flash(socket, :error, "Failed to delete previous film upload")}
    #   end
    # end

    case Mux.Video.Uploads.create(client, params) do
      {:ok, %{"url" => url, "id" => id}, _env} ->
        IO.puts("Mux Upload URL: #{url}")
        IO.puts("Upload ID: #{id}")

        # Update the project with the upload URL and ID
        case Projects.update_project(socket.assigns.project, %{
          "film_upload_id" => id
        }) do
          {:ok, updated_project} ->
        {:noreply,
          socket
             |> assign(:project, updated_project)
             |> assign(:film_upload_url, url)
             |> assign(:film_upload_id, id)
          |> put_flash(:info, "Upload URL generated")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to save upload URL")}
        end

        error ->
          IO.inspect(error, label: "Upload creation failed")
          {:noreply, put_flash(socket, :error, "Failed to generate upload URL")}
    end
  end

  @impl true
  def handle_event("deploy", _, socket) do
    project = socket.assigns.project

    case Projects.add_to_approval_queue(project) do
      {:ok, _queue_entry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project submitted for approval")
         |> assign(:project, project)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Project is already in the approval queue")}
    end
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
            <h2 class="text-xl font-semibold mb-4 flex items-center">
              Trailer
              <%= if @project.trailer_upload_id && @project.trailer_upload_id != "" do %>
                <svg class="ml-2 h-5 w-5 text-green-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd" />
                </svg>
              <% end %>
            </h2>
            <div class="mt-4">
                <script src="https://cdn.jsdelivr.net/npm/@mux/mux-uploader"></script>
              <%= if @trailer_upload_url do %>
                <div id="mux-trailer-upload-container" phx-update="ignore">
                  <style>
                    .btn {
                      padding: 6px 8px;
                      border: 1px solid #0d9488;
                      border-radius: 5px;
                      font-size: 16px;
                      color: white;
                      background: black;
                      cursor: pointer;
                    }
                  </style>
                  <mux-uploader endpoint={@trailer_upload_url}>
                    <button type="button" class="btn" slot="file-select">Pick a file</button>
                  </mux-uploader>
                </div>
              <% end %>

              <%= if @project.trailer_upload_id && @project.trailer_upload_id != "" do %>
                <div class="mb-4 rounded-md bg-yellow-50 p-4">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M8.485 3.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 3.495zM10 6a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 6zm0 9a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <h3 class="text-sm font-medium text-yellow-800">Existing Trailer</h3>
                      <div class="mt-2 text-sm text-yellow-700">
                        <p>Uploading a new trailer will replace the existing one.</p>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Always show button to generate upload URL -->
              <button
                type="button"
                phx-click="init_trailer_upload"
                class="inline-flex items-center mt-4 px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <svg class="mr-2 -ml-1 h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                </svg>
                <%= if @project.trailer_upload_id && @project.trailer_upload_id != "" do %>
                  Replace Trailer
                <% else %>
                Upload Trailer
                <% end %>
              </button>
            </div>
          </div>

          <div class="bg-white rounded-lg shadow-sm p-6">
            <h2 class="text-xl font-semibold mb-4 flex items-center">
              Film
              <%= if @project.film_upload_id && @project.film_upload_id != "" do %>
                <svg class="ml-2 h-5 w-5 text-green-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd" />
                </svg>
              <% end %>
            </h2>
            <div class="mt-4">
              <script src="https://cdn.jsdelivr.net/npm/@mux/mux-uploader"></script>
              <%= if @film_upload_url do %>
                <div id="mux-film-upload-container" phx-update="ignore">
                  <style>
                    .btn {
                      padding: 6px 8px;
                      border: 1px solid #0d9488;
                      border-radius: 5px;
                      font-size: 16px;
                      color: white;
                      background: black;
                      cursor: pointer;
                    }
                  </style>
                  <mux-uploader endpoint={@film_upload_url}>
                    <button type="button" class="btn" slot="file-select">Pick a file</button>
                  </mux-uploader>
                </div>
              <% end %>

              <%= if @project.film_upload_id && @project.film_upload_id != "" do %>
                <div class="mb-4 rounded-md bg-yellow-50 p-4">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M8.485 3.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 3.495zM10 6a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 6zm0 9a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <h3 class="text-sm font-medium text-yellow-800">Existing Film</h3>
                      <div class="mt-2 text-sm text-yellow-700">
                        <p>Uploading a new film will replace the existing one.</p>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Always show button to generate upload URL -->
              <button
                type="button"
                phx-click="init_film_upload"
                class="inline-flex items-center mt-4 px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <svg class="mr-2 -ml-1 h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                </svg>
                <%= if @project.film_upload_id && @project.film_upload_id != "" do %>
                  Replace Film
                <% else %>
                Upload Film
                <% end %>
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
                  disabled={Projects.in_approval_queue?(@project)}
                >
                  <svg class="mr-2 -ml-1 h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                  </svg>
                  <%= if Projects.in_approval_queue?(@project) do %>
                    Pending Approval
                  <% else %>
                  Deploy Project
                  <% end %>
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
