defmodule WindowpaneWeb.FilmModalComponent do
  use WindowpaneWeb, :live_component

  # Helper function to format price
  defp format_price(nil), do: "Free"
  defp format_price(price) when is_struct(price, Decimal), do: "$#{Decimal.to_string(price)}"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto" id="film-modal-backdrop">
      <!-- Background Overlay -->
      <div class="fixed inset-0 bg-black bg-opacity-75 transition-opacity" phx-click="close_modal" phx-target={@myself}></div>

      <!-- Modal Container -->
      <div class="flex min-h-full items-center justify-center p-4">
        <!-- Modal Content -->
        <div class="relative w-full max-w-4xl bg-black rounded-lg overflow-hidden shadow-xl">
          <!-- Close Button -->
          <button
            type="button"
            class="absolute top-4 right-4 z-10 rounded-full bg-black bg-opacity-50 p-2 text-white hover:bg-opacity-75 focus:outline-none focus:ring-2 focus:ring-white"
            phx-click="close_modal"
            phx-target={@myself}
          >
            <span class="sr-only">Close</span>
            <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          <!-- Trailer Area (placeholder for future implementation) -->
          <div class="relative w-full">
            <%= if @film.film && @film.film.trailer_playback_id && @trailer_token do %>
              <mux-player
                playback-id={@film.film.trailer_playback_id}
                placeholder={if Windowpane.Uploaders.BannerUploader.banner_exists?(@film), do: Windowpane.Uploaders.BannerUploader.banner_url(@film), else: nil}
                playback-token={@trailer_token}
                stream-type="on-demand"
                style="--controls: none;"
                autoplay="any"
                title="Trailer"
              ></mux-player>
            <% else %>
              <!-- Fallback when no trailer is available -->
              <div class="w-full aspect-video bg-gray-800 flex items-center justify-center">
                <%= if Windowpane.Uploaders.CoverUploader.cover_exists?(@film) do %>
                  <img
                    src={Windowpane.Uploaders.CoverUploader.cover_url(@film)}
                    alt={"Cover for #{@film.title}"}
                    class="w-full h-full object-cover"
                  />
                <% else %>
                  <div class="text-center text-gray-400">
                    <svg class="w-16 h-16 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                    </svg>
                    <p>No trailer available</p>
                  </div>
                <% end %>
              </div>
            <% end %>
            <div class="absolute top-4 left-4 text-white text-xl font-bold z-10 bg-black bg-opacity-60 px-4 py-2 rounded">
              <%= @film.title %>
            </div>
          </div>

          <!-- Content Area -->
          <div class="bg-black text-white p-6">
            <!-- Title and Actions Row -->
            <div class="flex items-start justify-between mb-4">
              <div class="flex-1">
                <p class="text-gray-300 mb-4">
                  By <%= @film.creator.name %>
                </p>
              </div>

              <!-- Action Buttons -->
              <div class="flex space-x-3 ml-6">
                <button
                  type="button"
                  class="inline-flex flex-col items-center px-4 py-3 bg-white text-black font-semibold rounded hover:bg-gray-200 transition-colors"
                >
                  <span class="text-sm">Rent movie</span>
                  <span class="text-lg font-bold"><%= format_price(@film.rental_price) %></span>
                </button>

                <button
                  type="button"
                  class="inline-flex flex-col items-center px-4 py-3 bg-white text-black font-semibold rounded hover:bg-gray-200 transition-colors"
                >
                  <span class="text-sm">Buy</span>
                  <span class="text-lg font-bold"><%= format_price(@film.purchase_price) %></span>
                </button>
              </div>
            </div>

            <!-- Description -->
            <div class="mb-6">
              <p class="text-gray-300 leading-relaxed text-lg">
                <%= if @film.description && String.trim(@film.description) != "" do %>
                  <%= @film.description %>
                <% else %>
                  <span class="italic text-gray-500">No description available for this film.</span>
                <% end %>
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    # Use live_patch to remove the id parameter from URL
    {:noreply, push_patch(socket, to: "/")}
  end
end
