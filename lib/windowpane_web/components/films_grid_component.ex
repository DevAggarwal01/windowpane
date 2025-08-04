defmodule WindowpaneWeb.FilmsGridComponent do
  use WindowpaneWeb, :live_component

  alias Windowpane.Projects
  alias Windowpane.Uploaders.CoverUploader

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(%{project_ids: project_ids} = assigns, socket) do
    # Filter to only get published project IDs
    published_project_ids = Projects.get_published_project_ids(project_ids)

    # Handle optional expired_status list
    expired_status = Map.get(assigns, :expired_status, [])

    # Handle optional ownership_ids list for custom linking (used in library)
    ownership_ids = Map.get(assigns, :ownership_ids, [])

    # Create a map of project_id -> expired status for easy lookup
    expired_map = if length(expired_status) == length(project_ids) do
      project_ids
      |> Enum.zip(expired_status)
      |> Enum.into(%{})
    else
      %{}
    end

    # Create a map of project_id -> ownership_id for custom linking
    ownership_map = if length(ownership_ids) == length(project_ids) do
      project_ids
      |> Enum.zip(ownership_ids)
      |> Enum.into(%{})
    else
      %{}
    end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:published_project_ids, published_project_ids)
     |> assign(:expired_map, expired_map)
     |> assign(:ownership_map, ownership_map)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <!-- Films Grid -->
      <%= if @published_project_ids == [] do %>
        <!-- Empty State -->
        <div class="text-center py-16">
          <div class="mx-auto h-24 w-24 text-gray-400 mb-4">
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2h4a1 1 0 110 2h-1v14a2 2 0 01-2 2H6a2 2 0 01-2-2V6H3a1 1 0 110-2h4z"></path>
            </svg>
          </div>
        </div>
      <% else %>
        <!-- Films Grid with White Grid Lines -->
        <div class="p-8 bg-black">
          <style>
            .films-grid {
              display: grid;
              grid-template-columns: repeat(2, 1fr);
              background-color: black;
              border-top: 2px solid white;
            }

            @media (min-width: 640px) {
              .films-grid {
                grid-template-columns: repeat(3, 1fr);
              }
            }

            @media (min-width: 768px) {
              .films-grid {
                grid-template-columns: repeat(4, 1fr);
              }
            }

            @media (min-width: 1024px) {
              .films-grid {
                grid-template-columns: repeat(5, 1fr);
              }
            }

            @media (min-width: 1280px) {
              .films-grid {
                grid-template-columns: repeat(6, 1fr);
              }
            }

            .film-item {
              background-color: black;
              transition: all 0.15s ease-in-out;
              border-right: 2px solid white;
              border-bottom: 2px solid white;
            }

            .film-item:hover {
              transform: scale(1.05);
              border: 2px solid white;
              z-index: 10;
              position: relative;
            }

            /* Remove right border from last column items */
            .film-item:nth-child(2n) {
              border-right: none;
            }

            @media (min-width: 640px) {
              .film-item:nth-child(2n) {
                border-right: 2px solid white;
              }
              .film-item:nth-child(3n) {
                border-right: none;
              }
            }

            @media (min-width: 768px) {
              .film-item:nth-child(3n) {
                border-right: 2px solid white;
              }
              .film-item:nth-child(4n) {
                border-right: none;
              }
            }

            @media (min-width: 1024px) {
              .film-item:nth-child(4n) {
                border-right: 2px solid white;
              }
              .film-item:nth-child(5n) {
                border-right: none;
              }
            }

            @media (min-width: 1280px) {
              .film-item:nth-child(5n) {
                border-right: 2px solid white;
              }
              .film-item:nth-child(6n) {
                border-right: none;
              }
            }

            /* Add left border to the first item (top-left cell) */
            .film-item:first-child {
              border-left: 2px solid white;
            }

            /* Add right border to the top-right cell */
            .film-item:nth-child(2) {
              border-right: 2px solid white;
            }

            @media (min-width: 640px) {
              .film-item:nth-child(3) {
                border-right: 2px solid white;
              }
            }

            @media (min-width: 768px) {
              .film-item:nth-child(4) {
                border-right: 2px solid white;
              }
            }

            @media (min-width: 1024px) {
              .film-item:nth-child(5) {
                border-right: 2px solid white;
              }
            }

            @media (min-width: 1280px) {
              .film-item:nth-child(6) {
                border-right: 2px solid white;
              }
            }
          </style>

          <div class="films-grid">
            <%= for project_id <- @published_project_ids do %>
              <% ownership_id = Map.get(@ownership_map, project_id) %>
              <% is_expired = Map.get(@expired_map, project_id, false) %>
              <% link_path = if !ownership_id || is_expired, do: ~p"/info?trailer_id=#{project_id}", else: ~p"/watch?id=#{ownership_id}" %>

              <.link patch={link_path} class="group film-item">
                <!-- Cover -->
                <div class="aspect-square relative overflow-hidden bg-black">
                  <%= if CoverUploader.cover_exists?(%{id: project_id}) do %>
                    <img
                      src={CoverUploader.cover_url(%{id: project_id})}
                      alt="Film cover"
                      class={"w-full h-full object-cover #{if Map.get(@expired_map, project_id, false), do: "opacity-50", else: ""}"}
                      loading="lazy"
                    />
                  <% else %>
                    <div class={"flex items-center justify-center w-full h-full #{if Map.get(@expired_map, project_id, false), do: "opacity-50", else: ""}"}>
                      <span class="text-4xl">🎬</span>
                    </div>
                  <% end %>

                  <!-- Expired overlay -->
                  <%= if Map.get(@expired_map, project_id, false) do %>
                    <div class="absolute inset-0 bg-black bg-opacity-50 flex items-center justify-center">
                      <span class="bg-red-600 text-white px-2 py-1 rounded text-sm font-medium">
                        EXPIRED
                      </span>
                    </div>
                  <% end %>
                </div>
              </.link>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
