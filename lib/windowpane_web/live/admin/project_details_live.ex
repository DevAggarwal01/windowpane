defmodule WindowpaneWeb.Admin.ProjectDetailsLive do
  use WindowpaneWeb, :live_view
  require Logger

  alias Windowpane.Projects
  alias Windowpane.MuxToken
  alias Phoenix.LiveView.JS

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Load project with appropriate associations based on type
    project = case get_project_with_associations(id) do
      {:ok, project} -> project
      {:error, _} -> Projects.get_project!(id)
    end

    # Generate signed tokens for trailer and film if they exist (only for film projects)
    trailer_token = if project.film && !is_struct(project.film, Ecto.Association.NotLoaded) && project.film.trailer_playback_id do
      MuxToken.generate_playback_token(project.film.trailer_playback_id)
    else
      nil
    end

    film_token = if project.film && !is_struct(project.film, Ecto.Association.NotLoaded) && project.film.film_playback_id do
      MuxToken.generate_playback_token(project.film.film_playback_id)
    else
      nil
    end

    {:ok,
     socket
     |> assign(:page_title, "Project Details")
     |> assign(:project, project)
     |> assign(:selected_tab, "trailer")
     |> assign(:trailer_token, trailer_token)
     |> assign(:film_token, film_token)
     |> assign(:show_feedback_modal, false)
     |> assign(:feedback_text, "")}
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
  def handle_event("select-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :selected_tab, tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100">
      <nav class="bg-white shadow-sm">
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="flex h-16 justify-between">
            <div class="flex">
              <div class="flex flex-shrink-0 items-center">
                <img class="h-8 w-auto" src={~p"/images/logo.png"} alt="Windowpane Admin" />
                <span class="ml-2 text-lg font-semibold text-gray-900">Admin</span>
              </div>
            </div>
            <div class="flex items-center">
              <.link
                navigate={~p"/"}
                class="relative inline-flex items-center gap-x-1.5 rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
              >
                Back to Dashboard
              </.link>
            </div>
          </div>
        </div>
      </nav>

      <main class="py-10">
        <div class="mx-auto max-w-7xl sm:px-6 lg:px-8">
          <div class="flex gap-8">
            <!-- Left side - Cover Image -->
            <div class="w-1/3">
              <div class="bg-white rounded-lg shadow-sm p-6">
                <!-- Action Buttons -->
                <!-- Debug: Current Status = <%= @project.status %> -->
                <div class="flex gap-3 mb-6">
                  <button
                    phx-click="approve-project"
                    phx-value-id={@project.id}
                    class="flex-1 inline-flex items-center justify-center rounded-md bg-green-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-green-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-green-600"
                  >
                    <svg class="mr-2 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                    </svg>
                    Approve
                  </button>
                  <button
                    phx-click="show-feedback-modal"
                    phx-value-id={@project.id}
                    class="flex-1 inline-flex items-center justify-center rounded-md bg-red-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-red-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-red-600"
                  >
                    <svg class="mr-2 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                    </svg>
                    Deny
                  </button>
                </div>

                <h3 class="text-lg font-medium text-gray-900 mb-4">Cover Image</h3>
                <%= if Windowpane.Uploaders.CoverUploader.cover_exists?(@project) do %>
                  <img
                    src={Windowpane.Uploaders.CoverUploader.cover_url(@project)}
                    class="w-full object-cover rounded-lg"
                    style="width: 320px; height: 480px; aspect-ratio: 2/3;"
                    alt={@project.title}
                  />
                <% else %>
                  <div class="bg-gray-200 rounded-lg flex items-center justify-center" style="width: 320px; height: 480px; aspect-ratio: 2/3;">
                    <%= case @project.type do %>
                      <% "film" -> %>
                        <span class="text-4xl">🎞️</span>
                      <% "tv_show" -> %>
                        <span class="text-4xl">🎬</span>
                      <% "live_event" -> %>
                        <span class="text-4xl">🎤</span>
                      <% "book" -> %>
                        <span class="text-4xl">📚</span>
                      <% "music" -> %>
                        <span class="text-4xl">🎶</span>
                    <% end %>
                  </div>
                <% end %>

                <!-- Banner Image -->
                <div class="mt-6">
                  <h3 class="text-lg font-medium text-gray-900 mb-4">Banner Image</h3>
                  <%= if Windowpane.Uploaders.BannerUploader.banner_exists?(@project) do %>
                    <img
                      src={Windowpane.Uploaders.BannerUploader.banner_url(@project)}
                      class="w-full object-cover rounded-lg"
                      style="width: 320px; height: 180px; aspect-ratio: 16/9;"
                      alt={"Banner for #{@project.title}"}
                    />
                  <% else %>
                    <div class="bg-gray-200 rounded-lg flex items-center justify-center" style="width: 320px; height: 180px; aspect-ratio: 16/9;">
                      <div class="text-center">
                        <svg class="mx-auto h-12 w-12 text-gray-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                        <span class="text-sm text-gray-500">No banner uploaded</span>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Right side - Video and Details -->
            <div class="flex-1 flex flex-col gap-8">
              <!-- Toggle Tabs -->
              <%= if @project.type == "film" && @project.film && !is_struct(@project.film, Ecto.Association.NotLoaded) do %>
                <div class="flex space-x-8 justify-center mb-4">
                  <button
                    phx-click="select-tab"
                    phx-value-tab="trailer"
                    class={"text-2xl font-medium border-b-2 px-4 pb-1 " <> if @selected_tab == "trailer", do: "border-brand text-gray-900", else: "border-transparent text-gray-500 hover:text-gray-700"}
                  >
                    Trailer
                  </button>
                  <button
                    phx-click="select-tab"
                    phx-value-tab="film"
                    class={"text-2xl font-medium border-b-2 px-4 pb-1 " <> if @selected_tab == "film", do: "border-brand text-gray-900", else: "border-transparent text-gray-500 hover:text-gray-700"}
                  >
                    Film
                  </button>
                </div>

                <!-- Video Player Area -->
                <div class="bg-white rounded-lg shadow-sm p-6 min-h-[300px] flex items-center justify-center">
                  <%= if @selected_tab == "trailer" do %>
                    <!-- Trailer video player placeholder -->
                    <%= if @project.film.trailer_playback_id do %>
                      <mux-player
                        playback-id={@project.film.trailer_playback_id}
                        playback-token={@trailer_token}
                      ></mux-player>
                    <% else %>
                      <div class="w-full text-center text-lg text-gray-500">No trailer available</div>
                    <% end %>
                  <% else %>
                    <!-- Film video player placeholder -->
                    <script src="https://cdn.jsdelivr.net/npm/@mux/mux-player" defer></script>
                    <%= if @project.film.film_playback_id && @film_token do %>
                      <mux-player
                        playback-id={@project.film.film_playback_id}
                        playback-token={@film_token}
                      ></mux-player>
                    <% else %>
                      <div class="w-full text-center text-lg text-gray-500">No film available</div>
                    <% end %>
                  <% end %>
                </div>
              <% else %>
                <!-- Non-film projects or projects without film data -->
                <div class="bg-white rounded-lg shadow-sm p-6 min-h-[300px] flex items-center justify-center">
                  <div class="text-center">
                    <div class="text-6xl mb-4">
                      <%= case @project.type do %>
                        <% "live_event" -> %>
                          🎤
                        <% "tv_show" -> %>
                          🎬
                        <% "book" -> %>
                          📚
                        <% "music" -> %>
                          🎶
                        <% _ -> %>
                          🎞️
                      <% end %>
                    </div>
                    <h3 class="text-lg font-medium text-gray-900 mb-2">
                      <%= String.capitalize(String.replace(@project.type, "_", " ")) %> Project
                    </h3>
                    <p class="text-gray-500">
                      <%= case @project.type do %>
                        <% "live_event" -> %>
                          Live stream content will be available during the scheduled broadcast
                        <% _ -> %>
                          Media content not available for preview
                      <% end %>
                    </p>
                  </div>
                </div>
              <% end %>

              <!-- Project Details -->
              <div class="bg-white shadow rounded-lg mt-8">
                <div class="px-4 py-5 sm:p-6">
                  <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
                    <div>
                      <h3 class="text-lg font-medium leading-6 text-gray-900">Project Details</h3>
                      <div class="mt-4 space-y-4">
                        <div>
                          <h4 class="text-sm font-medium text-gray-500">Title</h4>
                          <p class="mt-1 text-sm text-gray-900"><%= @project.title %></p>
                        </div>
                        <div>
                          <h4 class="text-sm font-medium text-gray-500">Description</h4>
                          <p class="mt-1 text-sm text-gray-900"><%= @project.description %></p>
                        </div>
                        <div>
                          <h4 class="text-sm font-medium text-gray-500">Type</h4>
                          <p class="mt-1 text-sm text-gray-900"><%= String.capitalize(@project.type) %></p>
                        </div>
                        <div>
                          <h4 class="text-sm font-medium text-gray-500">Status</h4>
                          <p class="mt-1">
                            <span class={"inline-flex items-center rounded-md px-2 py-1 text-xs font-medium #{status_class(@project.status)}"}>
                              <%= String.capitalize(@project.status) %>
                            </span>
                          </p>
                        </div>
                      </div>
                    </div>

                    <div>
                      <h3 class="text-lg font-medium leading-6 text-gray-900">Pricing & Schedule</h3>
                      <div class="mt-4 space-y-4">
                        <div>
                          <h4 class="text-sm font-medium text-gray-500">Premiere Date</h4>
                          <p class="mt-1 text-sm text-gray-900">
                            <%= if @project.premiere_date do %>
                              <%= Calendar.strftime(@project.premiere_date, "%B %d, %Y at %I:%M %p") %>
                            <% else %>
                              Not set
                            <% end %>
                          </p>
                        </div>
                        <div>
                          <h4 class="text-sm font-medium text-gray-500">Premiere Price</h4>
                          <p class="mt-1 text-sm text-gray-900">
                            <%= if @project.premiere_price do %>
                              $<%= Decimal.to_string(@project.premiere_price) %>
                            <% else %>
                              Not set
                            <% end %>
                          </p>
                        </div>
                        <div>
                          <h4 class="text-sm font-medium text-gray-500">Premiere Creator Cut</h4>
                          <p class="mt-1 text-sm text-gray-900">
                            <%= if @project.premiere_creator_cut do %>
                              $<%= Decimal.to_string(@project.premiere_creator_cut) %>
                            <% else %>
                              Not calculated
                            <% end %>
                          </p>
                        </div>
                        <div>
                          <h4 class="text-sm font-medium text-gray-500">Rental Price</h4>
                          <p class="mt-1 text-sm text-gray-900">
                            <%= if @project.rental_price do %>
                              $<%= Decimal.to_string(@project.rental_price) %>
                            <% else %>
                              Not set
                            <% end %>
                          </p>
                        </div>
                        <div>
                          <h4 class="text-sm font-medium text-gray-500">Rental Creator Cut</h4>
                          <p class="mt-1 text-sm text-gray-900">
                            <%= if @project.rental_creator_cut do %>
                              $<%= Decimal.to_string(@project.rental_creator_cut) %>
                            <% else %>
                              Not calculated
                            <% end %>
                          </p>
                        </div>
                        <%= if @project.type != "live_event" do %>
                          <div>
                            <h4 class="text-sm font-medium text-gray-500">Rental Window</h4>
                            <p class="mt-1 text-sm text-gray-900">
                              <%= if @project.rental_window_hours do %>
                                <%= @project.rental_window_hours %> hours
                              <% else %>
                                Not set
                              <% end %>
                            </p>
                          </div>
                        <% end %>

                        <!-- Live Stream Specific Information -->
                        <%= if @project.type == "live_event" && @project.live_stream do %>
                          <div>
                            <h4 class="text-sm font-medium text-gray-500">Recording Enabled</h4>
                            <p class="mt-1 text-sm text-gray-900">
                              <span class={"inline-flex items-center rounded-md px-2 py-1 text-xs font-medium " <> if @project.live_stream.recording, do: "bg-green-50 text-green-700", else: "bg-red-50 text-red-700"}>
                                <%= if @project.live_stream.recording, do: "Yes", else: "No" %>
                              </span>
                            </p>
                          </div>
                          <div>
                            <h4 class="text-sm font-medium text-gray-500">Expected Duration</h4>
                            <p class="mt-1 text-sm text-gray-900">
                              <%= if @project.live_stream.expected_duration_minutes do %>
                                <%= @project.live_stream.expected_duration_minutes %> minutes
                              <% else %>
                                Not set
                              <% end %>
                            </p>
                          </div>
                          <div>
                            <h4 class="text-sm font-medium text-gray-500">Stream Status</h4>
                            <p class="mt-1 text-sm text-gray-900">
                              <span class={"inline-flex items-center rounded-md px-2 py-1 text-xs font-medium " <> stream_status_class(@project.live_stream.status)}>
                                <%= String.capitalize(@project.live_stream.status) %>
                              </span>
                            </p>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>

    <!-- Feedback Modal -->
    <.modal :if={@show_feedback_modal} id="feedback-modal" show on_cancel={JS.push("close-feedback-modal")}>
      <div class="text-center">
        <div class="mb-4">
          <h3 class="text-lg font-medium text-gray-900">Deny Project</h3>
          <p class="text-sm text-gray-500 mt-1">Please provide feedback explaining why this project is being denied. This feedback will be visible to the creator.</p>
        </div>

        <form phx-submit="submit-feedback" class="mt-4">
          <div class="mb-4">
            <textarea
              name="feedback"
              value={@feedback_text}
              rows="4"
              class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              placeholder="Enter your feedback here..."
              required
            ></textarea>
          </div>

          <div class="flex justify-center gap-3">
            <button
              type="button"
              phx-click="close-feedback-modal"
              class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="px-4 py-2 text-sm font-medium text-white bg-red-600 border border-transparent rounded-md shadow-sm hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
            >
              Deny Project
            </button>
          </div>
        </form>
      </div>
    </.modal>
    """
  end

  @impl true
  def handle_event("approve-project", %{"id" => project_id}, socket) do
    # Load project with appropriate associations
    {:ok, project} = get_project_with_associations(project_id)

    # Check if this is a live stream project and create Mux live stream if needed
    live_stream_result = if project.type == "live_event" do
      case create_mux_live_stream(project) do
        {:ok, message} ->
          Logger.info("Live stream created during approval: #{message}")
          :ok
        {:error, error} ->
          Logger.error("Failed to create live stream during approval: #{error}")
          {:error, error}
      end
    else
      :ok
    end

    case live_stream_result do
      :ok ->
        case Projects.update_project(project, %{status: "published"}) do
          {:ok, updated_project} ->
            # Remove from approval queue
            Projects.remove_from_approval_queue(updated_project)

            # Create premiere entry with calculated end_time based on duration (only for films and live streams)
            if project.type in ["film", "live_event"] do
              case Projects.create_premiere(project) do
                {:ok, _premiere} ->
                  Logger.info("Premiere created successfully for project #{project.id}")
                {:error, premiere_error} ->
                  Logger.error("Failed to create premiere for project #{project.id}: #{inspect(premiere_error)}")
                  # Continue with approval even if premiere creation fails
              end
            end

            # Create project review
            Projects.create_project_review(%{
              status: "approved",
              feedback: nil,
              project_id: project.id
            })

            success_message = if project.type == "live_event" do
              "Live stream project approved and Mux stream created successfully"
            else
              "Project approved successfully"
            end

            {:noreply,
             socket
             |> put_flash(:info, success_message)
             |> assign(:project, updated_project)
             |> push_navigate(to: ~p"/")}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to approve project")}
        end

      {:error, error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create live stream: #{error}")}
    end
  end

  @impl true
  def handle_event("show-feedback-modal", %{"id" => project_id}, socket) do
    # Load project with appropriate associations
    {:ok, project} = get_project_with_associations(project_id)
    {:noreply,
     socket
     |> assign(:show_feedback_modal, true)
     |> assign(:project, project)}
  end

  @impl true
  def handle_event("close-feedback-modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_feedback_modal, false)
     |> assign(:feedback_text, "")}
  end

  @impl true
  def handle_event("submit-feedback", %{"feedback" => feedback}, socket) do
    project = socket.assigns.project

    if String.trim(feedback) == "" do
      {:noreply,
       socket
       |> put_flash(:error, "Feedback is required for denial")}
    else
      # Update project status to draft
      case Projects.update_project(project, %{status: "draft"}) do
        {:ok, updated_project} ->
          # Remove from approval queue
          Projects.remove_from_approval_queue(updated_project)

          # Create project review
          Projects.create_project_review(%{
            status: "denied",
            feedback: feedback,
            project_id: project.id
          })

          {:noreply,
           socket
           |> put_flash(:info, "Project denied and returned to draft")
           |> assign(:project, updated_project)
           |> assign(:show_feedback_modal, false)
           |> assign(:feedback_text, "")
           |> push_navigate(to: ~p"/")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to deny project")}
      end
    end
  end

  defp status_class(status) do
    case status do
      "draft" -> "bg-gray-50 text-gray-700"
      "published" -> "bg-green-50 text-green-700"
      "archived" -> "bg-red-50 text-red-700"
      "waiting for approval" -> "bg-yellow-50 text-yellow-700"
      _ -> "bg-gray-50 text-gray-700"
    end
  end

  defp stream_status_class(status) do
    case status do
      "active" -> "bg-green-50 text-green-700"
      "idle" -> "bg-yellow-50 text-yellow-700"
      "ended" -> "bg-gray-50 text-gray-700"
      "errored" -> "bg-red-50 text-red-700"
      _ -> "bg-gray-50 text-gray-700"
    end
  end

  # Private method to create live stream from Mux
  defp create_mux_live_stream(project) do
    require Logger
    Logger.warning("CREATE_LIVE_STREAM: Project ID: #{project.id}")

    client = Mux.client()
    params = %{
      "playback_policy" => "signed",
      "new_asset_settings" => %{
        "playback_policies" => ["signed"],
      },
      "cors_origin" => "http://windowpane.tv:4000", # TODO delete the 4000 localhost
      "passthrough" => "type:live_stream;project_id:#{project.id}"
    }

    case Mux.Video.LiveStreams.create(client, params) do
      {:ok, live_stream, _env} ->
        Logger.info("Created Mux live stream: #{inspect(live_stream)}")

        # Update existing live stream record in database
        live_stream_params = %{
          "mux_stream_id" => live_stream["id"],
          "stream_key" => live_stream["stream_key"],
          "playback_id" => live_stream["playback_ids"] |> List.first() |> Map.get("id")
        }

        # Get the existing live stream from the project (already preloaded)
        case project.live_stream do
          nil ->
            Logger.error("No existing live stream found for project #{project.id}")
            {:error, "No live stream found to update"}

          existing_live_stream ->
            case Projects.update_live_stream(existing_live_stream, live_stream_params) do
              {:ok, _updated_live_stream} ->
                Logger.info("Live stream record updated successfully")
                {:ok, "Live stream updated successfully"}

              {:error, changeset} ->
                Logger.error("Failed to update live stream record: #{inspect(changeset.errors)}")
                {:error, "Failed to update live stream"}
            end
        end

      {:error, error} ->
        Logger.error("Failed to create Mux live stream: #{inspect(error)}")
        {:error, "Failed to create live stream"}
    end
  end
end
