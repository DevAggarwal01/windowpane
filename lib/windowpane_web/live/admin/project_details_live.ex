defmodule WindowpaneWeb.Admin.ProjectDetailsLive do
  use WindowpaneWeb, :live_view

  alias Windowpane.Projects
  alias Windowpane.MuxToken
  alias Phoenix.LiveView.JS

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    project = Projects.get_project_with_film!(id)

    # Generate signed tokens for trailer and film if they exist
    trailer_token = if project.film && project.film.trailer_playback_id do
      MuxToken.generate_playback_token(project.film.trailer_playback_id)
    else
      nil
    end

    film_token = if project.film && project.film.film_playback_id do
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
              </div>
            </div>

            <!-- Right side - Video and Details -->
            <div class="flex-1 flex flex-col gap-8">
              <!-- Toggle Tabs -->
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

                  <%= if @project.film && @project.film.trailer_playback_id do %>

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
                  <%= if @project.film && @project.film.film_playback_id && @film_token do %>
                    <mux-player
                      playback-id={@project.film.film_playback_id}
                      playback-token={@film_token}
                    ></mux-player>
                  <% else %>
                    <div class="w-full text-center text-lg text-gray-500">No film available</div>
                  <% end %>
                <% end %>
              </div>

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
                          <p class="mt-1 text-sm text-gray-900"><%= Calendar.strftime(@project.premiere_date, "%B %d, %Y at %I:%M %p") %></p>
                        </div>
                        <div>
                          <h4 class="text-sm font-medium text-gray-500">Premiere Price</h4>
                          <p class="mt-1 text-sm text-gray-900">$<%= Decimal.to_string(@project.premiere_price) %></p>
                        </div>
                        <div>
                          <h4 class="text-sm font-medium text-gray-500">Rental Price</h4>
                          <p class="mt-1 text-sm text-gray-900">$<%= Decimal.to_string(@project.rental_price) %></p>
                        </div>
                        <div>
                          <h4 class="text-sm font-medium text-gray-500">Rental Window</h4>
                          <p class="mt-1 text-sm text-gray-900"><%= @project.rental_window_hours %> hours</p>
                        </div>
                        <div>
                          <h4 class="text-sm font-medium text-gray-500">Purchase Price</h4>
                          <p class="mt-1 text-sm text-gray-900">$<%= Decimal.to_string(@project.purchase_price) %></p>
                        </div>
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
    project = Projects.get_project_with_film!(project_id)
    case Projects.update_project(project, %{status: "published"}) do
      {:ok, updated_project} ->
        # Remove from approval queue
        Projects.remove_from_approval_queue(updated_project)

        # Create project review
        Projects.create_project_review(%{
          status: "approved",
          feedback: nil,
          project_id: project.id
        })

        {:noreply,
         socket
         |> put_flash(:info, "Project approved successfully")
         |> assign(:project, updated_project)
         |> push_navigate(to: ~p"/")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to approve project")}
    end
  end

  @impl true
  def handle_event("show-feedback-modal", %{"id" => project_id}, socket) do
    project = Projects.get_project_with_film!(project_id)
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
end
