defmodule WindowpaneWeb.Admin.ProjectDetailsLive do
  use WindowpaneWeb, :live_view

  alias Windowpane.Projects
  alias Windowpane.MuxToken

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
     |> assign(:film_token, film_token)}
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
                <h3 class="text-lg font-medium text-gray-900 mb-4">Cover Image</h3>
                <%= if Windowpane.Uploaders.CoverUploader.cover_exists?(@project) do %>
                  <img
                    src={Windowpane.Uploaders.CoverUploader.cover_url(@project)}
                    class="w-full aspect-[16/9] object-cover rounded-lg"
                    alt={@project.title}
                  />
                <% else %>
                  <div class="aspect-w-16 aspect-h-9 bg-gray-200 rounded-lg flex items-center justify-center">
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
                  <script src="https://cdn.jsdelivr.net/npm/@mux/mux-player" defer></script>
                  <%= if @project.film && @project.film.trailer_playback_id && @trailer_token do %>
                    <mux-player
                      playback-id={@project.film.trailer_playback_id}
                      tokens={Jason.encode!(%{@project.film.trailer_playback_id => @trailer_token})}
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
                      tokens={Jason.encode!(%{@project.film.film_playback_id => @film_token})}
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

                  <div class="mt-8 flex justify-end space-x-3">
                    <%= if @project.status == "waiting for approval" do %>
                      <button
                        phx-click="approve-project"
                        phx-value-id={@project.id}
                        class="inline-flex items-center rounded-md bg-green-50 px-3 py-2 text-sm font-medium text-green-700 hover:bg-green-100"
                      >
                        Approve Project
                      </button>
                      <button
                        phx-click="reject-project"
                        phx-value-id={@project.id}
                        class="inline-flex items-center rounded-md bg-red-50 px-3 py-2 text-sm font-medium text-red-700 hover:bg-red-100"
                      >
                        Reject Project
                      </button>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end

  @impl true
  def handle_event("approve-project", %{"id" => project_id}, socket) do
    project = Projects.get_project_with_film!(project_id)
    case Projects.update_project(project, %{status: "published"}) do
      {:ok, updated_project} ->
        # Remove from approval queue
        Projects.remove_from_approval_queue(updated_project)

        {:noreply,
         socket
         |> put_flash(:info, "Project approved successfully")
         |> assign(:project, updated_project)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to approve project")}
    end
  end

  @impl true
  def handle_event("reject-project", %{"id" => project_id}, socket) do
    project = Projects.get_project_with_film!(project_id)
    case Projects.update_project(project, %{status: "draft"}) do
      {:ok, updated_project} ->
        # Remove from approval queue
        Projects.remove_from_approval_queue(updated_project)

        {:noreply,
         socket
         |> put_flash(:info, "Project rejected and returned to draft")
         |> assign(:project, updated_project)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to reject project")}
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
