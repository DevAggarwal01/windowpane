defmodule AuroraWeb.HomeLive do
  use AuroraWeb, :live_view

  import AuroraWeb.NavComponents

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user] || socket.assigns[:current_creator]
    is_creator = !!socket.assigns[:current_creator]

    # Sample data - replace with real data from your context
    stats = %{
      total_revenue: "$12,345",
      content_performance: "Good",
      viewer_feedback: "Positive"
    }

    show_billing_popup = is_creator && socket.assigns[:current_creator] && !socket.assigns[:current_creator].onboarded

    projects = if is_creator do
      Aurora.Projects.list_projects(socket.assigns.current_creator.id)
    else
      []
    end

    {:ok, assign(socket,
      user: user,
      is_creator: is_creator,
      stats: stats,
      current_path: socket.assigns.live_action,
      show_billing_popup: show_billing_popup,
      show_project_dropdown: false,
      show_film_modal: false,
      film_form_step: 1,
      project_type: nil,
      error_message: nil,
      projects: projects,
      film_details: %{
        "title" => "",
        "description" => ""
      }
    )}
  end

  @impl true
  def handle_event("toggle_project_dropdown", _, socket) do
    {:noreply, assign(socket,
      show_project_dropdown: !socket.assigns.show_project_dropdown,
      error_message: nil
    )}
  end

  def handle_event("close_dropdown", _, socket) do
    {:noreply, assign(socket, show_project_dropdown: false, error_message: nil)}
  end

  def handle_event("close_film_modal", _, socket) do
    {:noreply, assign(socket,
      show_film_modal: false,
      film_form_step: 1,
      project_type: nil,
      film_details: %{"title" => "", "description" => ""}
    )}
  end

  def handle_event("create_project", %{"type" => type}, socket) do
    case type do
      "film" ->
        project_params = %{
          "title" => "New Film Project",
          "description" => "A new film project",
          "type" => type,
          "creator_id" => socket.assigns.current_creator.id,
          "status" => "draft",
          "premiere_date" => DateTime.utc_now() |> DateTime.add(30, :day),
          "rental_price" => Decimal.new("2.99"),
          "rental_window_hours" => 48,
          "purchase_price" => Decimal.new("9.99")
        }

        case Aurora.Projects.create_project(project_params) do
          {:ok, project} ->
            {:noreply,
             socket
             |> put_flash(:info, "Project created successfully!")
             |> redirect(to: ~p"/projects/#{project.id}")}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Error creating project. Please try again.")
             |> assign(show_project_dropdown: false)}
        end

      _ ->
        {:noreply, assign(socket,
          show_project_dropdown: false,
          error_message: "This project type is not supported yet. Coming soon!"
        )}
    end
  end

  def handle_event("next_step", params, socket) do
    next_step = socket.assigns.film_form_step + 1
    {:noreply, assign(socket,
      film_form_step: next_step,
      film_details: Map.merge(socket.assigns.film_details, params)
    )}
  end

  def handle_event("previous_step", _params, socket) do
    {:noreply, assign(socket, film_form_step: 1)}
  end

  def handle_event("submit_film_project", params, socket) do
    # Merge both steps' data and add type
    project_params = socket.assigns.film_details
    |> Map.merge(params)
    |> Map.put("type", socket.assigns.project_type)
    |> Map.put("creator_id", socket.assigns.current_creator.id)

    case Aurora.Projects.create_project(project_params) do
      {:ok, _project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project created successfully!")
         |> assign(
           show_film_modal: false,
           film_form_step: 1,
           film_details: %{"title" => "", "description" => ""},
           project_type: nil
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error creating project. Please check the form and try again.")
         |> put_flash(:error, "Error creating film project. Please check the form and try again.")
         |> assign(changeset: changeset)}
    end
  end

  def handle_event("create_project", %{"type" => "film"}, socket) do
    {:noreply, assign(socket,
      show_project_dropdown: false,
      show_film_modal: true,
      error_message: nil
    )}
  end

  def handle_event("create_project", _params, socket) do
    {:noreply, assign(socket,
      show_project_dropdown: false,
      error_message: "This project type is not supported yet. Coming soon!"
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <.main_header current_path={@current_path} is_creator={@is_creator} />

      <%= if @error_message do %>
        <div class="fixed top-4 right-4 bg-red-50 text-red-700 px-4 py-3 rounded-lg shadow-lg flex items-center z-50">
          <svg class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span><%= @error_message %></span>
        </div>
      <% end %>

      <%= if @show_film_modal do %>
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-50">
          <div class="fixed inset-0 z-50 overflow-y-auto">
            <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
              <div class="relative transform overflow-hidden rounded-lg bg-white px-4 pb-4 pt-5 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg sm:p-6">
                <div class="absolute right-0 top-0 pr-4 pt-4">
                  <button
                    phx-click="close_film_modal"
                    type="button"
                    class="rounded-md bg-white text-gray-400 hover:text-gray-500 focus:outline-none"
                  >
                    <span class="sr-only">Close</span>
                    <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
                <div>
                  <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-blue-100">
                    <span class="text-2xl">🎞️</span>
                  </div>
                  <div class="mt-3 text-center sm:mt-5">
                    <h3 class="text-xl font-semibold leading-6 text-gray-900">
                      <%= cond do %>
                        <% @film_form_step == 1 -> %>
                          Create New Film Project
                        <% @film_form_step == 2 -> %>
                          Configure Film Details
                        <% true -> %>
                          Upload a Trailer
                      <% end %>
                    </h3>
                    <div class="mt-4">
                      <%= cond do %>
                        <% @film_form_step == 1 -> %>
                          <form phx-submit="next_step" class="space-y-4">
                            <div>
                              <label for="title" class="block text-sm font-medium text-gray-700 text-left">
                                Film Title
                              </label>
                              <input
                                type="text"
                                name="title"
                                id="title"
                                value={@film_details["title"]}
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                placeholder="Enter film title"
                                required
                              />
                            </div>
                            <div>
                              <label for="description" class="block text-sm font-medium text-gray-700 text-left">
                                Description
                              </label>
                              <textarea
                                name="description"
                                id="description"
                                rows="3"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                placeholder="Enter film description"
                                required
                              ><%= @film_details["description"] %></textarea>
                            </div>
                            <div class="mt-6 sm:grid sm:grid-flow-row-dense sm:grid-cols-2 sm:gap-3">
                              <button
                                type="submit"
                                class="inline-flex w-full justify-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-500 sm:col-start-2"
                              >
                                Next
                              </button>
                              <button
                                type="button"
                                phx-click="close_film_modal"
                                class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:col-start-1 sm:mt-0"
                              >
                                Cancel
                              </button>
                            </div>
                          </form>
                        <% @film_form_step == 2 -> %>
                          <form phx-submit="next_step" class="space-y-4">
                            <div>
                              <label for="premiere_date" class="block text-sm font-medium text-gray-700 text-left">
                                Premiere Date
                              </label>
                              <input
                                type="datetime-local"
                                name="premiere_date"
                                id="premiere_date"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                required
                              />
                            </div>
                            <div>
                              <label for="premiere_price" class="block text-sm font-medium text-gray-700 text-left">
                                Premiere Ticket Price (optional)
                              </label>
                              <div class="mt-1 relative rounded-md shadow-sm">
                                <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                                  <span class="text-gray-500 sm:text-sm">$</span>
                                </div>
                                <input
                                  type="number"
                                  name="premiere_price"
                                  id="premiere_price"
                                  step="0.01"
                                  min="0"
                                  class="pl-7 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                  placeholder="0.00"
                                />
                              </div>
                            </div>
                            <div class="space-y-4">
                              <label class="block text-sm font-medium text-gray-700 text-left">
                                Rental Configuration
                              </label>
                              <div class="grid grid-cols-2 gap-4">
                                <div>
                                  <label for="rental_price" class="block text-sm font-medium text-gray-700 text-left">
                                    Rental Price
                                  </label>
                                  <div class="mt-1 relative rounded-md shadow-sm">
                                    <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                                      <span class="text-gray-500 sm:text-sm">$</span>
                                    </div>
                                    <input
                                      type="number"
                                      name="rental_price"
                                      id="rental_price"
                                      step="0.01"
                                      min="0"
                                      class="pl-7 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                      placeholder="0.00"
                                      required
                                    />
                                  </div>
                                </div>
                                <div>
                                  <label for="rental_window" class="block text-sm font-medium text-gray-700 text-left">
                                    Access Window (hours)
                                  </label>
                                  <input
                                    type="number"
                                    name="rental_window"
                                    id="rental_window"
                                    min="1"
                                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                    placeholder="48"
                                    required
                                  />
                                </div>
                              </div>
                            </div>
                            <div>
                              <label for="purchase_price" class="block text-sm font-medium text-gray-700 text-left">
                                Purchase Price (lifetime access)
                              </label>
                              <div class="mt-1 relative rounded-md shadow-sm">
                                <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                                  <span class="text-gray-500 sm:text-sm">$</span>
                                </div>
                                <input
                                  type="number"
                                  name="purchase_price"
                                  id="purchase_price"
                                  step="0.01"
                                  min="0"
                                  class="pl-7 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                  placeholder="0.00"
                                  required
                                />
                              </div>
                            </div>
                            <div class="mt-6 sm:grid sm:grid-flow-row-dense sm:grid-cols-2 sm:gap-3">
                              <button
                                type="submit"
                                class="inline-flex w-full justify-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-500 sm:col-start-2"
                              >
                                Next
                              </button>
                              <button
                                type="button"
                                phx-click="previous_step"
                                class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:col-start-1 sm:mt-0"
                              >
                                Back
                              </button>
                            </div>
                          </form>
                        <% true -> %>
                          <form phx-submit="submit_film_project" class="space-y-4">
                            <div class="text-center py-12">
                              <p class="text-gray-500">File upload area will be added here</p>
                            </div>
                            <div class="mt-6 sm:grid sm:grid-flow-row-dense sm:grid-cols-2 sm:gap-3">
                              <button
                                type="submit"
                                class="inline-flex w-full justify-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-500 sm:col-start-2"
                              >
                                Create Project
                              </button>
                              <button
                                type="button"
                                phx-click="previous_step"
                                class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:col-start-1 sm:mt-0"
                              >
                                Back
                              </button>
                            </div>
                          </form>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @show_billing_popup do %>
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-50">
          <div class="fixed inset-0 z-50 overflow-y-auto">
            <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
              <div class="relative transform overflow-hidden rounded-lg bg-white px-4 pb-4 pt-5 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg sm:p-6">
                <div>
                  <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-blue-100">
                    <svg class="h-6 w-6 text-[#0073b1]" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 002.25-2.25V6.75A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25v10.5A2.25 2.25 0 004.5 19.5z" />
                    </svg>
                  </div>
                  <div class="mt-3 text-center sm:mt-5">
                    <h3 class="text-xl font-semibold leading-6 text-gray-900">
                      Set Up Your Billing Information
                    </h3>
                    <div class="mt-4">
                      <p class="text-gray-600">
                        Before you can start uploading content and earning money, we need to set up your billing information. This is required so we can pay you for your content.
                      </p>
                      <p class="mt-2 text-sm text-gray-500">
                        You won't be charged anything - this is just so we can send you money!
                      </p>
                    </div>
                  </div>
                </div>
                <div class="mt-6 sm:mt-6 sm:grid sm:grid-flow-row-dense sm:grid-cols-2 sm:gap-3">
                  <.link
                    navigate={~p"/creators/settings"}
                    class="inline-flex w-full justify-center rounded-md bg-[#0073b1] px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-[#006097] sm:col-start-2"
                  >
                    Set up now
                  </.link>
                  <.link
                    navigate={~p"/creators/log_out"}
                    class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:col-start-1 sm:mt-0"
                  >
                    Log out
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Main Content -->
      <main class="container mx-auto px-4 py-8">
        <h1 class="text-3xl font-bold mb-8">Studio Homepage</h1>

        <!-- Stats Grid -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-2">Total Revenue</h3>
            <p class="text-4xl font-bold"><%= @stats.total_revenue %></p>
          </div>

          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-2">Content Performance</h3>
            <p class="text-4xl font-bold"><%= @stats.content_performance %></p>
          </div>

          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-2">Viewer Feedback</h3>
            <p class="text-4xl font-bold"><%= @stats.viewer_feedback %></p>
          </div>
        </div>

        <!-- Projects Section -->
        <div class="mb-8">
          <h2 class="text-2xl font-bold mb-4">My Projects</h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
            <!-- Create New Project Card -->
            <div class="relative" phx-click-away="close_dropdown">
              <button
                phx-click="toggle_project_dropdown"
                class="w-full flex flex-col items-center justify-center p-6 bg-white rounded-lg shadow-sm border-2 border-dashed border-gray-300 hover:border-gray-400 hover:bg-gray-50 transition-all duration-200"
              >
                <div class="w-16 h-16 flex items-center justify-center rounded-full bg-gray-100 mb-4">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                  </svg>
                </div>
                <h3 class="text-lg font-medium text-gray-900">Create New Project</h3>
                <p class="mt-1 text-sm text-gray-500">Start a new creative project</p>
              </button>

              <%= if @show_project_dropdown do %>
                <div class="absolute left-full ml-2 top-0 z-10 w-64 bg-white rounded-lg shadow-xl border border-gray-200 transform transition-all duration-200 ease-out">
                  <div class="p-2 space-y-1">
                    <div class="px-3 py-2 text-sm font-medium text-gray-500 border-b border-gray-100">
                      Select Project Type
                    </div>
                    <button
                      phx-click="create_project"
                      phx-value-type="film"
                      class="w-full text-left px-3 py-2 text-sm rounded-md text-gray-700 hover:bg-blue-50 hover:text-blue-700 flex items-center space-x-3 transition-colors duration-150"
                    >
                      <span class="text-xl">🎞️</span>
                      <span>Film</span>
                    </button>
                    <button
                      phx-click="create_project"
                      phx-value-type="tv_show"
                      class="w-full text-left px-3 py-2 text-sm rounded-md text-gray-700 hover:bg-blue-50 hover:text-blue-700 flex items-center space-x-3 transition-colors duration-150"
                    >
                      <span class="text-xl">🎬</span>
                      <span>TV Show</span>
                    </button>
                    <button
                      phx-click="create_project"
                      phx-value-type="live_event"
                      class="w-full text-left px-3 py-2 text-sm rounded-md text-gray-700 hover:bg-blue-50 hover:text-blue-700 flex items-center space-x-3 transition-colors duration-150"
                    >
                      <span class="text-xl">🎤</span>
                      <span>Live Event / Concert</span>
                    </button>
                    <button
                      phx-click="create_project"
                      phx-value-type="book"
                      class="w-full text-left px-3 py-2 text-sm rounded-md text-gray-700 hover:bg-blue-50 hover:text-blue-700 flex items-center space-x-3 transition-colors duration-150"
                    >
                      <span class="text-xl">📚</span>
                      <span>Book / Webcomic</span>
                    </button>
                    <button
                      phx-click="create_project"
                      phx-value-type="music"
                      class="w-full text-left px-3 py-2 text-sm rounded-md text-gray-700 hover:bg-blue-50 hover:text-blue-700 flex items-center space-x-3 transition-colors duration-150"
                    >
                      <span class="text-xl">🎶</span>
                      <span>Music Album / Single</span>
                    </button>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Project Cards -->
            <%= for project <- @projects do %>
              <.link navigate={~p"/projects/#{project.id}"} class="block">
                <div class="bg-white rounded-lg shadow-sm p-6 hover:shadow-md transition-shadow">
                  <div class="aspect-w-16 aspect-h-9 bg-gray-200 rounded-lg mb-4">
                    <%= case project.type do %>
                      <% "film" -> %>
                        <div class="flex items-center justify-center">
                          <span class="text-4xl">🎞️</span>
                        </div>
                      <% "tv_show" -> %>
                        <div class="flex items-center justify-center">
                          <span class="text-4xl">🎬</span>
                        </div>
                      <% "live_event" -> %>
                        <div class="flex items-center justify-center">
                          <span class="text-4xl">🎤</span>
                        </div>
                      <% "book" -> %>
                        <div class="flex items-center justify-center">
                          <span class="text-4xl">📚</span>
                        </div>
                      <% "music" -> %>
                        <div class="flex items-center justify-center">
                          <span class="text-4xl">🎶</span>
                        </div>
                    <% end %>
                  </div>
                  <h3 class="text-lg font-medium text-gray-900"><%= project.title %></h3>
                  <div class="mt-2 flex items-center text-sm text-gray-500">
                    <span class="capitalize"><%= project.type %></span>
                    <span class="mx-2">•</span>
                    <span class="capitalize"><%= project.status %></span>
                  </div>
                  <p class="text-sm text-gray-500">
                    Last updated: <%= Calendar.strftime(project.updated_at, "%B %d, %Y") %>
                  </p>
                </div>
              </.link>
            <% end %>
          </div>
        </div>
      </main>
    </div>
    """
  end
end
