defmodule WindowpaneWeb.LiveStreamSetupComponent do
  use WindowpaneWeb, :live_component
  require Logger
  import Phoenix.LiveView.JS

  alias Windowpane.Projects
  alias Windowpane.Uploaders.CoverUploader
  alias Windowpane.Uploaders.BannerUploader

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
     |> assign(:active_tab, "project_details")
     |> assign(:cover_updated_at, System.system_time(:second))
     |> assign(:revenue_breakdown, nil)
     |> assign(:saving, false)
     |> assign(:current_price_input, nil)}
  end

  @impl true
  def update(%{project: project, editing: editing} = assigns, socket) do
    changeset =
      project
      |> Projects.change_project()
      |> Ecto.Changeset.cast_assoc(:live_stream, with: &Windowpane.Projects.LiveStream.changeset/2)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> allow_upload(:cover, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1)
     |> allow_upload(:banner, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1)}
  end

  @impl true
  def handle_event("save", %{"project" => project_params}, socket) do
    Logger.warning("SAVE: Live Stream Project ID: #{socket.assigns.project.id}, Params: #{inspect(project_params)}")

    # Handle project update with nested live_stream attributes
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
      "playback_policy" => "signed",
      "new_asset_settings" => %{
        "playback_policies" => ["signed"],
      },
      "cors_origin" => "http://windowpane.tv:4000", # TODO delete the 4000 localhost
      "passthrough" => "type:live_stream;project_id:#{socket.assigns.project.id}"
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
  def handle_event("switch_tab", %{"tab" => "pricing_details"} = params, socket) do
    socket =
      if socket.assigns.project.live_stream do
        calculate_revenue_breakdown(socket)
      else
        socket
      end
    {:noreply, assign(socket, :active_tab, "pricing_details")}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  defp calculate_revenue_breakdown(socket) do
    project = socket.assigns.project
    minutes = project.live_stream.expected_duration_minutes || 0
    price = case project.premiere_price do
      price when is_binary(price) -> Decimal.to_float(Decimal.new(price))
      %Decimal{} = price -> Decimal.to_float(price)
      price when is_float(price) -> price
      price when is_integer(price) -> price * 1.0
      _ -> 0.0
    end

    # Platform margin calculation
    platform_margin = 0.4 / (price + 1) + 0.1

    platform_cut = price * platform_margin
    creator_payout = price - platform_cut

    assign(socket, :revenue_breakdown, %{
      price: price,
      platform_margin: platform_margin,
      platform_cut: platform_cut,
      creator_payout: creator_payout
    })
  end

  @impl true
  def handle_event("price_changed", params, socket) do
    Logger.info("Price changed params: #{inspect(params)}")
    price = params["premiere_price"]
    Logger.info("Setting current price input to: #{inspect(price)}")
    {:noreply, assign(socket, :current_price_input, price)}
  end

  @impl true
  def handle_event("update_price", %{"price" => price_str}, socket) do
    require Logger
    Logger.info("Update price called with price: #{inspect(price_str)}")

    case validate_and_parse_price(price_str) do
      {:ok, price_float} ->
        Logger.info("Parsed price to float: #{inspect(price_float)}")
        case Projects.update_project(socket.assigns.project, %{"premiere_price" => price_float}) do
          {:ok, project} ->
            Logger.info("Project price updated successfully to: #{price_float}")
            updated_project = Projects.get_project_with_live_stream_and_reviews!(project.id)

            socket = socket
              |> assign(:project, updated_project)
              |> assign(:current_price_input, nil)
              |> calculate_revenue_breakdown()

            {:noreply,
             socket
             |> put_flash(:info, "Price updated successfully")}

          {:error, changeset} ->
            Logger.error("Failed to update project price: #{inspect(changeset.errors)}")
            {:noreply, put_flash(socket, :error, "Failed to update price")}
        end

      {:error, reason} ->
        Logger.error("Invalid price input: #{reason}")
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  # Helper function to validate and parse price
  defp validate_and_parse_price(price_str) when is_binary(price_str) do
    case Float.parse(price_str) do
      {price, _} when price >= 1.0 -> {:ok, price}
      {_, _} -> {:error, "Price must be at least $1.00"}
      :error -> {:error, "Invalid price format"}
    end
  end
  defp validate_and_parse_price(_), do: {:error, "Invalid price input"}

  @impl true
  def handle_event("validate", params, socket) do
    Logger.info("Validating form with params: #{inspect(params)}")
    {:noreply, assign(socket, :live_action_form, params)}
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
              phx-value-tab="project_details"
              phx-target={@myself}
              class={[
                "py-4 px-6 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "project_details",
                  do: "border-blue-500 text-blue-600 bg-blue-50",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              Project Details
            </button>
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
              phx-value-tab="pricing_details"
              phx-target={@myself}
              class={[
                "py-4 px-6 text-sm font-medium border-b-2 transition-colors",
                if(@active_tab == "pricing_details",
                  do: "border-blue-500 text-blue-600 bg-blue-50",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )
              ]}
            >
              Pricing Details
            </button>
          </nav>
        </div>
      </div>

      <!-- Tab Content -->
      <%= if @active_tab == "project_details" do %>
        <!-- Project Details Tab -->
        <div class="bg-white shadow rounded-lg p-6 mb-8">
          <h2 class="text-2xl font-bold mb-6">Project Details</h2>

          <.form :let={f} for={@changeset} phx-change="update_project_details" phx-target={@myself} class="space-y-6">
            <div>
              <.input field={f[:title]} type="text" label="Stream Title" required />
            </div>

            <div>
              <.input field={f[:description]} type="textarea" label="Stream Description" rows="4" />
            </div>

            <div>
              <.input field={f[:premiere_date]} type="datetime-local" label="Scheduled Start Time" />
            </div>

            <div>
              <div class="flex items-center gap-2 mb-2">
                <label class="block text-sm font-medium leading-6 text-gray-900">
                  Expected Duration (minutes)
                </label>
                <div class="relative group">
                  <svg class="w-4 h-4 text-gray-400 hover:text-gray-600 cursor-help" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <div class="absolute bottom-6 left-1/2 transform -translate-x-1/2 bg-gray-900 text-white text-xs rounded py-2 px-3 opacity-0 group-hover:opacity-100 transition-opacity duration-200 z-10 whitespace-nowrap">
                    ⚠️ Stream will automatically end when expected duration is reached
                  </div>
                </div>
              </div>
              <%= if @project.live_stream do %>
                <.inputs_for :let={ls_f} field={f[:live_stream]}>
                  <.input
                    field={ls_f[:expected_duration_minutes]}
                    type="number"
                    min="1"
                    step="1"
                    placeholder="e.g., 60 for 1 hour"
                  />
                </.inputs_for>
              <% else %>
                <input
                  type="number"
                  min="1"
                  step="1"
                  placeholder="e.g., 60 for 1 hour"
                  class="block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-zinc-900 sm:text-sm sm:leading-6"
                  disabled
                />
              <% end %>
              <p class="mt-2 text-sm text-gray-600">
                How long do you expect this live stream to run? This helps with planning and will automatically end the stream when reached.
              </p>
            </div>

            <div class="flex items-center justify-end">
              <%= if @saving do %>
                <div class="flex items-center gap-2">
                  <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                  <span class="text-sm text-gray-500">Saving...</span>
                </div>
              <% else %>
                <div class="flex items-center gap-2">
                  <div class="w-2 h-2 bg-green-500 rounded-full"></div>
                  <span class="text-sm text-gray-500">All changes saved</span>
                </div>
              <% end %>
            </div>
          </.form>
        </div>
      <% end %>

      <%= if @active_tab == "pricing_details" do %>
        <!-- Pricing Details Tab -->
        <div class="bg-white shadow rounded-lg p-6 mb-8">
          <h2 class="text-2xl font-bold mb-6">Pricing Details</h2>

          <div class="space-y-6">
            <!-- Price Input Section -->
            <div>
              <div class="flex items-center gap-2 mb-6">
                <div class="flex-grow">
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Ticket Price ($)
                  </label>
                  <div class="flex items-center gap-2">
                    <div class="flex-grow">
                      <input
                        type="number"
                        id="price-input"
                        name="premiere_price"
                        value={@current_price_input || @project.premiere_price}
                        min="1.00"
                        step="0.01"
                        placeholder="Enter price"
                        class="block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-blue-600 sm:text-sm sm:leading-6"
                        phx-change="price_changed"
                        phx-target={@myself}
                      />
                    </div>
                    <button
                      type="button"
                      id="update-price-button"
                      phx-hook="UpdatePrice"
                      phx-target={@myself}
                      class="inline-flex items-center justify-center rounded-md bg-blue-600 p-2 text-white shadow-sm hover:bg-blue-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600"
                    >
                      <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                      </svg>
                    </button>
                  </div>
                  <p class="mt-1 text-sm text-gray-500">
                    Minimum ticket price is $1.00. Click checkmark to update.
                  </p>
                </div>
              </div>
            </div>

            <!-- Revenue Breakdown Section -->
            <%= if @revenue_breakdown && @project.live_stream do %>
              <div class="mt-8 border-t pt-6">
                <h3 class="text-lg font-semibold mb-4">Revenue Breakdown (Per Viewer)</h3>

                <div class="bg-gray-50 rounded-lg p-6 space-y-4">
                  <div class="flex justify-between items-center">
                    <span class="text-sm font-medium text-gray-900">Ticket Price:</span>
                    <span class="font-semibold text-gray-900">
                      $<%= :erlang.float_to_binary(@revenue_breakdown.price, decimals: 2) %>
                    </span>
                  </div>

                  <div class="pt-2 border-t border-gray-200">
                    <div class="flex justify-between items-center text-sm">
                      <span>Platform Fee (<%= :erlang.float_to_binary(@revenue_breakdown.platform_margin * 100, decimals: 1) %>%):</span>
                      <span class="font-medium text-gray-600">
                        $<%= :erlang.float_to_binary(@revenue_breakdown.platform_cut, decimals: 2) %>
                      </span>
                    </div>
                  </div>

                  <div class="pt-2 border-t border-gray-200">
                    <div class="flex justify-between items-center">
                      <span class="font-medium text-gray-900">Your Payout:</span>
                      <span class="font-semibold text-green-600">
                        $<%= :erlang.float_to_binary(@revenue_breakdown.creator_payout, decimals: 2) %>
                      </span>
                    </div>
                  </div>

                  <div class="mt-4 text-xs text-gray-500 space-y-1">
                    <p>* Platform fee percentage decreases as ticket price increases</p>
                    <p>* Example platform fees:</p>
                    <ul class="list-disc ml-4 mt-1">
                      <li>30% for $1 tickets</li>
                      <li>23.3% for $2 tickets</li>
                      <li>16.7% for $5 tickets</li>
                      <li>13.6% for $10 tickets</li>
                    </ul>
                  </div>
                </div>
              </div>
            <% else %>
              <div class="mt-8 border-t pt-6">
                <p class="text-sm text-gray-600">
                  Please set an expected duration in the Project Details tab to see your revenue breakdown.
                </p>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

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
    </div>
    """
  end

  @impl true
  def handle_event("update_project_details", %{"project" => project_params}, socket) do
    Logger.info("Updating project details: #{inspect(project_params)}")

    # Set saving state to true
    socket = assign(socket, :saving, true)

    # Add a small delay to show the saving indicator
    Process.sleep(300)

    case Projects.update_project(socket.assigns.project, project_params) do
      {:ok, project} ->
        updated_project = Projects.get_project_with_live_stream_and_reviews!(project.id)
        {:noreply,
         socket
         |> assign(:project, updated_project)
         |> assign(:changeset, Projects.change_project(updated_project))
         |> assign(:saving, false)
         |> put_flash(:info, "Project details updated")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:saving, false)
         |> put_flash(:error, "Error updating project details")}
    end
  end

  @impl true
  def handle_event(event, params, socket) do
    require Logger
    Logger.info("Event received: #{event}, params: #{inspect(params)}, assigns: #{inspect(socket.assigns)}")

    case event do
      "price_changed" ->
        handle_price_changed(params, socket)
      "update_price" ->
        handle_update_price(params, socket)
      _ ->
        Logger.warning("Unhandled event: #{event}")
        {:noreply, socket}
    end
  end

  defp handle_price_changed(%{"value" => price}, socket) do
    require Logger
    Logger.info("Price changed to: #{inspect(price)}")
    {:noreply, socket}
  end

  defp handle_update_price(_params, socket) do
    require Logger
    Logger.info("Starting price update...")

    # Get the temporary price from the socket assigns
    case socket.assigns.temp_price do
      nil ->
        Logger.info("No temporary price found, keeping current price")
        {:noreply, socket}

      temp_price ->
        Logger.info("Using temporary price for update: #{inspect(temp_price)}")

        case Float.parse(to_string(temp_price)) do
          {price_float, _} when price_float >= 1.0 ->
            Logger.info("Valid price float: #{price_float}")
            case Projects.update_project(socket.assigns.project, %{"premiere_price" => price_float}) do
              {:ok, project} ->
                Logger.info("Project updated successfully")
                updated_project = Projects.get_project_with_live_stream_and_reviews!(project.id)

                socket = socket
                  |> assign(:project, updated_project)
                  |> assign(:temp_price, nil)

                socket = calculate_revenue_breakdown(socket)

                Logger.info("New project price: #{inspect(updated_project.premiere_price)}")
                {:noreply,
                 socket
                 |> put_flash(:info, "Ticket price updated successfully")}

              {:error, changeset} ->
                Logger.error("Failed to update project: #{inspect(changeset.errors)}")
                {:noreply,
                 socket
                 |> put_flash(:error, "Failed to update ticket price: #{inspect(changeset.errors)}")}
            end

          {price_float, _} ->
            Logger.info("Price too low: #{price_float}")
            {:noreply,
             socket
             |> put_flash(:error, "Ticket price must be at least $1.00")}

          :error ->
            Logger.error("Invalid price format: #{inspect(temp_price)}")
            {:noreply,
             socket
             |> put_flash(:error, "Invalid price format")}
        end
    end
  end

  @impl true
  def handle_event("validate", params, socket) do
    Logger.info("Validating form with params: #{inspect(params)}")
    {:noreply, assign(socket, :live_action_form, params)}
  end
end
