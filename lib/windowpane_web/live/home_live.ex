defmodule WindowpaneWeb.HomeLive do
  use WindowpaneWeb, :live_view

  import WindowpaneWeb.NavComponents

  alias Windowpane.PricingCalculator
  alias Windowpane.Uploaders.CoverUploader

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
      Windowpane.Projects.list_projects(socket.assigns.current_creator.id)
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
          "rental_window_hours" => 48
        }

        case Windowpane.Projects.create_project(project_params) do
          {:ok, project} ->
            {:noreply,
             socket
             |> put_flash(:info, "Project created successfully!")
             |> redirect(to: ~p"/#{project.id}")}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Error creating project. Please try again.")
             |> assign(show_project_dropdown: false)}
        end

      "live_event" ->
        # Calculate initial creator cuts using pricing calculator
        premiere_price = 1.00
        rental_price = 5.00

        premiere_creator_cut = PricingCalculator.calculate_creator_cut(premiere_price)
        rental_creator_cut = PricingCalculator.calculate_creator_cut(rental_price)

        project_params = %{
          "title" => "New Live Stream",
          "description" => "A new live stream project",
          "type" => type,
          "creator_id" => socket.assigns.current_creator.id,
          "status" => "draft",
          "premiere_date" => DateTime.utc_now() |> DateTime.add(7, :day),
          "premiere_price" => Decimal.new("1.00"),
          "premiere_creator_cut" => Decimal.new(to_string(premiere_creator_cut)),
          "rental_price" => Decimal.new("5.00"),
          "rental_creator_cut" => Decimal.new(to_string(rental_creator_cut)),
          "rental_window_hours" => 24
        }

        case Windowpane.Projects.create_project(project_params) do
          {:ok, project} ->
            # Also create the live stream record with recording enabled by default
            live_stream_params = %{
              "project_id" => project.id,
              "status" => "idle",
              "recording" => true,  # Enable recording by default for live streams
              "expected_duration_minutes" => 60
            }

            case Windowpane.Projects.create_live_stream(live_stream_params) do
              {:ok, _live_stream} ->
                {:noreply,
                 socket
                 |> put_flash(:info, "Live stream project created successfully!")
                 |> redirect(to: ~p"/#{project.id}")}

              {:error, _changeset} ->
                # If live stream creation fails, we should probably delete the project
                # or at least show an error, but for now just show error
                {:noreply,
                 socket
                 |> put_flash(:error, "Error creating live stream. Please try again.")
                 |> assign(show_project_dropdown: false)}
            end

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Error creating live stream project. Please try again.")
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

    case Windowpane.Projects.create_project(project_params) do
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

  # Banner cropper event handlers (to prevent crashes if events are sent here accidentally)
  def handle_event("show_banner_cropper_modal", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("hide_banner_cropper_modal", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("set_banner_uploading", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("banner_upload_success", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("banner_upload_error", _params, socket) do
    {:noreply, socket}
  end

  # Cover cropper event handlers (to prevent crashes if events are sent here accidentally)
  def handle_event("show_cropper_modal", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("hide_cropper_modal", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("set_uploading", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("upload_success", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("upload_error", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:project_deleted}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Project deleted successfully")
     |> redirect(to: ~p"/")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-black">
      <.main_header current_path={@current_path} is_creator={@is_creator} />

      <%= if @error_message do %>
        <div class="fixed top-4 right-4 bg-red-50 text-red-700 px-4 py-3 rounded-lg shadow-lg flex items-center z-50">
          <svg class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span><%= @error_message %></span>
        </div>
      <% end %>

      <%= if @show_film_modal && @is_creator do %>
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-50">
          <div class="fixed inset-0 z-50 overflow-y-auto">
            <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
              <div class="relative transform overflow-hidden rounded-lg bg-white px-4 pb-4 pt-5 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg sm:p-6">
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

      <%= if @show_billing_popup && @is_creator do %>
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
        <%= if @is_creator do %>
          <!-- Projects Section -->
          <div class="mb-8">
            <div class="flex items-center gap-3 mb-4">
              <h2 class="text-xl font-semibold text-white">My Projects</h2>
              <div class="relative" phx-click-away="close_dropdown">
                <button
                  phx-click="toggle_project_dropdown"
                  class="w-10 h-10 bg-white rounded-full shadow-sm hover:shadow-md transition-all duration-200 hover:scale-105 flex items-center justify-center"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                  </svg>
                </button>

                <%= if @show_project_dropdown do %>
                  <div class="absolute right-0 top-full mt-2 z-10 w-64 bg-white rounded-lg shadow-xl border border-gray-200 transform transition-all duration-200 ease-out">
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
                        <span>Live Stream</span>
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
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
              <!-- Project Cards -->
              <%= for project <- @projects do %>
                <.link navigate={~p"/#{project.id}"} class="block group">
                  <div class="bg-white rounded-lg shadow-sm hover:shadow-md transition-all duration-200 hover:scale-105 overflow-hidden">
                    <div class="aspect-square relative overflow-hidden bg-gray-200">
                      <%= if CoverUploader.cover_exists?(project) do %>
                        <img src={CoverUploader.cover_url(project)} alt={project.title} class="w-full h-full object-cover" />
                      <% else %>
                        <div class="flex items-center justify-center w-full h-full">
                          <span class="text-gray-500 text-sm">No cover</span>
                        </div>
                      <% end %>

                      <!-- Type overlay icon in top right corner -->
                      <div class="absolute top-2 right-2 w-8 h-8 bg-black bg-opacity-60 rounded-full flex items-center justify-center">
                        <%= case project.type do %>
                          <% "film" -> %>
                            <span class="text-white text-sm">🎞️</span>
                          <% "tv_show" -> %>
                            <span class="text-white text-sm">🎬</span>
                          <% "live_event" -> %>
                            <span class="text-white text-sm">🎤</span>
                          <% "book" -> %>
                            <span class="text-white text-sm">📚</span>
                          <% "music" -> %>
                            <span class="text-white text-sm">🎶</span>
                        <% end %>
                      </div>

                      <!-- Title overlay on hover -->
                      <div class="absolute inset-0 bg-black bg-opacity-75 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                        <h3 class="text-lg font-medium text-white text-center px-4"><%= project.title %></h3>
                      </div>
                    </div>
                  </div>
                </.link>
              <% end %>
            </div>
          </div>
        <% else %>
          <!-- User Dashboard -->
          <div class="max-w-7xl mx-auto">
            <h1 class="text-3xl font-bold mb-8">Welcome Back!</h1>

            <!-- Continue Watching Section -->
            <section class="mb-12">
              <h2 class="text-2xl font-semibold mb-6">Continue Watching</h2>
              <div class="bg-white rounded-lg shadow-sm p-6">
                <p class="text-gray-500">You haven't started watching anything yet.</p>
                <.link
                  navigate={~p"/browse"}
                  class="mt-4 inline-flex items-center text-sm font-medium text-blue-600 hover:text-blue-500"
                >
                  Browse content
                  <svg class="ml-1 h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd" />
                  </svg>
                </.link>
              </div>
            </section>

            <!-- My Library Section -->
            <section class="mb-12">
              <h2 class="text-2xl font-semibold mb-6">My Library</h2>
              <div class="bg-white rounded-lg shadow-sm p-6">
                <p class="text-gray-500">Your library is empty.</p>
                <.link
                  navigate={~p"/browse"}
                  class="mt-4 inline-flex items-center text-sm font-medium text-blue-600 hover:text-blue-500"
                >
                  Discover content
                  <svg class="ml-1 h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd" />
                  </svg>
                </.link>
              </div>
            </section>

            <!-- Recommended Section -->
            <section>
              <h2 class="text-2xl font-semibold mb-6">Recommended for You</h2>
              <div class="bg-white rounded-lg shadow-sm p-6">
                <p class="text-gray-500">We're preparing your personalized recommendations.</p>
                <.link
                  navigate={~p"/browse"}
                  class="mt-4 inline-flex items-center text-sm font-medium text-blue-600 hover:text-blue-500"
                >
                  Browse trending content
                  <svg class="ml-1 h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd" />
                  </svg>
                </.link>
              </div>
            </section>
          </div>
        <% end %>
      </main>
    </div>
    """
  end
end
