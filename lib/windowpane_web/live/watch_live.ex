defmodule WindowpaneWeb.WatchLive do
  use WindowpaneWeb, :live_view

  alias Windowpane.OwnershipRecord
  alias Windowpane.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, project: nil, playback_token: nil, content_type: nil, ownership_record: nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    current_user = socket.assigns[:current_user]

    # Redirect to home if no user is logged in
    unless current_user do
      {:noreply, push_navigate(socket, to: ~p"/")}
    else
      try do
        ownership_id = String.to_integer(id)

        # Get the ownership record with project preloaded
        ownership_record = OwnershipRecord
        |> Repo.get(ownership_id)
        |> Repo.preload([project: [:film, :creator]])

        case ownership_record do
          nil ->
            # Ownership record not found
            redirect_to_home(socket)

          ownership_record ->
            # Check 1: Verify current user owns this record
            if ownership_record.user_id != current_user.id do
              # User doesn't own this ownership record - redirect to film page
              redirect_to_film_page(socket, ownership_record.project.id)
            else
              # Check 2: Verify project type is film
              if ownership_record.project.type != "film" do
                # Not a film - redirect to film page
                redirect_to_film_page(socket, ownership_record.project.id)
              else
                # Check 3: Verify ownership is still active (not expired)
                if is_expired?(ownership_record) do
                  # Ownership expired - redirect to film page
                  redirect_to_film_page(socket, ownership_record.project.id)
                else
                  # All checks passed - set up the watch page
                  setup_watch_page(socket, ownership_record)
                end
              end
            end
        end
      rescue
        ArgumentError ->
          # Invalid ID format
          redirect_to_home(socket)
        Ecto.NoResultsError ->
          # Database error
          redirect_to_home(socket)
      end
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  # Helper function to check if ownership record is expired
  defp is_expired?(ownership_record) do
    now = DateTime.utc_now()
    DateTime.compare(ownership_record.expires_at, now) == :lt
  end

  # Helper function to redirect to home page
  defp redirect_to_home(socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  # Helper function to redirect to film page
  defp redirect_to_film_page(socket, film_id) do
    {:noreply, push_navigate(socket, to: ~p"/?id=#{film_id}")}
  end

  # Helper function to set up the watch page with valid ownership
  defp setup_watch_page(socket, ownership_record) do
    project = ownership_record.project

    # Determine what to play - prefer full film, fallback to trailer
    {playback_id, content_type, playback_token} =
      cond do
        project.film && project.film.film_playback_id && ownership_record.jwt_token ->
          # User owns the film and has JWT token - play full film
          {project.film.film_playback_id, "full", ownership_record.jwt_token}

        project.film && project.film.trailer_playback_id ->
          # Fallback to trailer (no JWT needed for trailers)
          trailer_token = Windowpane.MuxToken.generate_playback_token(project.film.trailer_playback_id)
          {project.film.trailer_playback_id, "trailer", trailer_token}

        true ->
          # No playable content
          {nil, "unavailable", nil}
      end

    socket =
      socket
      |> assign(:project, project)
      |> assign(:ownership_record, ownership_record)
      |> assign(:playback_token, playback_token)
      |> assign(:content_type, content_type)
      |> assign(:playback_id, playback_id)
      |> assign(:page_title, project.title)
      |> assign(:invalid_type, false)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= cond do %>
      <% @project && @playback_id && @playback_token -> %>
        <!-- Main Watch Container -->
        <div class="min-h-screen bg-gray-50">
          <!-- Main Content -->
          <div class="max-w-7xl mx-auto px-4 py-6">
            <div class="grid grid-cols-1 lg:grid-cols-4 gap-6">
              <!-- Left Column - Cover & Info -->
              <div class="lg:col-span-1">
                <div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
                  <!-- Film Cover -->
                  <div class="aspect-[3/4] bg-gray-100 relative">
                    <%= if Windowpane.Uploaders.CoverUploader.cover_exists?(@project) do %>
                      <img
                        src={Windowpane.Uploaders.CoverUploader.cover_url(@project)}
                        alt={"Cover for #{@project.title}"}
                        class="w-full h-full object-cover"
                      />
                    <% else %>
                      <div class="flex items-center justify-center w-full h-full">
                        <div class="text-center text-gray-400">
                          <span class="text-6xl mb-2 block">🎬</span>
                          <span class="text-sm font-medium">No Cover</span>
                        </div>
                      </div>
                    <% end %>
                  </div>

                  <!-- Film Details -->
                  <div class="p-4">
                    <h1 class="text-xl font-bold text-gray-900 mb-2"><%= @project.title %></h1>
                    <p class="text-gray-600 mb-3">By <%= @project.creator.name %></p>

                    <!-- Status Badge -->
                    <div class="flex items-center gap-2 mb-4">
                      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                        ✓ MOVIE
                      </span>
                    </div>

                    <!-- Film Info -->
                    <div class="space-y-2 text-sm">
                      <%= if @project.description && String.trim(@project.description) != "" do %>
                        <div>
                          <p class="text-gray-700 leading-relaxed">
                            <%= @project.description %>
                          </p>
                        </div>
                      <% end %>

                      <div class="pt-2 border-t border-gray-100">
                        <div class="space-y-1">
                          <div class="flex justify-between">
                            <span class="text-gray-500">Type:</span>
                            <span class="text-gray-800 capitalize"><%= @project.type %></span>
                          </div>
                          <%= if @project.premiere_date do %>
                            <div class="flex justify-between">
                              <span class="text-gray-500">Premiered:</span>
                              <span class="text-gray-800">
                                <%= Calendar.strftime(@project.premiere_date, "%B %Y") %>
                              </span>
                            </div>
                          <% end %>
                          <%= if @content_type == "full" do %>
                            <div class="flex justify-between">
                              <span class="text-gray-500">Status:</span>
                              <span class="text-green-600 font-medium">
                                <%= if is_expired?(@ownership_record) do %>
                                  Expired
                                <% else %>
                                  Expires <%= format_expires_at(@ownership_record.expires_at) %>
                                <% end %>
                              </span>
                            </div>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Middle Column - Video Player -->
              <div class="lg:col-span-3">
                <div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
                  <!-- Player Container -->
                  <div class="aspect-video bg-black relative">
                    <mux-player
                      playback-id={@playback_id}
                      playback-token={@playback_token}
                      stream-type="on-demand"
                      title={@project.title}
                      class="w-full h-full"
                    ></mux-player>
                  </div>
                </div>

                <!-- Additional Actions -->
                <%= if @content_type == "trailer" do %>
                  <div class="mt-4 p-4 bg-blue-50 rounded-lg border border-blue-200">
                    <div class="flex items-center justify-between">
                      <div>
                        <h3 class="text-lg font-medium text-blue-900">Want to watch the full film?</h3>
                        <p class="text-blue-700">This is just the trailer. Rent or purchase to watch the complete film.</p>
                      </div>
                      <.link
                        navigate={~p"/?id=#{@project.id}"}
                        class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-md font-medium hover:bg-blue-700 transition-colors"
                      >
                        View Film Details
                      </.link>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>

      <% @content_type == "unavailable" -> %>
        <!-- Content Unavailable -->
        <div class="min-h-screen bg-gray-50 flex items-center justify-center">
          <div class="text-center max-w-md mx-auto p-6">
            <div class="w-16 h-16 mx-auto mb-4 text-gray-400">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" class="w-full h-full">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">Content not available</h3>
            <p class="text-gray-600 mb-6">The video content for this film is not yet available for streaming.</p>
            <.link
              navigate={~p"/library"}
              class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-md font-medium hover:bg-blue-700 transition-colors"
            >
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
              Back to Library
            </.link>
          </div>
        </div>

      <% true -> %>
        <!-- Error State -->
        <div class="min-h-screen bg-gray-50 flex items-center justify-center">
          <div class="text-center max-w-md mx-auto p-6">
            <div class="w-16 h-16 mx-auto mb-4 text-gray-400">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" class="w-full h-full">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.232 15.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">Invalid URL</h3>
            <p class="text-gray-600 mb-6">The requested content could not be found or you don't have access to it.</p>
            <.link
              navigate={~p"/"}
              class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-md font-medium hover:bg-blue-700 transition-colors"
            >
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
              Back to Browse
            </.link>
          </div>
        </div>
    <% end %>
    """
  end

  # Helper function to format expiration time
  defp format_expires_at(expires_at) do
    case DateTime.compare(expires_at, DateTime.utc_now()) do
      :lt -> "expired"
      _ ->
        hours_left = DateTime.diff(expires_at, DateTime.utc_now(), :hour)
        cond do
          hours_left < 1 -> "soon"
          hours_left < 24 -> "in #{hours_left} hours"
          true -> "in #{div(hours_left, 24)} days"
        end
    end
  end
end
