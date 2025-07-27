defmodule WindowpaneWeb.LibraryLive do
  use WindowpaneWeb, :live_view
  alias WindowpaneWeb.FilmsGridComponent

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user] || socket.assigns[:current_creator]
    is_creator = !!socket.assigns[:current_creator]

    # Get all ownership records for the user (both active and expired)
    ownership_records = if user do
      get_user_library(user.id)
    else
      []
    end

    # Extract project IDs and expired status
    project_ids = Enum.map(ownership_records, & &1.project.id)
    expired_status = Enum.map(ownership_records, &is_expired?/1)
    ownership_ids = Enum.map(ownership_records, & &1.id)

    {:ok, assign(socket,
      project_ids: project_ids,
      expired_status: expired_status,
      ownership_ids: ownership_ids,
      page_title: "My Library"
    )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Main Content -->
    <main class="min-h-screen w-full px-4 py-6" style="background-color: #000000;">
      <!-- Films Grid -->
      <.live_component
        module={FilmsGridComponent}
        id="library-films-grid"
        project_ids={@project_ids}
        expired_status={@expired_status}
        ownership_ids={@ownership_ids}
      />
    </main>
    """
  end

  # Private helper functions

  defp get_user_library(user_id) do
    import Ecto.Query
    alias Windowpane.Repo
    alias Windowpane.OwnershipRecord

    # Get all ownership records for user, ordered by most recent expiration first
    from(ownership in OwnershipRecord,
      where: ownership.user_id == ^user_id,
      order_by: [desc: ownership.expires_at],
      preload: [:project]
    )
    |> Repo.all()
  end

  defp is_expired?(ownership) do
    now = DateTime.utc_now()
    DateTime.compare(ownership.expires_at, now) == :lt
  end
end
