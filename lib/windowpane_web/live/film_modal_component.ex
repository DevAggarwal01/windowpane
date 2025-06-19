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
            <mux-player
              playback-id="XamuNYpAzCOw7MVac302qibSwGfIm3hKVwisAl1i6RN4"
              placeholder="https://f004.backblazeb2.com/file/videocoverlibrary/1/cover"
              playback-token="eyJhbGciOiJSUzI1NiJ9.eyJraWQiOiJDc2pxY1lxRENaZnNTcHB1ekg4UEJQaE9yMUlMNjAyUk0yWm9XZTNnZzAwQ0UiLCJhdWQiOiJ2Iiwic3ViIjoiWGFtdU5ZcEF6Q093N01WYWMzMDJxaWJTd0dmSW0zaEtWd2lzQWwxaTZSTjQiLCJleHAiOjE3NTA0NDc4OTZ9.ZWR6TGxu9d8XXj_7tm0Vki3TGA2US2cjZLzBY2ENSnLrC8TdfMYvho1go5MZRwbp-RlN5jNjCJXn6dljRXu1jK4UXMU6gueaCHthhYOmDe70-2Q3ZNP4BHb_L5azceVQ-oJH-rStt8XJsWHgQXsrBtiTTb-iP4UCar_ODj_xGF2Vk6HCg_2SiJ1Bjglmyb3crb2Hld7D6KXdbLB5XejtIt5xv8sUOC3veSnD0daO-E8DZCbO8I12djTdjf_n4jGIwdB3IL5rgqxyyObYNAzhTS2yxTwXJ8rP2eJpvVdjkapYWCBNpXAoga01hxnYxYLai2RziLOxp4YrFog0lEL7gw"
              stream-type="on-demand"
              style="--controls: none;"
              autoplay="any"
              title="Trailer"
            ></mux-player>
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
