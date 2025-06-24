defmodule WindowpaneWeb.LiveStreamSetupComponent do
  use WindowpaneWeb, :live_component
  require Logger
  import Phoenix.LiveView.JS

  alias Windowpane.Projects
  alias Windowpane.PricingCalculator
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
     |> assign(:current_price_input, nil)
     |> assign(:current_premiere_price_input, nil)
     |> assign(:current_rental_price_input, nil)
     |> assign(:show_delete_modal, false)}
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

    # Calculate premiere price breakdown using PricingCalculator
    premiere_price = PricingCalculator.normalize_price(project.premiere_price)
    premiere_breakdown = PricingCalculator.calculate_revenue_breakdown(premiere_price)

    # Calculate rental price breakdown if recording is enabled
    rental_breakdown = if project.live_stream && project.live_stream.recording do
      rental_price = PricingCalculator.normalize_price(project.rental_price)
      PricingCalculator.calculate_revenue_breakdown(rental_price)
    else
      nil
    end

    assign(socket, :revenue_breakdown, %{
      premiere: premiere_breakdown,
      rental: rental_breakdown
    })
  end

  @impl true
  def handle_event("price_changed", params, socket) do
    Logger.info("Price changed params: #{inspect(params)}")

    cond do
      Map.has_key?(params, "premiere_price") ->
        price = params["premiere_price"]
        Logger.info("Setting current premiere price input to: #{inspect(price)}")
        {:noreply, assign(socket, :current_premiere_price_input, price)}

      Map.has_key?(params, "rental_price") ->
        price = params["rental_price"]
        Logger.info("Setting current rental price input to: #{inspect(price)}")
        {:noreply, assign(socket, :current_rental_price_input, price)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_price", %{"price" => price_str}, socket) do
    require Logger
    Logger.info("Update premiere price called with price: #{inspect(price_str)}")

    case validate_and_parse_price(price_str) do
      {:ok, price_float} ->
        Logger.info("Parsed premiere price to float: #{inspect(price_float)}")

        # Calculate creator cut using the pricing calculator
        creator_cut = PricingCalculator.calculate_creator_cut(price_float)

        Logger.info("Calculated premiere creator cut: #{inspect(creator_cut)}")

        case Projects.update_project(socket.assigns.project, %{
          "premiere_price" => price_float,
          "premiere_creator_cut" => creator_cut
        }) do
          {:ok, project} ->
            Logger.info("Project premiere price and creator cut updated successfully. Price: #{price_float}, Creator Cut: #{creator_cut}")
            updated_project = Projects.get_project_with_live_stream_and_reviews!(project.id)

            socket = socket
              |> assign(:project, updated_project)
              |> assign(:current_premiere_price_input, nil)
              |> calculate_revenue_breakdown()

            {:noreply,
             socket
             |> put_flash(:info, "Premiere price updated successfully")}

          {:error, changeset} ->
            Logger.error("Failed to update project premiere price: #{inspect(changeset.errors)}")
            {:noreply, put_flash(socket, :error, "Failed to update premiere price")}
        end

      {:error, reason} ->
        Logger.error("Invalid premiere price input: #{reason}")
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("update_rental_price", %{"price" => price_str}, socket) do
    require Logger
    Logger.info("Update rental price called with price: #{inspect(price_str)}")

    case validate_and_parse_price(price_str) do
      {:ok, price_float} ->
        Logger.info("Parsed rental price to float: #{inspect(price_float)}")

        # Calculate creator cut using the pricing calculator
        creator_cut = PricingCalculator.calculate_creator_cut(price_float)

        Logger.info("Calculated rental creator cut: #{inspect(creator_cut)}")

        case Projects.update_project(socket.assigns.project, %{
          "rental_price" => price_float,
          "rental_creator_cut" => creator_cut
        }) do
          {:ok, project} ->
            Logger.info("Project rental price and creator cut updated successfully. Price: #{price_float}, Creator Cut: #{creator_cut}")
            updated_project = Projects.get_project_with_live_stream_and_reviews!(project.id)

            socket = socket
              |> assign(:project, updated_project)
              |> assign(:current_rental_price_input, nil)
              |> calculate_revenue_breakdown()

            {:noreply,
             socket
             |> put_flash(:info, "Rental price updated successfully")}

          {:error, changeset} ->
            Logger.error("Failed to update project rental price: #{inspect(changeset.errors)}")
            {:noreply, put_flash(socket, :error, "Failed to update rental price")}
        end

      {:error, reason} ->
        Logger.error("Invalid rental price input: #{reason}")
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
    <div class="max-w-7xl mx-auto">
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

      <!-- Delete Confirmation Modal -->
      <%= if @show_delete_modal do %>
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-50">
          <div class="fixed inset-0 z-50 overflow-y-auto">
            <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
              <div class="relative transform overflow-hidden rounded-lg bg-white px-4 pb-4 pt-5 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg sm:p-6">
                <div class="sm:flex sm:items-start">
                  <div class="mx-auto flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full bg-red-100 sm:mx-0 sm:h-10 sm:w-10">
                    <svg class="h-6 w-6 text-red-600" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
                    </svg>
                  </div>
                  <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left">
                    <h3 class="text-base font-semibold leading-6 text-gray-900">Delete Project</h3>
                    <div class="mt-2">
                      <p class="text-sm text-gray-500">
                        Are you sure you want to delete "<strong><%= @project.title %></strong>"? This action cannot be undone and will permanently remove the project and all associated data.
                      </p>
                    </div>
                  </div>
                </div>
                <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
                  <button
                    type="button"
                    phx-click="delete_project"
                    phx-target={@myself}
                    class="inline-flex w-full justify-center rounded-md bg-red-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-red-500 sm:ml-3 sm:w-auto"
                  >
                    Delete Project
                  </button>
                  <button
                    type="button"
                    phx-click="hide_delete_modal"
                    phx-target={@myself}
                    class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:mt-0 sm:w-auto"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Main Layout: Two Column -->
      <div class="grid grid-cols-1 lg:grid-cols-4 gap-8">
        <!-- Main Content Area (Left Side) -->
        <div class="lg:col-span-3">
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
                <button
                  phx-click="switch_tab"
                  phx-value-tab="recording"
                  phx-target={@myself}
                  class={[
                    "py-4 px-6 text-sm font-medium border-b-2 transition-colors",
                    if(@active_tab == "recording",
                      do: "border-blue-500 text-blue-600 bg-blue-50",
                      else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                    )
                  ]}
                >
                  Recording & Library
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
                        Primiere Ticket Price ($)
                      </label>
                      <div class="flex items-center gap-2">
                        <div class="flex-grow">
                          <input
                            type="number"
                            id="price-input"
                            name="premiere_price"
                            value={@current_premiere_price_input || @project.premiere_price}
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

                <!-- Rental Price Input Section -->
                <%= if @project.live_stream && @project.live_stream.recording do %>
                  <div>
                    <div class="flex items-center gap-2 mb-6">
                      <div class="flex-grow">
                        <label class="block text-sm font-medium text-gray-700 mb-1">
                          Rental Ticket Price ($)
                        </label>
                        <div class="flex items-center gap-2">
                          <div class="flex-grow">
                            <input
                              type="number"
                              id="rental-price-input"
                              name="rental_price"
                              value={@current_rental_price_input || @project.rental_price}
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
                            id="update-rental-price-button"
                            phx-hook="UpdateRentalPrice"
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
                <% end %>

                <!-- Revenue Breakdown Section -->
                <%= if @revenue_breakdown && @project.live_stream do %>
                  <div class="mt-8 border-t pt-6">
                    <h3 class="text-lg font-semibold mb-4">Revenue Breakdown (Per Viewer)</h3>

                    <!-- Premiere Price Breakdown -->
                    <div class="mb-6">
                      <h4 class="text-md font-medium text-gray-900 mb-3">Live Stream Premiere</h4>
                      <div class="bg-gray-50 rounded-lg p-6 space-y-4">
                        <div class="flex justify-between items-center">
                          <span class="text-sm font-medium text-gray-900">Ticket Price:</span>
                          <span class="font-semibold text-gray-900">
                            $<%= :erlang.float_to_binary(@revenue_breakdown.premiere.price, decimals: 2) %>
                          </span>
                        </div>

                        <div class="pt-2 border-t border-gray-200">
                          <div class="flex justify-between items-center text-sm">
                            <span>Platform Fee (<%= :erlang.float_to_binary(@revenue_breakdown.premiere.platform_margin * 100, decimals: 1) %>%):</span>
                            <span class="font-medium text-gray-600">
                              $<%= :erlang.float_to_binary(@revenue_breakdown.premiere.platform_cut, decimals: 2) %>
                            </span>
                          </div>
                        </div>

                        <div class="pt-2 border-t border-gray-200">
                          <div class="flex justify-between items-center">
                            <span class="font-medium text-gray-900">Your Payout:</span>
                            <span class="font-semibold text-green-600">
                              $<%= :erlang.float_to_binary(@revenue_breakdown.premiere.creator_payout, decimals: 2) %>
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>

                    <!-- Rental Price Breakdown (only if recording is enabled) -->
                    <%= if @revenue_breakdown.rental do %>
                      <div class="mb-6">
                        <h4 class="text-md font-medium text-gray-900 mb-3">Recording Rental</h4>
                        <div class="bg-blue-50 rounded-lg p-6 space-y-4">
                          <div class="flex justify-between items-center">
                            <span class="text-sm font-medium text-gray-900">Rental Price:</span>
                            <span class="font-semibold text-gray-900">
                              $<%= :erlang.float_to_binary(@revenue_breakdown.rental.price, decimals: 2) %>
                            </span>
                          </div>

                          <div class="pt-2 border-t border-blue-200">
                            <div class="flex justify-between items-center text-sm">
                              <span>Platform Fee (<%= :erlang.float_to_binary(@revenue_breakdown.rental.platform_margin * 100, decimals: 1) %>%):</span>
                              <span class="font-medium text-gray-600">
                                $<%= :erlang.float_to_binary(@revenue_breakdown.rental.platform_cut, decimals: 2) %>
                              </span>
                            </div>
                          </div>

                          <div class="pt-2 border-t border-blue-200">
                            <div class="flex justify-between items-center">
                              <span class="font-medium text-gray-900">Your Payout:</span>
                              <span class="font-semibold text-green-600">
                                $<%= :erlang.float_to_binary(@revenue_breakdown.rental.creator_payout, decimals: 2) %>
                              </span>
                            </div>
                          </div>
                        </div>
                      </div>
                    <% end %>

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

          <%= if @active_tab == "recording" do %>
            <!-- Recording & Library Tab -->
            <div class="bg-white shadow rounded-lg p-6 mb-8">
              <h2 class="text-2xl font-bold mb-6">Recording & Video Library</h2>

              <div class="space-y-8">
                <!-- Recording Settings -->
                <div class="border-b border-gray-200 pb-6">
                  <h3 class="text-lg font-semibold mb-4 flex items-center">
                    <svg class="w-5 h-5 mr-2 text-red-500" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" />
                    </svg>
                    Recording Settings
                  </h3>

                  <!-- Recording Toggle -->
                  <div class="flex items-center justify-between mb-4">
                    <div class="flex items-center">
                      <span class="text-sm font-medium text-gray-900 mr-3">Enable Recording</span>
                      <button
                        type="button"
                        phx-click="toggle_recording"
                        phx-target={@myself}
                        class={[
                          "relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-blue-600 focus:ring-offset-2",
                          if(@project.live_stream && @project.live_stream.recording, do: "bg-blue-600", else: "bg-gray-200")
                        ]}
                        role="switch"
                        aria-checked={@project.live_stream && @project.live_stream.recording}
                      >
                        <span
                          aria-hidden="true"
                          class={[
                            "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
                            if(@project.live_stream && @project.live_stream.recording, do: "translate-x-5", else: "translate-x-0")
                          ]}
                        ></span>
                      </button>
                    </div>
                    <span class="text-sm text-gray-500">
                      <%= if @project.live_stream && @project.live_stream.recording do %>
                        Recording Enabled
                      <% else %>
                        Recording Disabled
                      <% end %>
                    </span>
                  </div>

                  <%= if @project.live_stream && @project.live_stream.recording do %>
                    <div class="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
                      <div class="flex items-center">
                        <svg class="w-5 h-5 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                        </svg>
                        <span class="font-medium text-green-800">Recording Enabled</span>
                      </div>
                      <p class="text-green-700 mt-2 text-sm">
                        Your live stream will be automatically recorded and available immediately after it ends.
                      </p>
                    </div>
                    <div class="text-sm text-gray-600 space-y-2">
                      <p>• High-quality recording (1080p) included with your stream</p>
                      <p>• Recording starts automatically when you go live</p>
                      <p>• Video is processed and ready within minutes of ending your stream</p>
                    </div>
                  <% else %>
                    <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-4">
                      <div class="flex items-center">
                        <svg class="w-5 h-5 text-yellow-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                        </svg>
                        <span class="font-medium text-yellow-800">Recording Disabled</span>
                      </div>
                      <p class="text-yellow-700 mt-2 text-sm">
                        Your live stream will not be recorded. You won't be able to monetize the recording or add it to the public library.
                      </p>
                    </div>
                  <% end %>
                </div>

                <!-- Monetization Options -->
                <%= if @project.live_stream && @project.live_stream.recording do %>
                  <div class="border-b border-gray-200 pb-6">
                    <h3 class="text-lg font-semibold mb-4 flex items-center">
                      <svg class="w-5 h-5 mr-2 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M8.433 7.418c.155-.103.346-.196.567-.267v1.698a2.305 2.305 0 01-.567-.267C8.07 8.34 8 8.114 8 8c0-.114.07-.34.433-.582zM11 12.849v-1.698c.22.071.412.164.567.267.364.243.433.468.433.582 0 .114-.07.34-.433.582a2.305 2.305 0 01-.567.267z" />
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-13a1 1 0 10-2 0v.092a4.535 4.535 0 00-1.676.662C6.602 6.234 6 7.009 6 8c0 .99.602 1.765 1.324 2.246.48.32 1.054.545 1.676.662v1.941c-.391-.127-.68-.317-.843-.504a1 1 0 10-1.51 1.31c.562.649 1.413 1.076 2.353 1.253V15a1 1 0 102 0v-.092a4.535 4.535 0 001.676-.662C13.398 13.766 14 12.991 14 12c0-.99-.602-1.765-1.324-2.246A4.535 4.535 0 0011 9.092V7.151c.391.127.68.317.843.504a1 1 0 101.511-1.31c-.563-.649-1.413-1.076-2.354-1.253V5z" clip-rule="evenodd" />
                      </svg>
                      Monetize Your Recording
                    </h3>
                    <div class="border border-gray-200 rounded-lg p-4">
                      <h4 class="font-medium text-gray-900 mb-2">Rental Access</h4>
                      <p class="text-sm text-gray-600 mb-3">
                        Allow viewers to rent your recorded stream for a specified time period.
                      </p>
                      <div class="space-y-2 text-sm">
                        <div class="flex justify-between">
                          <span class="text-gray-500">Rental Price:</span>
                          <span class="font-medium">${@project.rental_price || "5.00"}</span>
                        </div>
                        <div class="flex justify-between">
                          <span class="text-gray-500">Rental Window:</span>
                          <span class="font-medium">48 hours</span>
                        </div>
                      </div>
                    </div>
                  </div>

                  <!-- Public Library -->
                  <div>
                    <h3 class="text-lg font-semibold mb-4 flex items-center">
                      <svg class="w-5 h-5 mr-2 text-blue-500" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      Add to Public Video Library
                    </h3>
                    <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
                      <p class="text-blue-800 text-sm">
                        Your recorded stream can be added to our public video library, making it discoverable to new viewers and potentially increasing your earnings.
                      </p>
                    </div>

                    <div class="space-y-4">
                      <div class="flex items-start space-x-3">
                        <svg class="w-5 h-5 text-green-500 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                        </svg>
                        <div>
                          <h4 class="font-medium text-gray-900">Increased Discoverability</h4>
                          <p class="text-sm text-gray-600">Your content appears in search results and category browsing</p>
                        </div>
                      </div>

                      <div class="flex items-start space-x-3">
                        <svg class="w-5 h-5 text-green-500 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                        </svg>
                        <div>
                          <h4 class="font-medium text-gray-900">Passive Income</h4>
                          <p class="text-sm text-gray-600">Earn from rentals long after your live stream ends</p>
                        </div>
                      </div>

                      <div class="flex items-start space-x-3">
                        <svg class="w-5 h-5 text-green-500 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                        </svg>
                        <div>
                          <h4 class="font-medium text-gray-900">Professional Showcase</h4>
                          <p class="text-sm text-gray-600">Build your portfolio with high-quality recorded content</p>
                        </div>
                      </div>

                      <div class="flex items-start space-x-3">
                        <svg class="w-5 h-5 text-green-500 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                        </svg>
                        <div>
                          <h4 class="font-medium text-gray-900">Quality Control</h4>
                          <p class="text-sm text-gray-600">We maintain high standards to ensure the best viewer experience</p>
                        </div>
                      </div>
                    </div>

                    <div class="mt-6 bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                      <div class="flex items-center">
                        <svg class="w-5 h-5 text-yellow-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                        </svg>
                        <span class="font-medium text-yellow-800">Note</span>
                      </div>
                      <p class="text-yellow-700 mt-2 text-sm">
                        After your stream ends, you'll have the option to submit your recording for inclusion in our public library.
                        Our content team will review it within 24-48 hours and notify you of the decision.
                      </p>
                    </div>
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

        <!-- Project Actions Section (Right Side) -->
        <div class="lg:col-span-1">
          <!-- Project Status -->
          <div class="bg-white shadow rounded-lg mb-8 p-6">
            <div class="space-y-4">
              <!-- Project Status Header -->
              <div>
                <h3 class="text-lg font-semibold text-gray-900 mb-2">Project Status</h3>
                <%= case @project.status do %>
                  <% "draft" -> %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                      <svg class="mr-1.5 h-2 w-2 text-yellow-400" fill="currentColor" viewBox="0 0 8 8">
                        <circle cx="4" cy="4" r="3" />
                      </svg>
                      Draft
                    </span>
                  <% "published" -> %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      <svg class="mr-1.5 h-2 w-2 text-green-400" fill="currentColor" viewBox="0 0 8 8">
                        <circle cx="4" cy="4" r="3" />
                      </svg>
                      Published
                    </span>
                  <% "waiting for approval" -> %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                      <svg class="mr-1.5 h-2 w-2 text-blue-400" fill="currentColor" viewBox="0 0 8 8">
                        <circle cx="4" cy="4" r="3" />
                      </svg>
                      Pending Approval
                    </span>
                  <% "archived" -> %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                      <svg class="mr-1.5 h-2 w-2 text-gray-400" fill="currentColor" viewBox="0 0 8 8">
                        <circle cx="4" cy="4" r="3" />
                      </svg>
                      Archived
                    </span>
                  <% _ -> %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                      <svg class="mr-1.5 h-2 w-2 text-gray-400" fill="currentColor" viewBox="0 0 8 8">
                        <circle cx="4" cy="4" r="3" />
                      </svg>
                      <%= String.capitalize(@project.status) %>
                    </span>
                <% end %>
              </div>

              <!-- Action Buttons (Stacked) -->
              <div class="space-y-3">
                <%= if @project.status == "draft" do %>
                  <!-- Deploy Button -->
                  <button
                    type="button"
                    phx-click="deploy_project"
                    phx-target={@myself}
                    class="w-full inline-flex items-center justify-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
                  >
                    <svg class="mr-2 -ml-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                    </svg>
                    Deploy Project
                  </button>
                <% else %>
                  <!-- Project is already deployed -->
                  <div class="w-full inline-flex items-center justify-center px-4 py-2 text-sm text-green-600 bg-green-50 rounded-md">
                    <svg class="mr-2 h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                    </svg>
                    Project Deployed
                  </div>
                <% end %>

                <!-- Delete Button -->
                <button
                  type="button"
                  phx-click="show_delete_modal"
                  phx-target={@myself}
                  class="w-full inline-flex items-center justify-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-red-700 bg-red-100 hover:bg-red-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                >
                  <svg class="mr-2 -ml-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                  Delete Project
                </button>
              </div>

              <!-- Additional Project Info -->
              <%= if @project.status == "draft" do %>
                <div class="mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded-md">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg class="h-4 w-4 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-2">
                      <h4 class="text-xs font-medium text-yellow-800">
                        Draft Mode
                      </h4>
                      <div class="mt-1 text-xs text-yellow-700">
                        <p>
                          Complete setup and deploy to make live.
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>

              <%= if @project.status == "published" do %>
                <div class="mt-4 p-3 bg-green-50 border border-green-200 rounded-md">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <svg class="h-4 w-4 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-2">
                      <h4 class="text-xs font-medium text-green-800">
                        Live & Public
                      </h4>
                      <div class="mt-1 text-xs text-green-700">
                        <p>
                          Your stream is visible to viewers.
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
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
  def handle_event("toggle_recording", _params, socket) do
    require Logger
    Logger.info("Toggling recording for live stream")

    case socket.assigns.project.live_stream do
      nil ->
        Logger.warning("No live stream found for project")
        {:noreply, put_flash(socket, :error, "No live stream found for this project")}

      live_stream ->
        new_recording_value = !live_stream.recording
        Logger.info("Updating recording from #{live_stream.recording} to #{new_recording_value}")

        case Projects.update_live_stream(live_stream, %{"recording" => new_recording_value}) do
          {:ok, _updated_live_stream} ->
            Logger.info("Recording setting updated successfully")
            updated_project = Projects.get_project_with_live_stream_and_reviews!(socket.assigns.project.id)

            {:noreply,
             socket
             |> assign(:project, updated_project)
             |> put_flash(:info, "Recording setting updated successfully")}

          {:error, changeset} ->
            Logger.error("Failed to update recording setting: #{inspect(changeset.errors)}")
            {:noreply, put_flash(socket, :error, "Failed to update recording setting")}
        end
    end
  end

  @impl true
  def handle_event("deploy_project", _params, socket) do
    require Logger
    Logger.info("Deploying project: #{socket.assigns.project.id}")

    case Projects.update_project(socket.assigns.project, %{"status" => "published"}) do
      {:ok, project} ->
        Logger.info("Project deployed successfully")
        updated_project = Projects.get_project_with_live_stream_and_reviews!(project.id)

        {:noreply,
         socket
         |> assign(:project, updated_project)
         |> put_flash(:info, "Project deployed successfully! Your live stream is now public.")}

      {:error, changeset} ->
        Logger.error("Failed to deploy project: #{inspect(changeset.errors)}")
        {:noreply, put_flash(socket, :error, "Failed to deploy project")}
    end
  end

  @impl true
  def handle_event("show_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, true)}
  end

  @impl true
  def handle_event("hide_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, false)}
  end

  @impl true
  def handle_event("delete_project", _params, socket) do
    require Logger
    Logger.info("Deleting project: #{socket.assigns.project.id}")

    socket = assign(socket, :show_delete_modal, false)

    case Projects.delete_project(socket.assigns.project) do
      {:ok, _project} ->
        Logger.info("Project deleted successfully")
        # Send message to parent to redirect after deletion
        send(self(), {:project_deleted})

        {:noreply, socket}

      {:error, changeset} ->
        Logger.error("Failed to delete project: #{inspect(changeset.errors)}")
        {:noreply, put_flash(socket, :error, "Failed to delete project")}
    end
  end
end
