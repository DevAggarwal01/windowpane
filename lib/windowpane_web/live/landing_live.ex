defmodule WindowpaneWeb.LandingLive do
  use WindowpaneWeb, :live_view

  alias Windowpane.Projects
  alias Windowpane.MuxToken
  alias Windowpane.Ownership
  alias WindowpaneWeb.{LandingRowComponent, FilmModalComponent}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Discover Amazing Content")
      |> assign(:selected_film, nil)
      |> assign(:is_premiere, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    selected_film =
      case params["id"] do
        nil -> nil
        id ->
          # Fetch just the basic project info for the modal
          Projects.get_project_with_associations_and_creator_name!(String.to_integer(id))
      end

    # Check if current user owns this film and get ownership record ID
    {user_owns_film, ownership_id} = if selected_film && socket.assigns[:current_user] do
      if Ownership.user_owns_project?(socket.assigns.current_user.id, selected_film.id) do
        # Get the active ownership record ID
        ownership_record = Ownership.get_active_ownership_record(socket.assigns.current_user.id, selected_film.id)
        {true, ownership_record && ownership_record.id}
      else
        {false, nil}
      end
    else
      {false, nil}
    end

    # Generate trailer token efficiently using Projects.get_playback_id
    trailer_token = if selected_film && selected_film.type == "film" do
      case Projects.get_playback_id(selected_film, "trailer") do
        nil -> nil
        playback_id -> MuxToken.generate_playback_token(playback_id)
      end
    else
      nil
    end

    # Determine if this is a premiere based on the source
    is_premiere = params["source"] == "premieres"

    socket =
      socket
      |> assign(:selected_film, selected_film)
      |> assign(:trailer_token, trailer_token)
      |> assign(:user_owns_film, user_owns_film)
      |> assign(:ownership_id, ownership_id)
      |> assign(:is_premiere, is_premiere)

    {:noreply, socket}
  end

  def handle_event("fetch_project_ids", %{"keys" => keys}, socket) do
    # Get 10 random published project IDs
    IO.puts("DEBUG: fetch_project_ids event received with keys: #{inspect(keys)}")
    project_ids = Projects.get_random_published_project_ids(length(keys))

    project_ids =
      if length(project_ids) < length(keys) do
        Stream.cycle(project_ids) |> Enum.take(length(keys))
      else
        project_ids
      end

    # Push the project IDs to the client via a custom event
    {:noreply, push_event(socket, "project_ids_fetched", %{project_ids: project_ids, keys: keys})}
  end

  @impl true
  def handle_info(:close_film_modal, socket) do
    IO.puts("DEBUG: close_film_modal message received in LandingLive")
    # Close the modal by removing the id parameter from the URL
    {:noreply, push_patch(socket, to: ~p"/")}
  end

  @impl true
  def render(assigns) do
    ~H"""

    <main class="h-screen bg-white overflow-hidden">
      <div id="canvas-container" phx-hook="PixiCanvas" phx-update="ignore" data-logged-in={if @current_user, do: "true", else: "false"} class="w-full h-full"></div>

    </main>
    """
  end
end
