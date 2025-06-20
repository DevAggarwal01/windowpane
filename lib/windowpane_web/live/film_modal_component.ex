defmodule WindowpaneWeb.FilmModalComponent do
  use WindowpaneWeb, :live_component

  # Helper function to format price
  defp format_price(nil), do: "Free"
  defp format_price(price) when is_struct(price, Decimal), do: "$#{Decimal.to_string(price)}"

  @impl true
  def mount(socket) do
    {:ok, assign(socket, show_login_message: false, show_rent_confirmation: false, show_buy_confirmation: false)}
  end

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

          <!-- Trailer Player -->
          <div class="relative w-full aspect-video bg-gray-800">
            <%= if @film.film && @film.film.trailer_playback_id && @trailer_token do %>
              <mux-player
                playback-id={@film.film.trailer_playback_id}
                poster={if Windowpane.Uploaders.BannerUploader.banner_exists?(@film), do: Windowpane.Uploaders.BannerUploader.banner_url(@film), else: nil}
                playback-token={@trailer_token}
                stream-type="on-demand"
                style="--bottom-controls: none;"
                title="Trailer"
                class="w-full h-full"
              ></mux-player>
            <% else %>
              <!-- Static image fallback -->
              <%= cond do %>
                <% Windowpane.Uploaders.BannerUploader.banner_exists?(@film) -> %>
                  <img
                    src={Windowpane.Uploaders.BannerUploader.banner_url(@film)}
                    alt={"Banner for #{@film.title}"}
                    class="w-full h-full object-cover"
                  />
                <% Windowpane.Uploaders.CoverUploader.cover_exists?(@film) -> %>
                  <img
                    src={Windowpane.Uploaders.CoverUploader.cover_url(@film)}
                    alt={"Cover for #{@film.title}"}
                    class="w-full h-full object-cover"
                  />
                <% true -> %>
                  <div class="w-full h-full flex items-center justify-center text-gray-400">
                    <div class="text-center">
                    <svg class="w-16 h-16 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                    </svg>
                      <p>No image available</p>
                    </div>
                  </div>
                <% end %>

              <!-- Watch Film Button (only if no trailer but has full film) -->
              <%= if @film.film && !@film.film.trailer_playback_id && @film.film.film_playback_id do %>
                <.link
                  navigate={~p"/watch?id=#{@film.id}"}
                  class="absolute bottom-4 right-4 bg-black bg-opacity-70 hover:bg-opacity-90 px-3 py-2 rounded cursor-pointer transition-all duration-300 hover:scale-105 hover:shadow-lg"
                >
                  <div class="flex items-center text-white text-sm font-medium">
                    <svg class="w-4 h-4 mr-1 transition-transform duration-300 group-hover:scale-110" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M8 5v10l8-5-8-5z"/>
                    </svg>
                    Watch Film
              </div>
                </.link>
              <% end %>
            <% end %>
          </div>

          <!-- Content Area -->
          <div class="bg-black text-white p-6">
            <!-- Title and Actions Row -->
            <div class="flex items-start justify-between mb-4">
              <div class="flex-1">
                <h1 class="text-2xl font-bold text-white mb-2">
                  <%= @film.title %>
                </h1>
                <p class="text-gray-300 mb-4">
                  By <%= @film.creator.name %>
                </p>
              </div>

              <!-- Action Buttons -->
              <div class="flex space-x-3 ml-6">
                <button
                  type="button"
                  class="inline-flex flex-col items-center px-4 py-3 bg-white text-black font-semibold rounded hover:bg-gray-200 transition-colors"
                  phx-click="rent_film"
                  phx-target={@myself}
                >
                  <span class="text-sm">Rent movie</span>
                  <span class="text-lg font-bold"><%= format_price(@film.rental_price) %></span>
                </button>

                <button
                  type="button"
                  class="inline-flex flex-col items-center px-4 py-3 bg-white text-black font-semibold rounded hover:bg-gray-200 transition-colors"
                  phx-click="buy_film"
                  phx-target={@myself}
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

      <!-- Login Message Modal -->
      <%= if @show_login_message do %>
        <div class="fixed inset-0 z-60 overflow-y-auto">
          <div class="fixed inset-0 bg-black bg-opacity-50"></div>
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative bg-white rounded-lg p-6 max-w-md w-full">
              <div class="text-center">
                <h3 class="text-lg font-medium text-gray-900 mb-4">Uh oh, please log in or sign up</h3>
                <p class="text-gray-600 mb-6">You need to be logged in to rent or purchase films.</p>
                <div class="flex space-x-3 justify-center">
                  <.link
                    href={~p"/users/log_in?redirect=#{URI.encode("/?id=#{@film.id}")}"}
                    class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 font-medium"
                  >
                    Log in
                  </.link>
                  <.link
                    href={~p"/users/register?redirect=#{URI.encode("/?id=#{@film.id}")}"}
                    class="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 font-medium"
                  >
                    Sign up
                  </.link>
                </div>
                <button
                  type="button"
                  class="mt-4 text-gray-500 hover:text-gray-700"
                  phx-click="close_login_message"
                  phx-target={@myself}
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Rent Confirmation Modal -->
      <%= if @show_rent_confirmation do %>
        <div class="fixed inset-0 z-60 overflow-y-auto">
          <div class="fixed inset-0 bg-black bg-opacity-50"></div>
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative bg-white rounded-lg p-6 max-w-md w-full">
              <div class="text-center">
                <h3 class="text-lg font-medium text-gray-900 mb-4">Are you sure?</h3>
                <p class="text-gray-600 mb-6">
                  Do you want to rent "<%= @film.title %>" for <%= format_price(@film.rental_price) %>?
                </p>
                <div class="flex space-x-3 justify-center">
                  <button
                    type="button"
                    class="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 font-medium"
                    phx-click="confirm_rent"
                    phx-target={@myself}
                  >
                    Yes, rent it
                  </button>
                  <button
                    type="button"
                    class="px-4 py-2 bg-gray-600 text-white rounded hover:bg-gray-700 font-medium"
                    phx-click="cancel_rent"
                    phx-target={@myself}
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Buy Confirmation Modal -->
      <%= if @show_buy_confirmation do %>
        <div class="fixed inset-0 z-60 overflow-y-auto">
          <div class="fixed inset-0 bg-black bg-opacity-50"></div>
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative bg-white rounded-lg p-6 max-w-md w-full">
              <div class="text-center">
                <h3 class="text-lg font-medium text-gray-900 mb-4">Are you sure?</h3>
                <p class="text-gray-600 mb-6">
                  Do you want to buy "<%= @film.title %>" for <%= format_price(@film.purchase_price) %>?
                </p>
                <div class="flex space-x-3 justify-center">
                  <button
                    type="button"
                    class="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 font-medium"
                    phx-click="confirm_buy"
                    phx-target={@myself}
                  >
                    Yes, buy it
                  </button>
                  <button
                    type="button"
                    class="px-4 py-2 bg-gray-600 text-white rounded hover:bg-gray-700 font-medium"
                    phx-click="cancel_buy"
                    phx-target={@myself}
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    # Use live_patch to remove the id parameter from URL
    {:noreply, push_patch(socket, to: "/")}
  end

  @impl true
  def handle_event("rent_film", _params, socket) do
    if socket.assigns.current_user do
      {:noreply, assign(socket, show_rent_confirmation: true)}
    else
      {:noreply, assign(socket, show_login_message: true)}
    end
  end

  @impl true
  def handle_event("buy_film", _params, socket) do
    if socket.assigns.current_user do
      {:noreply, assign(socket, show_buy_confirmation: true)}
    else
      {:noreply, assign(socket, show_login_message: true)}
    end
  end

  @impl true
  def handle_event("close_login_message", _params, socket) do
    {:noreply, assign(socket, show_login_message: false)}
  end

  @impl true
  def handle_event("confirm_rent", _params, socket) do
    # TODO: Implement actual rental logic here
    # For now, just close the confirmation
    {:noreply, assign(socket, show_rent_confirmation: false)}
  end

  @impl true
  def handle_event("cancel_rent", _params, socket) do
    {:noreply, assign(socket, show_rent_confirmation: false)}
  end

  @impl true
  def handle_event("confirm_buy", _params, socket) do
    # TODO: Implement actual purchase logic here
    # For now, just close the confirmation
    {:noreply, assign(socket, show_buy_confirmation: false)}
  end

  @impl true
  def handle_event("cancel_buy", _params, socket) do
    {:noreply, assign(socket, show_buy_confirmation: false)}
  end
end
