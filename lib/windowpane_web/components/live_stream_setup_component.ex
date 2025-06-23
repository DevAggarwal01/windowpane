defmodule WindowpaneWeb.LiveStreamSetupComponent do
  use WindowpaneWeb, :live_component
  require Logger

  alias Windowpane.Projects
  alias Windowpane.Uploaders.CoverUploader
  alias Windowpane.Uploaders.BannerUploader
  alias Phoenix.LiveView.JS

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:show_cover_modal, false)
     |> assign(:show_cropper_modal, false)
     |> assign(:cover_uploading, false)
     |> assign(:show_banner_modal, false)
     |> assign(:show_banner_cropper_modal, false)
     |> assign(:banner_uploading, false)
     |> assign(:active_tab, "ui_setup")
     |> assign(:cover_updated_at, System.system_time(:second))}
  end

  @impl true
  def update(%{project: project, editing: editing} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, Projects.change_project(project))
     |> allow_upload(:cover, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1)
     |> allow_upload(:banner, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1)}
  end

  @impl true
  def handle_event("save", %{"project" => project_params}, socket) do
    Logger.warning("SAVE: Live Stream Project ID: #{socket.assigns.project.id}, Params: #{inspect(project_params)}")
    case Projects.update_project(socket.assigns.project, project_params) do
      {:ok, project} ->
        updated_project = Projects.get_project_with_live_stream_and_reviews!(project.id)
        send(self(), {:project_updated, updated_project, false})
        Logger.warning("SAVE: Live Stream Project updated successfully")
        {:noreply,
         socket
         |> put_flash(:info, "Live stream project updated successfully")
         |> assign(:project, updated_project)}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warning("SAVE: Live Stream Project update failed: #{inspect(changeset.errors)}")
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("create_live_stream", _, socket) do
    Logger.warning("CREATE_LIVE_STREAM: Project ID: #{socket.assigns.project.id}")

    client = Mux.client()
    params = %{
      "playback_policy" => ["signed"],
      "passthrough" => "type:live_stream;project_id:#{socket.assigns.project.id}",
      "new_asset_settings" => %{
        "playback_policies" => ["signed"],
        "passthrough" => "type:recording;project_id:#{socket.assigns.project.id}"
      }
    }

    case Mux.Video.LiveStreams.create(client, params) do
      {:ok, live_stream, _env} ->
        Logger.info("Created Mux live stream: #{inspect(live_stream)}")

        # Create live stream record in database
        live_stream_params = %{
          "mux_stream_id" => live_stream["id"],
          "stream_key" => live_stream["stream_key"],
          "playback_id" => live_stream["playback_ids"] |> List.first() |> Map.get("id"),
          "status" => "idle",
          "project_id" => socket.assigns.project.id
        }

        case Projects.create_live_stream(live_stream_params) do
          {:ok, _live_stream_record} ->
            updated_project = Projects.get_project_with_live_stream_and_reviews!(socket.assigns.project.id)
            {:noreply,
             socket
             |> assign(:project, updated_project)
             |> put_flash(:info, "Live stream created successfully!")}

          {:error, changeset} ->
            Logger.error("Failed to create live stream record: #{inspect(changeset.errors)}")
            {:noreply, put_flash(socket, :error, "Failed to save live stream. Please try again.")}
        end

      {:error, error} ->
        Logger.error("Failed to create Mux live stream: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, "Failed to create live stream. Please try again.")}
    end
  end

  @impl true
  def handle_event("start_stream", _, socket) do
    # TODO: Implement stream start functionality
    {:noreply, put_flash(socket, :info, "Stream starting functionality coming soon!")}
  end

  @impl true
  def handle_event("stop_stream", _, socket) do
    # TODO: Implement stream stop functionality
    {:noreply, put_flash(socket, :info, "Stream stopping functionality coming soon!")}
  end

  # Cover upload event handlers (similar to FilmSetupComponent)
  @impl true
  def handle_event("show_cover_modal", _params, socket) do
    {:noreply, assign(socket, :show_cover_modal, true)}
  end

  @impl true
  def handle_event("hide_cover_modal", _params, socket) do
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
    updated_project = Projects.get_project_with_live_stream_and_reviews!(socket.assigns.project.id)
    {:noreply,
     socket
     |> assign(:project, updated_project)
     |> assign(:show_cropper_modal, false)
     |> assign(:cover_uploading, false)
     |> assign(:cover_updated_at, System.system_time(:second))
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
  def handle_event("show_film_modal", _params, socket) do
    require Logger
    Logger.info("show_film_modal event received!")
    # Send message to parent to show FilmModalComponent with edit=true
    send(self(), {:show_film_modal, socket.assigns.project, %{edit: true}})
    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    require Logger
    Logger.info("switch_tab event received with tab: #{tab}")
    {:noreply, assign(socket, :active_tab, tab)}
  end

  # Banner upload event handlers (similar to FilmSetupComponent)
  @impl true
  def handle_event("show_banner_modal", _params, socket) do
    {:noreply, assign(socket, :show_banner_modal, true)}
  end

  @impl true
  def handle_event("hide_banner_modal", _params, socket) do
    {:noreply, assign(socket, :show_banner_modal, false)}
  end

  @impl true
  def handle_event("upload_banner", _params, socket) do
    consume_uploaded_entries(socket, :banner, fn %{path: path}, entry ->
      case BannerUploader.store({path, socket.assigns.project}) do
        {:ok, _filename} ->
          {:ok, entry}
        {:error, _reason} ->
          {:error, "Failed to upload banner"}
      end
    end)

    updated_project = Projects.get_project_with_live_stream_and_reviews!(socket.assigns.project.id)

    {:noreply,
     socket
     |> assign(:project, updated_project)
     |> assign(:show_banner_modal, false)
     |> put_flash(:info, "Banner updated successfully")}
  end

  # Helper function to generate cache-busting cover URL
  defp cover_url_with_cache_bust(project, cover_updated_at) do
    alias Windowpane.Uploaders.CoverUploader
    base_url = CoverUploader.cover_url(project)
    "#{base_url}?t=#{cover_updated_at}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <!-- Cover Upload Modal -->
      <%= if @show_cover_modal do %>
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-50">
          <div class="fixed inset-0 z-50 overflow-y-auto">
            <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
              <div class="relative transform overflow-hidden rounded-lg bg-white px-4 pb-4 pt-5 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg sm:p-6">
                <div class="absolute right-0 top-0 pr-4 pt-4">
                  <button
                    phx-click="hide_cover_modal"
                    phx-target={@myself}
                    type="button"
                    class="rounded-md bg-white text-gray-400 hover:text-gray-500 focus:outline-none"
                  >
                    <span class="sr-only">Close</span>
                    <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
                <div class="mt-3 text-center sm:mt-5">
                  <h3 class="text-lg font-semibold leading-6 text-gray-900">Upload Cover Image</h3>
                  <div class="mt-4">
                    <form phx-submit="upload_cover" phx-target={@myself} phx-change="validate_cover" class="space-y-4">
                      <div class="flex justify-center">
                        <!-- Container for cover and edit button -->
                        <div class="relative flex flex-col items-center">
                          <!-- Film Cover Placeholder with Dashed Border -->
                          <div
                            class="w-64 h-96 border-2 border-dashed border-gray-300 rounded-lg flex flex-col items-center justify-center bg-gray-50 hover:border-gray-400 hover:bg-gray-100 transition-colors cursor-pointer"
                            phx-click="show_film_modal"
                            phx-target={@myself}
                          >
                            <!-- Include Cropper.js CDN -->
                            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.6.1/cropper.min.css">
                            <script src="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.6.1/cropper.min.js"></script>

                            <%= if Windowpane.Uploaders.CoverUploader.cover_exists?(@project) do %>
                              <!-- Show uploaded cover image -->
                              <img
                                src={cover_url_with_cache_bust(@project, @cover_updated_at)}
                                alt={"Cover for #{@project.title}"}
                                class="w-full h-full object-cover rounded-lg"
                              />
                            <% else %>
                              <!-- Show placeholder when no cover exists -->
                              <div class="text-center">
                                <svg class="mx-auto h-16 w-16 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                                </svg>
                                <span class="text-xs text-gray-500">JPG, PNG, WEBP accepted</span>
                              </div>
                            <% end %>
                          </div>

                          <!-- Pencil Edit Icon (positioned absolutely over the cover but outside its div) -->
                          <button
                            type="button"
                            class="absolute top-0 right-0 -mt-2 -mr-2 w-8 h-8 bg-white rounded-full shadow-md flex items-center justify-center border border-gray-200 hover:bg-gray-50 cursor-pointer z-10"
                            onclick="document.getElementById('cover-file-input').click();"
                          >
                            <svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                            </svg>
                          </button>

                          <!-- Hidden file input (outside the clickable area) -->
                          <input
                            type="file"
                            id="cover-file-input"
                            accept=".jpg,.jpeg,.png,.webp"
                            style="display: none;"
                            id="image-cropper-hook"
                            phx-hook="ImageCropper"
                            data-project-id={@project.id}
                            phx-target={@myself}
                          />
                        </div>
                      </div>

                      <div class="mt-5 sm:mt-6 sm:grid sm:grid-flow-row-dense sm:grid-cols-2 sm:gap-3">
                        <button
                          type="submit"
                          class="inline-flex w-full justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 sm:col-start-2"
                        >
                          Upload
                        </button>
                        <button
                          type="button"
                          phx-click="hide_cover_modal"
                          phx-target={@myself}
                          class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:col-start-1 sm:mt-0"
                        >
                          Cancel
                        </button>
                      </div>
                    </form>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Cropper Modal -->
      <%= if @show_cropper_modal do %>
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-50">
          <div class="fixed inset-0 z-50 overflow-y-auto">
            <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
              <div class="relative transform overflow-hidden rounded-lg bg-white px-4 pb-4 pt-5 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-4xl sm:p-6">
                <div class="absolute right-0 top-0 pr-4 pt-4">
                  <button
                    phx-click="hide_cropper_modal"
                    phx-target={@myself}
                    type="button"
                    class="rounded-md bg-white text-gray-400 hover:text-gray-500 focus:outline-none"
                  >
                    <span class="sr-only">Close</span>
                    <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
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
              </div>
            </div>
          </div>
        </div>

      <% end %>

      <!-- Tab Navigation -->
      <div class="bg-white shadow rounded-lg mb-8">
        <div class="border-b border-gray-200">
          <nav class="-mb-px flex">
            <button
              phx-click="switch_tab"
              phx-value-tab="ui_setup"
              phx-target={@myself}
              class={[
                "py-4 px-6 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "ui_setup",
                  do: "border-blue-500 text-blue-600 bg-blue-50",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              UI Setup
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="live_stream_setup"
              phx-target={@myself}
              class={[
                "py-4 px-6 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "live_stream_setup",
                  do: "border-blue-500 text-blue-600 bg-blue-50",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              Live Stream Setup
            </button>
          </nav>
        </div>
      </div>

      <!-- Tab Content -->
      <%= if @active_tab == "ui_setup" do %>
        <!-- Cover Image Section -->
        <div class="bg-white shadow rounded-lg p-6 mt-8">
          <h3 class="text-xl font-bold mb-4">User Interface Setup</h3>

          <div class="flex justify-center">
            <!-- Container for cover and edit button -->
            <div class="relative flex flex-col items-center">
              <!-- Film Cover Placeholder with Dashed Border -->
              <div
                class="w-64 h-96 border-2 border-dashed border-gray-300 rounded-lg flex flex-col items-center justify-center bg-gray-50 hover:border-gray-400 hover:bg-gray-100 transition-colors cursor-pointer"
                phx-click="show_film_modal"
                phx-target={@myself}
              >
                <!-- Include Cropper.js CDN -->
                <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.6.1/cropper.min.css">
                <script src="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.6.1/cropper.min.js"></script>

                <%= if Windowpane.Uploaders.CoverUploader.cover_exists?(@project) do %>
                  <!-- Show uploaded cover image -->
                  <img
                    src={cover_url_with_cache_bust(@project, @cover_updated_at)}
                    alt={"Cover for #{@project.title}"}
                    class="w-full h-full object-cover rounded-lg"
                  />
                <% else %>
                  <!-- Show placeholder when no cover exists -->
                  <div class="text-center">
                    <svg class="mx-auto h-16 w-16 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                    <span class="text-xs text-gray-500">JPG, PNG, WEBP accepted</span>
                  </div>
                <% end %>
              </div>

              <!-- Pencil Edit Icon (positioned absolutely over the cover but outside its div) -->
              <button
                type="button"
                class="absolute top-0 right-0 -mt-2 -mr-2 w-8 h-8 bg-white rounded-full shadow-md flex items-center justify-center border border-gray-200 hover:bg-gray-50 cursor-pointer z-10"
                onclick="document.getElementById('cover-file-input').click();"
              >
                <svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                </svg>
              </button>

              <!-- Hidden file input (outside the clickable area) -->
              <input
                type="file"
                id="cover-file-input"
                accept=".jpg,.jpeg,.png,.webp"
                style="display: none;"
                id="image-cropper-hook"
                phx-hook="ImageCropper"
                data-project-id={@project.id}
                phx-target={@myself}
              />
            </div>
          </div>

          <!-- Instructions text (separate from cover) -->
          <p class="text-sm text-gray-600 text-center mt-4">
            Click cover for additional configuration
          </p>
        </div>
      <% end %>

      <%= if @active_tab == "live_stream_setup" do %>
        <!-- Project Details Form -->
        <div class="bg-white shadow rounded-lg p-6 mb-8">
          <h2 class="text-2xl font-bold mb-6">Live Stream Setup</h2>

          <.form :let={f} for={@changeset} phx-submit="save" phx-target={@myself} class="space-y-6">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <.input field={f[:title]} type="text" label="Stream Title" required />
              </div>
              <div>
                <.input field={f[:status]} type="select" label="Status" options={[
                  {"Draft", "draft"},
                  {"Scheduled", "scheduled"},
                  {"Live", "live"},
                  {"Ended", "ended"}
                ]} />
              </div>
            </div>

            <div>
              <.input field={f[:description]} type="textarea" label="Stream Description" rows="4" />
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <.input field={f[:premiere_date]} type="datetime-local" label="Scheduled Start Time" />
              </div>
              <div>
                <.input field={f[:premiere_price]} type="number" label="Ticket Price ($)" step="0.01" min="0" />
              </div>
            </div>

            <%= if @editing do %>
              <div class="flex justify-end">
                <button
                  type="submit"
                  class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-md font-medium hover:bg-blue-700 transition-colors"
                >
                  Save Changes
                </button>
              </div>
            <% end %>
          </.form>
        </div>

        <!-- Coming Soon Section -->
        <div class="bg-gradient-to-r from-blue-50 to-indigo-50 rounded-lg p-8 text-center">
          <div class="mx-auto h-24 w-24 text-blue-500 mb-6">
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" class="w-full h-full">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
            </svg>
          </div>

          <h3 class="text-2xl font-bold text-gray-900 mb-4">
            Live Streaming Setup
          </h3>

          <p class="text-lg text-gray-600 mb-6 max-w-2xl mx-auto">
            Complete live streaming functionality is coming soon! This will include stream configuration,
            RTMP settings, stream keys, and real-time viewer management.
          </p>

          <div class="flex items-center justify-center space-x-8 text-sm text-gray-500">
            <div class="flex items-center space-x-2">
              <svg class="w-5 h-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span>RTMP Streaming</span>
            </div>

            <div class="flex items-center space-x-2">
              <svg class="w-5 h-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span>Real-time Chat</span>
            </div>

            <div class="flex items-center space-x-2">
              <svg class="w-5 h-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span>Analytics</span>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
