defmodule WindowpaneWeb.LibraryLive do
  use WindowpaneWeb, :live_view
  alias Windowpane.Uploaders.CoverUploader

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

    {:ok, assign(socket,
      user: user,
      is_creator: is_creator,
      ownership_records: ownership_records,
      selected_project: nil,
      trailer_token: nil,
      page_title: "My Library"
    )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {selected_project, ownership_id} =
      case params["id"] do
        nil -> {nil, nil}
        id ->
          ownership_id = String.to_integer(id)
          # Find the ownership record by ID (ensures user owns it)
          ownership_record = Enum.find(socket.assigns.ownership_records, fn ownership ->
            ownership.id == ownership_id
          end)

          if ownership_record do
            # Load the project with film data for the modal (even if expired)
            project = get_project_with_film(ownership_record.project.id)
            {project, ownership_id}
          else
            {nil, nil}
          end
      end

    # Generate trailer token if needed
    trailer_token = if selected_project && selected_project.film && selected_project.film.trailer_playback_id do
      alias Windowpane.MuxToken
      MuxToken.generate_playback_token(selected_project.film.trailer_playback_id)
    else
      nil
    end

    # Determine if user currently owns (has active access to) the film
    user_owns_film = if selected_project && ownership_id do
      ownership_record = Enum.find(socket.assigns.ownership_records, fn ownership ->
        ownership.id == ownership_id
      end)
      ownership_record && !is_expired?(ownership_record)
    else
      false
    end

    {:noreply, assign(socket,
      selected_project: selected_project,
      ownership_id: ownership_id,
      trailer_token: trailer_token,
      user_owns_film: user_owns_film
    )}
  end

  @impl true
  def handle_info(:close_film_modal, socket) do
    IO.puts("DEBUG: close_film_modal message received in LibraryLive")
    # Close the modal by removing the id parameter from the URL
    {:noreply, push_patch(socket, to: ~p"/library")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Film Modal Component -->
    <%= if @selected_project do %>
      <.live_component
        module={WindowpaneWeb.FilmModalComponent}
        id="film-modal"
        film={@selected_project}
        trailer_token={@trailer_token}
        current_user={@user}
        is_creator={@is_creator}
        user_owns_film={@user_owns_film}
        ownership_id={@ownership_id}
      />
    <% end %>

    <!-- Main Content -->
    <main class="max-w-7xl mx-auto px-4 py-6">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-white mb-2">My Library</h1>
        <p class="text-gray-400">Your rented films</p>
      </div>

      <!-- Content Area -->
      <%= if length(@ownership_records) > 0 do %>
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-6">
          <%= for ownership <- @ownership_records do %>
            <div class="bg-gray-800 rounded-lg overflow-hidden hover:bg-gray-700 transition-colors">
              <%= if is_expired?(ownership) do %>
                <!-- Expired - open film modal to allow re-renting -->
                <.link patch={~p"/library?id=#{ownership.id}"} class="block cursor-pointer">
                  <div class="aspect-[2/3] bg-gray-700 overflow-hidden relative">
                    <%= if CoverUploader.cover_exists?(ownership.project) do %>
                      <img
                        src={CoverUploader.cover_url(ownership.project)}
                        alt={"Cover image for #{ownership.project.title}"}
                        class="w-full h-full object-cover opacity-50"
                      />
                    <% else %>
                      <div class="flex items-center justify-center w-full h-full opacity-50">
                        <span class="text-4xl">🎞️</span>
                      </div>
                    <% end %>
                    <!-- Expired overlay -->
                    <div class="absolute inset-0 bg-black bg-opacity-50 flex items-center justify-center">
                      <span class="bg-red-600 text-white px-2 py-1 rounded text-sm font-medium">
                        EXPIRED
                      </span>
                    </div>
                  </div>
                  <div class="p-3">
                    <h3 class="text-sm font-medium text-gray-400 truncate mb-2">
                      <%= ownership.project.title %>
                    </h3>
                    <div class="flex items-center justify-between">
                      <span class="inline-flex items-center rounded-md px-2 py-1 text-xs font-medium bg-red-50 text-red-700">
                        Expired
                      </span>
                      <span class="text-xs text-gray-500">
                        <%= format_expires_at(ownership.expires_at) %>
                      </span>
                    </div>
                  </div>
                </.link>
              <% else %>
                <!-- Active - open film modal -->
                <.link patch={~p"/library?id=#{ownership.id}"} class="block cursor-pointer">
                  <div class="aspect-[2/3] bg-gray-700 overflow-hidden">
                    <%= if CoverUploader.cover_exists?(ownership.project) do %>
                      <img
                        src={CoverUploader.cover_url(ownership.project)}
                        alt={"Cover image for #{ownership.project.title}"}
                        class="w-full h-full object-cover"
                      />
                    <% else %>
                      <div class="flex items-center justify-center w-full h-full">
                        <span class="text-4xl">🎞️</span>
                      </div>
                    <% end %>
                  </div>
                  <div class="p-3">
                    <h3 class="text-sm font-medium text-white truncate mb-2">
                      <%= ownership.project.title %>
                    </h3>
                    <div class="flex items-center justify-between">
                      <span class="inline-flex items-center rounded-md px-2 py-1 text-xs font-medium bg-green-50 text-green-700">
                        Active
                      </span>
                      <span class="text-xs text-gray-400">
                        <%= format_expires_at(ownership.expires_at) %>
                      </span>
                    </div>
                  </div>
                </.link>
              <% end %>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="bg-gray-800 rounded-lg p-6">
          <div class="text-center py-16">
            <div class="mx-auto h-24 w-24 text-gray-400 mb-4">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path>
              </svg>
            </div>
            <h3 class="text-lg font-medium text-white mb-2">Your library is empty</h3>
            <p class="text-gray-400 mb-6">Start building your collection by purchasing or renting films.</p>
            <.link
              navigate={~p"/"}
              class="inline-flex items-center px-4 py-2 bg-accent text-white rounded-md font-medium hover:bg-highlight transition-colors"
            >
              Browse Films
              <svg class="ml-2 w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7l5 5m0 0l-5 5m5-5H6" />
              </svg>
            </.link>
          </div>
        </div>
      <% end %>
    </main>
    """
  end

  # Private helper functions

  defp get_project_with_film(project_id) do
    alias Windowpane.Projects

    try do
      Projects.get_project_with_film_and_creator_name!(project_id)
    rescue
      Ecto.NoResultsError -> nil
    end
  end

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

  defp format_expires_at(expires_at) do
    case DateTime.compare(expires_at, DateTime.utc_now()) do
      :lt -> "Expired"
      _ ->
        hours_left = DateTime.diff(expires_at, DateTime.utc_now(), :hour)
        cond do
          hours_left < 1 -> "Expires soon"
          true -> "#{hours_left} hours left"
        end
    end
  end
end
