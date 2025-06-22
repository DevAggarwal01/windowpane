defmodule WindowpaneWeb.ProjectLive.Show do
  use WindowpaneWeb, :live_view
  require Logger

  alias Windowpane.Projects
  alias Windowpane.Uploaders.CoverUploader
  alias Windowpane.Uploaders.BannerUploader
  alias Phoenix.LiveView.JS

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    project = Projects.get_project_with_film_and_reviews!(id)
    Logger.warning("MOUNT: Setting initial editing state to false")
    Logger.warning("MOUNT: Project ID: #{id}")

    {:ok,
     socket
     |> assign(:page_title, "Project Details")
     |> assign(:project, project)
     |> assign(:editing, false)
     |> assign(:show_cover_modal, false)
     |> assign(:show_cropper_modal, false)
     |> assign(:cover_uploading, false)
     |> assign(:show_banner_modal, false)
     |> assign(:show_banner_cropper_modal, false)
     |> assign(:banner_uploading, false)
     |> assign(:trailer_upload_url, nil)
     |> assign(:trailer_upload_id, nil)
     |> assign(:film_upload_url, nil)
     |> assign(:film_upload_id, nil)
     |> assign(:changeset, Projects.change_project(project))
     |> allow_upload(:cover, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1)
     |> allow_upload(:banner, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1)}
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
     |> assign(:editing, editing)
     |> assign(:changeset, Projects.change_project(project))}
  end

  @impl true
  def handle_event("save", %{"project" => project_params}, socket) do
    case Projects.update_project(socket.assigns.project, project_params) do
      {:ok, project} ->
        updated_project = Projects.get_project_with_film_and_reviews!(project.id)
        {:noreply,
         socket
         |> put_flash(:info, "Project updated successfully")
         |> assign(:project, updated_project)
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
        "playback_policies" => ["signed"],
        "passthrough" => "type:trailer;project_id:#{socket.assigns.project.id}",
      },
      "cors_origin" => "http://studio.windowpane.tv:4000",
    }

    case Mux.Video.Uploads.create(client, params) do
      {:ok, %{"url" => url, "id" => id}, _env} ->
        IO.puts("Mux Upload URL: #{url}")
        IO.puts("Upload ID: #{id}")

        # Get or create film for this project and update it with trailer upload ID
        film = Projects.get_or_create_film(socket.assigns.project)
        case Projects.update_film(film, %{
          "trailer_upload_id" => id
        }) do
          {:ok, _updated_film} ->
            updated_project = Projects.get_project_with_film_and_reviews!(socket.assigns.project.id)
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
        "playback_policies" => ["signed"],
        "passthrough" => "type:film;project_id:#{socket.assigns.project.id}",
      },
      "cors_origin" => "http://studio.windowpane.tv:4000",
    }

    case Mux.Video.Uploads.create(client, params) do
      {:ok, %{"url" => url, "id" => id}, _env} ->
        IO.puts("Mux Upload URL: #{url}")
        IO.puts("Upload ID: #{id}")

        # Get or create film for this project and update it with film upload ID
        film = Projects.get_or_create_film(socket.assigns.project)
        case Projects.update_film(film, %{
          "film_upload_id" => id
        }) do
          {:ok, _updated_film} ->
            updated_project = Projects.get_project_with_film_and_reviews!(socket.assigns.project.id)
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

    IO.puts("=== DEPLOY DEBUG ===")
    IO.puts("Project ID: #{project.id}")
    IO.puts("Project status: #{project.status}")
    IO.puts("In approval queue: #{Projects.in_approval_queue?(project)}")
    IO.puts("Ready for deployment: #{Projects.ready_for_deployment?(project)}")

    # Check if project is ready for deployment first
    if Projects.ready_for_deployment?(project) do
      case Projects.add_to_approval_queue(project) do
        {:ok, _queue_entry} ->
          # Update project status to waiting for approval
          IO.puts("📝 Updating project status from '#{project.status}' to 'waiting for approval'")
          case Projects.update_project(project, %{status: "waiting for approval"}) do
            {:ok, updated_project} ->
              IO.puts("✅ Project status updated successfully to '#{updated_project.status}'")
              updated_project_with_film = Projects.get_project_with_film_and_reviews!(updated_project.id)
              IO.puts("🔄 Reloaded project with film, status: '#{updated_project_with_film.status}'")

              IO.puts("✅ Project added to approval queue")
              {:noreply,
               socket
               |> put_flash(:info, "Project submitted for approval")
               |> assign(:project, updated_project_with_film)}

            {:error, changeset} ->
              IO.puts("❌ Failed to update project status: #{inspect(changeset.errors)}")
              {:noreply,
               socket
               |> put_flash(:error, "Project submitted but status update failed")
               |> assign(:project, project)}
          end
        {:error, _changeset} ->
          IO.puts("❌ Project already in approval queue")
          {:noreply,
           socket
           |> put_flash(:error, "Project is already in the approval queue")}
      end
    else
      # Show simple error message
      IO.puts("❌ Project not ready for deployment")
      {:noreply,
       socket
       |> put_flash(:error, "Cannot deploy project. All fields have not been filled out. Please complete all required fields and uploads.")}
    end
  end

  @impl true
  def handle_event("trigger_file_input", _, socket) do
    Logger.warning("TRIGGER_FILE_INPUT: File input clicked")
    Logger.warning("TRIGGER_FILE_INPUT: Sending push_event to client")

    socket = push_event(socket, "trigger-file-input", %{input_id: "cover-upload"})
    Logger.warning("TRIGGER_FILE_INPUT: push_event sent")

    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_cover", _params, socket) do
    Logger.warning("UPLOAD_COVER: Project ID: #{socket.assigns.project.id}")

    uploaded_files =
      consume_uploaded_entries(socket, :cover, fn %{path: path}, entry ->
        # Upload to Wasabi using our CoverUploader - just pass the path
        case CoverUploader.store({path, socket.assigns.project}) do
          {:ok, _filename} ->
            Logger.info("Successfully uploaded cover for project #{socket.assigns.project.id}")
            {:ok, :uploaded}

          {:error, reason} ->
            Logger.error("Failed to upload cover for project #{socket.assigns.project.id}: #{inspect(reason)}")
            {:error, reason}
        end
      end)

    case uploaded_files do
      [] ->
        {:noreply, put_flash(socket, :error, "No files were uploaded")}

      files when length(files) > 0 ->
        # Check if all uploads were successful
        if Enum.all?(files, fn file -> file == :uploaded end) do
          {:noreply,
           socket
           |> put_flash(:info, "Cover image uploaded successfully!")
           |> assign(:uploaded_files, files)}
        else
          failed_uploads = Enum.filter(files, fn file -> file != :uploaded end)
          Logger.error("Some uploads failed: #{inspect(failed_uploads)}")
          {:noreply, put_flash(socket, :error, "Failed to upload some files")}
        end
    end
  end

  @impl true
  def handle_event("validate_cover", _params, socket) do
    Logger.warning("VALIDATE_COVER: Project ID: #{socket.assigns.project.id}")
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    Logger.warning("CANCEL_UPLOAD: Project ID: #{socket.assigns.project.id}")
    {:noreply, cancel_upload(socket, :cover, ref)}
  end

  @impl true
  def handle_event("open_cover_modal", _params, socket) do
    {:noreply, assign(socket, :show_cover_modal, true)}
  end

  @impl true
  def handle_event("close_cover_modal", _params, socket) do
    Logger.warning("CLOSE_COVER_MODAL: Closing cover modal")
    {:noreply, assign(socket, :show_cover_modal, false)}
  end

  @impl true
  def handle_event("show_cropper_modal", _params, socket) do
    {:noreply, assign(socket, :show_cropper_modal, true)}
  end

  @impl true
  def handle_event("hide_cropper_modal", _params, socket) do
    {:noreply, assign(socket, :show_cropper_modal, false)}
  end

  @impl true
  def handle_event("set_uploading", %{"uploading" => uploading}, socket) do
    {:noreply, assign(socket, :cover_uploading, uploading)}
  end

  @impl true
  def handle_event("upload_success", _params, socket) do
    updated_project = Projects.get_project_with_film_and_reviews!(socket.assigns.project.id)
    {:noreply,
     socket
     |> assign(:project, updated_project)
     |> assign(:show_cropper_modal, false)
     |> assign(:cover_uploading, false)
     |> put_flash(:info, "Cover image uploaded successfully!")}
  end

  @impl true
  def handle_event("upload_error", %{"error" => error}, socket) do
    {:noreply,
     socket
     |> assign(:cover_uploading, false)
     |> put_flash(:error, "Upload failed: #{error}")}
  end

  @impl true
  def handle_event("trigger_banner_file_input", _, socket) do
    Logger.warning("TRIGGER_BANNER_FILE_INPUT: File input clicked")
    Logger.warning("TRIGGER_BANNER_FILE_INPUT: Sending push_event to client")

    socket = push_event(socket, "trigger-banner-file-input", %{input_id: "banner-upload"})
    Logger.warning("TRIGGER_BANNER_FILE_INPUT: push_event sent")

    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_banner", _params, socket) do
    Logger.warning("UPLOAD_BANNER: Project ID: #{socket.assigns.project.id}")

    uploaded_files =
      consume_uploaded_entries(socket, :banner, fn %{path: path}, entry ->
        # Upload to Wasabi using our BannerUploader - just pass the path
        case BannerUploader.store({path, socket.assigns.project}) do
          {:ok, _filename} ->
            Logger.info("Successfully uploaded banner for project #{socket.assigns.project.id}")
            {:ok, :uploaded}

          {:error, reason} ->
            Logger.error("Failed to upload banner for project #{socket.assigns.project.id}: #{inspect(reason)}")
            {:error, reason}
        end
      end)

    case uploaded_files do
      [] ->
        {:noreply, put_flash(socket, :error, "No files were uploaded")}

      files when length(files) > 0 ->
        # Check if all uploads were successful
        if Enum.all?(files, fn file -> file == :uploaded end) do
          {:noreply,
           socket
           |> put_flash(:info, "Banner image uploaded successfully!")
           |> assign(:uploaded_files, files)}
        else
          failed_uploads = Enum.filter(files, fn file -> file != :uploaded end)
          Logger.error("Some uploads failed: #{inspect(failed_uploads)}")
          {:noreply, put_flash(socket, :error, "Failed to upload some files")}
        end
    end
  end

  @impl true
  def handle_event("validate_banner", _params, socket) do
    Logger.warning("VALIDATE_BANNER: Project ID: #{socket.assigns.project.id}")
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_banner_upload", %{"ref" => ref}, socket) do
    Logger.warning("CANCEL_BANNER_UPLOAD: Project ID: #{socket.assigns.project.id}")
    {:noreply, cancel_upload(socket, :banner, ref)}
  end

  @impl true
  def handle_event("open_banner_modal", _params, socket) do
    {:noreply, assign(socket, :show_banner_modal, true)}
  end

  @impl true
  def handle_event("close_banner_modal", _params, socket) do
    Logger.warning("CLOSE_BANNER_MODAL: Closing banner modal")
    {:noreply, assign(socket, :show_banner_modal, false)}
  end

  @impl true
  def handle_event("show_banner_cropper_modal", _params, socket) do
    {:noreply, assign(socket, :show_banner_cropper_modal, true)}
  end

  @impl true
  def handle_event("hide_banner_cropper_modal", _params, socket) do
    {:noreply, assign(socket, :show_banner_cropper_modal, false)}
  end

  @impl true
  def handle_event("set_banner_uploading", %{"uploading" => uploading}, socket) do
    {:noreply, assign(socket, :banner_uploading, uploading)}
  end

  @impl true
  def handle_event("banner_upload_success", _params, socket) do
    updated_project = Projects.get_project_with_film_and_reviews!(socket.assigns.project.id)
    {:noreply,
     socket
     |> assign(:project, updated_project)
     |> assign(:show_banner_cropper_modal, false)
     |> assign(:banner_uploading, false)
     |> put_flash(:info, "Banner image uploaded successfully!")}
  end

  @impl true
  def handle_event("banner_upload_error", %{"error" => error}, socket) do
    {:noreply,
     socket
     |> assign(:banner_uploading, false)
     |> put_flash(:error, "Banner upload failed: #{error}")}
  end

  defp format_price(nil), do: "-"
  defp format_price(price) when is_struct(price, Decimal), do: "$#{Decimal.to_string(price)}"

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

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div class="lg:col-span-2 space-y-6">
          <%= if @editing do %>
            <div class="bg-white rounded-lg shadow-sm p-6">
              <h2 class="text-xl font-semibold mb-4">Edit Project</h2>
              <.form
                :let={f}
                for={@changeset}
                phx-submit="save"
                class="space-y-4"
              >
                <div>
                  <.input field={f[:title]} type="text" label="Title" />
                </div>

                <div>
                  <.input field={f[:description]} type="textarea" label="Description" />
                </div>

                <div>
                  <.input
                    field={f[:type]}
                    type="select"
                    label="Type"
                    options={[
                      {"Film", "film"},
                      {"TV Show", "tv_show"},
                      {"Live Event", "live_event"},
                      {"Book", "book"},
                      {"Music", "music"}
                    ]}
                  />
                </div>

                <div>
                  <.input field={f[:premiere_date]} type="datetime-local" label="Premiere Date" />
                </div>

                <div>
                  <.input field={f[:premiere_price]} type="number" label="Premiere Price" step="0.01" />
                </div>

                <div>
                  <.input field={f[:rental_price]} type="number" label="Rental Price" step="0.01" />
                </div>

                <div>
                  <.input field={f[:rental_window_hours]} type="number" label="Rental Window (hours)" />
                </div>

                <div class="flex gap-4">
                  <.button type="submit">Save Changes</.button>
                  <.button type="button" phx-click="cancel_edit" class="bg-gray-500 hover:bg-gray-600">
                    Cancel
                  </.button>
                </div>
              </.form>
            </div>
          <% else %>
            <div class="bg-white rounded-lg shadow-sm p-6">
              <div class="flex justify-between items-center mb-4">
                <h2 class="text-xl font-semibold">Project Details</h2>
                <.link
                  patch={~p"/#{@project}?edit=true"}
                  class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  <svg class="mr-2 -ml-0.5 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                  </svg>
                  Edit
                </.link>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label class="block text-sm font-medium text-gray-500">Description</label>
                  <p class="mt-1 text-gray-900"><%= @project.description %></p>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-500">Type</label>
                  <p class="mt-1 text-gray-900 capitalize"><%= String.replace(@project.type, "_", " ") %></p>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-500">Premiere Date</label>
                  <p class="mt-1 text-gray-900">
                    <%= if @project.premiere_date do %>
                      <%= Calendar.strftime(@project.premiere_date, "%B %d, %Y at %I:%M %p") %>
                    <% else %>
                      Not set
                    <% end %>
                  </p>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-500">Premiere Price</label>
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
              </div>
            </div>
          <% end %>

          <div class="bg-white rounded-lg shadow-sm p-6">
            <h2 class="text-xl font-semibold mb-4 flex items-center">
              Trailer
              <%= if @project.film && @project.film.trailer_asset_id && @project.film.trailer_asset_id != "" && @project.film.trailer_playback_id && @project.film.trailer_playback_id != "" do %>
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

              <!-- Always show button to generate upload URL -->
              <button
                type="button"
                phx-click="init_trailer_upload"
                class="inline-flex items-center mt-4 px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <svg class="mr-2 -ml-1 h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                </svg>
                <%= if @project.film && @project.film.trailer_asset_id && @project.film.trailer_asset_id != "" && @project.film.trailer_playback_id && @project.film.trailer_playback_id != "" do %>
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
              <%= if @project.film && @project.film.film_asset_id && @project.film.film_asset_id != "" && @project.film.film_playback_id && @project.film.film_playback_id != "" do %>
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

              <!-- Always show button to generate upload URL -->
              <button
                type="button"
                phx-click="init_film_upload"
                class="inline-flex items-center mt-4 px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <svg class="mr-2 -ml-1 h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                </svg>
                <%= if @project.film && @project.film.film_asset_id && @project.film.film_asset_id != "" && @project.film.film_playback_id && @project.film.film_playback_id != "" do %>
                  Replace Film
                <% else %>
                Upload Film
                <% end %>
              </button>
            </div>
          </div>

          <div class="bg-white rounded-lg shadow-sm p-6">
            <h2 class="text-xl font-semibold mb-4 flex items-center">
              Film Cover
              <%= if CoverUploader.cover_exists?(@project) do %>
                <svg class="ml-2 h-5 w-5 text-green-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd" />
                </svg>
              <% end %>
            </h2>

            <div class="mt-4" id="image-cropper-hook" phx-hook="ImageCropper" data-project-id={@project.id}>
              <!-- Include Cropper.js CDN -->
              <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.6.1/cropper.min.css">
              <script src="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.6.1/cropper.min.js"></script>

              <div class="flex gap-2">
                <button
                  type="button"
                  onclick="document.getElementById('cover-file-input').click()"
                  class={[
                    "inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500",
                    @cover_uploading && "opacity-50 cursor-not-allowed"
                  ]}
                  disabled={@cover_uploading}
                >
                  <%= if @cover_uploading do %>
                    <svg class="animate-spin -ml-1 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                      <path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    Uploading...
                  <% else %>
                    <svg class="mr-2 -ml-1 h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                    </svg>
                    <%= if CoverUploader.cover_exists?(@project) do %>
                      Replace Cover
                    <% else %>
                      Upload Cover
                    <% end %>
                  <% end %>
                </button>

                <%= if CoverUploader.cover_exists?(@project) do %>
                  <button
                    type="button"
                    phx-click="open_cover_modal"
                    class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    <svg class="mr-2 -ml-1 h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                    </svg>
                    View Image
                  </button>
                <% end %>
              </div>

              <input
                type="file"
                id="cover-file-input"
                accept=".jpg,.jpeg,.png,.webp"
                style="display: none;"
              />
            </div>
          </div>

          <div class="bg-white rounded-lg shadow-sm p-6">
            <h2 class="text-xl font-semibold mb-4 flex items-center">
              Film Banner
              <%= if BannerUploader.banner_exists?(@project) do %>
                <svg class="ml-2 h-5 w-5 text-green-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd" />
                </svg>
              <% end %>
            </h2>

            <div class="mt-4" id="banner-cropper-hook" phx-hook="BannerCropper" data-project-id={@project.id}>
              <!-- Include Cropper.js CDN -->
              <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.6.1/cropper.min.css">
              <script src="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.6.1/cropper.min.js"></script>

              <div class="flex gap-2">
                <button
                  type="button"
                  onclick="document.getElementById('banner-file-input').click()"
                  class={[
                    "inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500",
                    @banner_uploading && "opacity-50 cursor-not-allowed"
                  ]}
                  disabled={@banner_uploading}
                >
                  <%= if @banner_uploading do %>
                    <svg class="animate-spin -ml-1 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                      <path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    Uploading...
                  <% else %>
                    <svg class="mr-2 -ml-1 h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                    </svg>
                    <%= if BannerUploader.banner_exists?(@project) do %>
                      Replace Banner
                    <% else %>
                      Upload Banner
                    <% end %>
                  <% end %>
                </button>

                <%= if BannerUploader.banner_exists?(@project) do %>
                  <button
                    type="button"
                    phx-click="open_banner_modal"
                    class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    <svg class="mr-2 -ml-1 h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                    </svg>
                    View Image
                  </button>
                <% end %>
              </div>

              <input
                type="file"
                id="banner-file-input"
                accept=".jpg,.jpeg,.png,.webp"
                style="display: none;"
              />
            </div>
          </div>
        </div>

        <div class="space-y-6">
          <div class="bg-white rounded-lg shadow-sm p-6">
            <h2 class="text-xl font-semibold mb-4">Actions</h2>
            <div class="space-y-4">
              <%= if @project.status == "draft" or @project.status == "waiting for approval" do %>
                <button
                  phx-click="deploy"
                  class="w-full inline-flex justify-center items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 disabled:bg-gray-400 disabled:cursor-not-allowed"
                  disabled={@project.status == "waiting for approval" or Projects.in_approval_queue?(@project)}
                >
                  <svg class="mr-2 -ml-1 h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                  </svg>
                  <%= cond do %>
                    <% @project.status == "waiting for approval" -> %>
                      Pending Approval
                    <% Projects.in_approval_queue?(@project) -> %>
                      Pending Approval
                    <% true -> %>
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
                <label class="block text-sm font-medium text-gray-500">Status</label>
                <p class="mt-1 text-gray-900 capitalize">
                  <%= String.replace(@project.status, "_", " ") %>
                </p>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-500">Created</label>
                <p class="mt-1 text-gray-900">
                  <%= Calendar.strftime(@project.inserted_at, "%B %d, %Y") %>
                </p>
              </div>
            </div>
          </div>

          <!-- Feedback Section -->
          <%= if @project.reviews && length(@project.reviews) > 0 do %>
            <div class="bg-white rounded-lg shadow-sm p-6">
              <h2 class="text-xl font-semibold mb-4">Feedback</h2>
              <div class="space-y-4">
                <%= for review <- @project.reviews do %>
                  <div class={["border-l-4 pl-4", if(review.status == "approved", do: "border-green-500", else: "border-red-500")]}>
                    <div class="flex items-center justify-between mb-2">
                      <span class={["inline-flex items-center rounded-md px-2 py-1 text-xs font-medium", if(review.status == "approved", do: "bg-green-50 text-green-700", else: "bg-red-50 text-red-700")]}>
                        <%= String.capitalize(review.status) %>
                      </span>
                      <span class="text-sm text-gray-500">
                        <%= Calendar.strftime(review.inserted_at, "%B %d, %Y at %I:%M %p") %>
                      </span>
                    </div>
                    <%= if review.feedback do %>
                      <p class="text-sm text-gray-700"><%= review.feedback %></p>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Cover Image Modal -->
    <.modal :if={@show_cover_modal} id="cover-image-modal" show on_cancel={JS.push("close_cover_modal")}>
      <div class="text-center">
        <div class="mb-4">
          <h3 class="text-lg font-medium text-gray-900">Cover Image</h3>
        </div>
        <div class="flex justify-center">
          <img
            src={CoverUploader.cover_url(@project)}
            alt="Cover Image"
            class="max-w-full max-h-96 object-contain rounded-lg shadow-lg"
          />
        </div>
      </div>
    </.modal>

    <!-- Cropper Modal -->
    <.modal :if={@show_cropper_modal} id="cropper-modal" show on_cancel={JS.push("hide_cropper_modal")}>
      <div class="text-center">
        <div class="mb-4">
          <h3 class="text-lg font-medium text-gray-900">Crop Cover Image</h3>
          <p class="text-sm text-gray-500 mt-1">Adjust the crop area to fit your cover image (2:3 aspect ratio)</p>
        </div>

        <div class="cropper-container mb-6" style="max-height: 500px;">
          <img
            id="cropper-image"
            src=""
            alt="Image to crop"
            style="max-width: 100%; display: block;"
          />
        </div>

        <div class="flex justify-center gap-3">
          <button
            type="button"
            onclick="document.dispatchEvent(new CustomEvent('cropper:close'))"
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            Cancel
          </button>
          <button
            type="button"
            onclick="document.dispatchEvent(new CustomEvent('cropper:crop-and-upload'))"
            class={[
              "px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500",
              @cover_uploading && "opacity-50 cursor-not-allowed"
            ]}
            disabled={@cover_uploading}
          >
            <%= if @cover_uploading do %>
              <svg class="animate-spin -ml-1 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Uploading...
            <% else %>
              Crop & Upload
            <% end %>
          </button>
        </div>
      </div>
    </.modal>

    <!-- Banner Image Modal -->
    <.modal :if={@show_banner_modal} id="banner-image-modal" show on_cancel={JS.push("close_banner_modal")}>
      <div class="text-center">
        <div class="mb-4">
          <h3 class="text-lg font-medium text-gray-900">Banner Image</h3>
        </div>
        <div class="flex justify-center">
          <img
            src={BannerUploader.banner_url(@project)}
            alt="Banner Image"
            class="max-w-full max-h-96 object-contain rounded-lg shadow-lg"
          />
        </div>
      </div>
    </.modal>

    <!-- Banner Cropper Modal -->
    <.modal :if={@show_banner_cropper_modal} id="banner-cropper-modal" show on_cancel={JS.push("hide_banner_cropper_modal")}>
      <div class="text-center">
        <div class="mb-4">
          <h3 class="text-lg font-medium text-gray-900">Crop Banner Image</h3>
          <p class="text-sm text-gray-500 mt-1">Adjust the crop area to fit your banner image (16:9 aspect ratio)</p>
        </div>

        <div class="cropper-container mb-6" style="max-height: 500px;">
          <img
            id="banner-cropper-image"
            src=""
            alt="Banner image to crop"
            style="max-width: 100%; display: block;"
          />
        </div>

        <div class="flex justify-center gap-3">
          <button
            type="button"
            onclick="document.dispatchEvent(new CustomEvent('banner-cropper:close'))"
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            Cancel
          </button>
          <button
            type="button"
            onclick="document.dispatchEvent(new CustomEvent('banner-cropper:crop-and-upload'))"
            class={[
              "px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500",
              @banner_uploading && "opacity-50 cursor-not-allowed"
            ]}
            disabled={@banner_uploading}
          >
            <%= if @banner_uploading do %>
              <svg class="animate-spin -ml-1 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Uploading...
            <% else %>
              Crop & Upload
            <% end %>
          </button>
        </div>
      </div>
    </.modal>
    """
  end
end
