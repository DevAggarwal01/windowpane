defmodule AuroraWeb.ProjectLive.New do
  use AuroraWeb, :live_view

  alias Aurora.Projects

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      page_title: "New Project",
      project_type: nil,
      error_message: nil,
      form_step: 1,
      project_details: %{
        "title" => "",
        "description" => ""
      }
    )}
  end

  @impl true
  def handle_event("select_type", %{"type" => type}, socket) do
    case type do
      "film" ->
        {:noreply, assign(socket,
          project_type: type,
          error_message: nil
        )}
      _ ->
        {:noreply, assign(socket,
          project_type: nil,
          error_message: "This project type is not supported yet. Coming soon!"
        )}
    end
  end

  def handle_event("next_step", params, socket) do
    next_step = socket.assigns.form_step + 1
    {:noreply, assign(socket,
      form_step: next_step,
      project_details: Map.merge(socket.assigns.project_details, params)
    )}
  end

  def handle_event("previous_step", _params, socket) do
    prev_step = max(1, socket.assigns.form_step - 1)
    {:noreply, assign(socket, form_step: prev_step)}
  end

  def handle_event("submit_project", params, socket) do
    project_params = socket.assigns.project_details
    |> Map.merge(params)
    |> Map.put("type", socket.assigns.project_type)
    |> Map.put("creator_id", socket.assigns.current_creator.id)
    |> Map.put("status", "draft")

    case Projects.create_project(project_params) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project created successfully!")
         |> redirect(to: ~p"/projects/#{project.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error creating project. Please check the form and try again.")
         |> assign(changeset: changeset)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex items-center gap-4 mb-8">
        <.link
          navigate={~p"/projects"}
          class="text-gray-600 hover:text-gray-900"
        >
          ← Back to projects
        </.link>
        <h1 class="text-3xl font-bold">New Project</h1>
      </div>

      <%= if @error_message do %>
        <div class="mb-6 bg-red-50 text-red-700 px-4 py-3 rounded-lg shadow-sm flex items-center">
          <svg class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span><%= @error_message %></span>
        </div>
      <% end %>

      <div class="bg-white rounded-lg shadow-lg">
        <%= if is_nil(@project_type) do %>
          <div class="p-6">
            <h2 class="text-xl font-semibold mb-4">Select Project Type</h2>
            <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
              <button
                phx-click="select_type"
                phx-value-type="film"
                class="flex flex-col items-center p-4 border-2 rounded-lg hover:border-blue-500 hover:bg-blue-50 transition-all"
              >
                <span class="text-3xl mb-2">🎞️</span>
                <span class="font-medium">Film</span>
              </button>
              <button
                phx-click="select_type"
                phx-value-type="tv_show"
                class="flex flex-col items-center p-4 border-2 rounded-lg hover:border-blue-500 hover:bg-blue-50 transition-all"
              >
                <span class="text-3xl mb-2">🎬</span>
                <span class="font-medium">TV Show</span>
              </button>
              <button
                phx-click="select_type"
                phx-value-type="live_event"
                class="flex flex-col items-center p-4 border-2 rounded-lg hover:border-blue-500 hover:bg-blue-50 transition-all"
              >
                <span class="text-3xl mb-2">🎤</span>
                <span class="font-medium">Live Event</span>
              </button>
              <button
                phx-click="select_type"
                phx-value-type="book"
                class="flex flex-col items-center p-4 border-2 rounded-lg hover:border-blue-500 hover:bg-blue-50 transition-all"
              >
                <span class="text-3xl mb-2">📚</span>
                <span class="font-medium">Book</span>
              </button>
              <button
                phx-click="select_type"
                phx-value-type="music"
                class="flex flex-col items-center p-4 border-2 rounded-lg hover:border-blue-500 hover:bg-blue-50 transition-all"
              >
                <span class="text-3xl mb-2">🎶</span>
                <span class="font-medium">Music</span>
              </button>
            </div>
          </div>
        <% else %>
          <div class="border-b border-gray-200">
            <div class="p-4">
              <div class="flex items-center space-x-2 text-sm text-gray-500">
                <button phx-click="select_type" phx-value-type="" class="hover:text-gray-700">
                  Change type
                </button>
                <span>•</span>
                <span>Step <%= @form_step %> of 3</span>
              </div>
            </div>
          </div>

          <div class="p-6">
            <%= case @form_step do %>
              <% 1 -> %>
                <form phx-submit="next_step" class="space-y-6">
                  <div>
                    <label for="title" class="block text-sm font-medium text-gray-700">
                      Title
                    </label>
                    <input
                      type="text"
                      name="title"
                      id="title"
                      value={@project_details["title"]}
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                      placeholder="Enter project title"
                      required
                    />
                  </div>
                  <div>
                    <label for="description" class="block text-sm font-medium text-gray-700">
                      Description
                    </label>
                    <textarea
                      name="description"
                      id="description"
                      rows="3"
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                      placeholder="Enter project description"
                      required
                    ><%= @project_details["description"] %></textarea>
                  </div>
                  <div class="flex justify-end">
                    <button
                      type="submit"
                      class="inline-flex justify-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-500"
                    >
                      Next
                    </button>
                  </div>
                </form>

              <% 2 -> %>
                <form phx-submit="next_step" class="space-y-6">
                  <div>
                    <label for="premiere_date" class="block text-sm font-medium text-gray-700">
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
                    <label for="premiere_price" class="block text-sm font-medium text-gray-700">
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
                    <label class="block text-sm font-medium text-gray-700">
                      Rental Configuration
                    </label>
                    <div class="grid grid-cols-2 gap-4">
                      <div>
                        <label for="rental_price" class="block text-sm font-medium text-gray-700">
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
                        <label for="rental_window_hours" class="block text-sm font-medium text-gray-700">
                          Access Window (hours)
                        </label>
                        <input
                          type="number"
                          name="rental_window_hours"
                          id="rental_window_hours"
                          min="1"
                          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                          placeholder="48"
                          required
                        />
                      </div>
                    </div>
                  </div>
                  <div>
                    <label for="purchase_price" class="block text-sm font-medium text-gray-700">
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
                  <div class="flex justify-between">
                    <button
                      type="button"
                      phx-click="previous_step"
                      class="inline-flex justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
                    >
                      Back
                    </button>
                    <button
                      type="submit"
                      class="inline-flex justify-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-500"
                    >
                      Next
                    </button>
                  </div>
                </form>

              <% 3 -> %>
                <form phx-submit="submit_project" class="space-y-6">
                  <div class="border-2 border-dashed border-gray-300 rounded-lg p-6">
                    <div class="text-center">
                      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                      </svg>
                      <div class="mt-4">
                        <label class="block text-sm font-medium text-gray-700">
                          Upload Trailer
                        </label>
                        <div class="mt-1 flex justify-center px-6 pt-5 pb-6">
                          <div class="space-y-1 text-center">
                            <div class="flex text-sm text-gray-600">
                              <label for="trailer" class="relative cursor-pointer rounded-md bg-white font-medium text-blue-600 focus-within:outline-none focus-within:ring-2 focus-within:ring-blue-500 focus-within:ring-offset-2 hover:text-blue-500">
                                <span>Upload a file</span>
                                <input id="trailer" name="trailer" type="file" class="sr-only" />
                              </label>
                              <p class="pl-1">or drag and drop</p>
                            </div>
                            <p class="text-xs text-gray-500">MP4, MOV up to 500MB</p>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                  <div class="flex justify-between">
                    <button
                      type="button"
                      phx-click="previous_step"
                      class="inline-flex justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
                    >
                      Back
                    </button>
                    <div class="flex space-x-3">
                      <button
                        type="submit"
                        class="inline-flex justify-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-500"
                      >
                        Create Project
                      </button>
                      <button
                        type="submit"
                        name="deploy"
                        value="true"
                        class="inline-flex justify-center rounded-md bg-green-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-green-500"
                      >
                        Create & Deploy
                      </button>
                    </div>
                  </div>
                </form>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
