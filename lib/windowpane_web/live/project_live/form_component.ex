defmodule WindowpaneWeb.ProjectLive.FormComponent do
  use WindowpaneWeb, :live_component

  alias Windowpane.Projects

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold mb-8"><%= @title %></h2>

      <.form
        for={@form}
        id="project-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-6">
          <div>
            <.input field={@form[:title]} type="text" label="Title" required />
          </div>

          <div>
            <.input field={@form[:description]} type="textarea" label="Description" required />
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <.input
                field={@form[:premiere_date]}
                type="datetime-local"
                label="Premiere Date"
                required
              />
            </div>
            <div>
              <.input
                field={@form[:premiere_price]}
                type="number"
                label="Premiere Price"
                step="0.01"
                min="0"
              />
            </div>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <.input
                field={@form[:rental_price]}
                type="number"
                label="Rental Price"
                step="0.01"
                min="0"
                required
              />
            </div>
            <div>
              <.input
                field={@form[:rental_window_hours]}
                type="number"
                label="Rental Window (hours)"
                min="1"
                required
              />
            </div>
          </div>

          <div>
            <.input
              field={@form[:purchase_price]}
              type="number"
              label="Purchase Price"
              step="0.01"
              min="0"
              required
            />
          </div>
        </div>

        <div class="mt-6 flex justify-end gap-4">
          <.button
            type="button"
            phx-click="cancel"
            phx-target={@myself}
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            Cancel
          </.button>
          <.button
            type="submit"
            phx-disable-with="Saving..."
            class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            Save Project
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{project: project} = assigns, socket) do
    changeset = Projects.change_project(project)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"project" => project_params}, socket) do
    changeset =
      socket.assigns.project
      |> Projects.change_project(project_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"project" => project_params}, socket) do
    save_project(socket, socket.assigns.action, project_params)
  end

  def handle_event("cancel", _, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.patch)}
  end

  defp save_project(socket, :edit, project_params) do
    case Projects.update_project(socket.assigns.project, project_params) do
      {:ok, project} ->
        notify_parent({:saved, project})

        {:noreply,
         socket
         |> put_flash(:info, "Project updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
