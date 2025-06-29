defmodule WindowpaneWeb.FilmModalComponent do
  use WindowpaneWeb, :live_component

  alias Windowpane.{Repo, Ownership, Accounts, MuxToken}
  alias Windowpane.Uploaders.BannerUploader

  # Helper function to format price
  defp format_price(nil), do: "Free"
  defp format_price(price) when is_struct(price, Decimal), do: "$#{Decimal.to_string(price)}"

  # Helper function to generate cache-busting banner URL
  defp banner_url_with_cache_bust(film, banner_updated_at) do
    base_url = BannerUploader.banner_url(film)
    "#{base_url}?t=#{banner_updated_at}"
  end

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      show_login_message: false,
      show_rent_confirmation: false,
      show_insufficient_funds: false,
      show_rental_success: false,
      user_owns_film: false,  # Default value
      ownership_id: nil,  # Default value for ownership ID
      edit: false,  # Default value for edit parameter
      show_banner_upload_modal: false,
      banner_uploading: false,
      banner_updated_at: System.system_time(:second),
      is_premiere: false  # Default value for is_premiere
    )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:banner_uploading, false)
     |> assign(:banner_updated_at, System.system_time(:second))
     |> assign_new(:is_premiere, fn -> false end)  # Ensure is_premiere has a default value
    }
  end

  @impl true
  def handle_event("banner_upload_complete", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Banner uploaded successfully!")
     |> assign(:banner_updated_at, System.system_time(:second))
     |> assign(:banner_uploading, false)
     |> assign(:show_banner_upload_modal, false)}
  end

  @impl true
  def handle_event("banner_upload_error", %{"error" => error}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, error)
     |> assign(:banner_uploading, false)}
  end

  @impl true
  def handle_event("set_banner_uploading", %{"uploading" => uploading}, socket) do
    {:noreply, assign(socket, :banner_uploading, uploading)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    film = socket.assigns.film

    case consume_uploaded_entries(socket, :banner, fn %{path: path} ->
      case BannerUploader.store({path, film}) do
        {:ok, _filename} -> {:ok, :banner_uploaded}
        {:error, reason} -> {:error, reason}
      end
    end) do
      [{:ok, :banner_uploaded}] ->
        {:noreply,
         socket
         |> put_flash(:info, "Banner uploaded successfully!")
         |> assign(:banner_updated_at, System.system_time(:second))
         |> assign(:banner_uploading, false)
         |> assign(:show_banner_upload_modal, false)}

      [{:error, reason}] ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to upload banner: #{reason}")
         |> assign(:banner_uploading, false)}

      [] ->
        {:noreply,
         socket
         |> put_flash(:error, "No file was uploaded")
         |> assign(:banner_uploading, false)}
    end
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
            <%= if @film.film && Map.get(@film.film, :trailer_playback_id) && @trailer_token do %>
              <mux-player
                playback-id={@film.film.trailer_playback_id}
                poster={if BannerUploader.banner_exists?(@film), do: banner_url_with_cache_bust(@film, @banner_updated_at), else: nil}
                playback-token={@trailer_token}
                stream-type="on-demand"
                style="--bottom-controls: none;"
                title="Trailer"
                class="w-full h-full"
              ></mux-player>
            <% else %>
              <!-- Static image fallback -->
              <%= cond do %>
                <% BannerUploader.banner_exists?(@film) -> %>
                  <div class="relative w-full aspect-video">
                    <img
                      src={banner_url_with_cache_bust(@film, @banner_updated_at)}
                      alt={"Banner for #{@film.title}"}
                      class="w-full h-full object-cover"
                    />
                    <%= if Map.get(assigns, :edit, false) do %>
                      <button
                        type="button"
                        class="absolute top-4 left-4 w-10 h-10 bg-white bg-opacity-80 rounded-full shadow-md flex items-center justify-center border border-gray-200 hover:bg-opacity-100 cursor-pointer z-10 transition-all duration-200 hover:scale-105"
                        phx-click="show_banner_upload_modal"
                        phx-target={@myself}
                      >
                        <svg class="w-5 h-5 text-gray-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                        </svg>
                      </button>
                    <% end %>
                  </div>
                <% true -> %>
                  <div class="w-full aspect-video flex items-center justify-center text-gray-400">
                    <div class="text-center">
                      <svg class="w-16 h-16 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                      </svg>
                      <p>No banner available</p>
                      <%= if Map.get(assigns, :edit, false) do %>
                        <button
                          type="button"
                          class="mt-4 px-4 py-2 bg-white rounded-md shadow text-sm font-medium text-gray-700 hover:bg-gray-50"
                          phx-click="show_banner_upload_modal"
                          phx-target={@myself}
                        >
                          Upload Banner
                        </button>
                      <% end %>
                    </div>
                  </div>
              <% end %>
            <% end %>
          </div>

          <!-- Content Area -->
          <div class="bg-black text-white p-6">
            <!-- Title and Actions Row -->
            <div class="flex items-start justify-between mb-4">
              <div class="flex-1">
                <div class="flex items-center gap-3 mb-2">
                  <%= if @is_premiere do %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                      Premiere
                    </span>
                  <% end %>
                  <h1 class="text-2xl font-bold text-white">
                    <%= @film.title %>
                  </h1>
                </div>
                <p class="text-gray-300 mb-4">
                  By <%= if is_map(@film.creator) && !match?(%Ecto.Association.NotLoaded{}, @film.creator), do: @film.creator.name, else: "Unknown Creator" %>
                </p>
              </div>

              <!-- Action Buttons -->
              <div class="flex space-x-3 ml-6">
                <%= if @user_owns_film do %>
                  <!-- User owns the film - show Watch Now button -->
                  <.link
                    navigate={~p"/watch?id=#{@ownership_id}"}
                    class="inline-flex flex-col items-center px-6 py-3 bg-green-600 text-white font-semibold rounded hover:bg-green-700 transition-colors"
                  >
                    <span class="text-sm">▶️ Watch Now</span>
                    <span class="text-xs opacity-75">You own this film</span>
                  </.link>
                <% else %>
                  <!-- User doesn't own - show rent/premiere button (disabled in edit mode) -->
                  <%= if Map.get(assigns, :edit, false) do %>
                    <!-- Edit mode - show disabled button -->
                    <button
                      type="button"
                      class="inline-flex flex-col items-center px-4 py-3 bg-gray-300 text-gray-500 font-semibold rounded cursor-not-allowed opacity-50"
                      disabled
                    >
                      <span class="text-sm"><%= if @is_premiere, do: "Join Premiere", else: "Rent" %></span>
                      <span class="text-lg font-bold"><%= format_price(if @is_premiere, do: @film.premiere_price, else: @film.rental_price) %></span>
                    </button>
                  <% else %>
                    <!-- Normal mode - show active button -->
                    <button
                      type="button"
                      class="inline-flex flex-col items-center px-4 py-3 bg-white text-black font-semibold rounded hover:bg-gray-200 transition-colors"
                      phx-click="rent_film"
                      phx-target={@myself}
                    >
                      <span class="text-sm"><%= if @is_premiere, do: "Join Premiere", else: "Rent" %></span>
                      <span class="text-lg font-bold"><%= format_price(if @is_premiere, do: @film.premiere_price, else: @film.rental_price) %></span>
                    </button>
                  <% end %>
                <% end %>
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

            <%= if @is_premiere && @film.premiere_date do %>
              <!-- Premiere Date -->
              <div class="mt-4 p-4 bg-gray-800 rounded-lg">
                <h3 class="text-lg font-semibold text-white mb-2">Premiere Details</h3>
                <p class="text-gray-300">
                  Premiering on <%= Calendar.strftime(@film.premiere_date, "%B %d, %Y at %I:%M %p UTC") %>
                </p>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Banner Upload Modal -->
      <%= if @show_banner_upload_modal do %>
        <div class="fixed inset-0 z-60 overflow-y-auto">
          <div class="fixed inset-0 bg-black bg-opacity-50"></div>
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative bg-white rounded-lg p-6 max-w-md w-full">
              <div class="absolute right-0 top-0 pr-4 pt-4">
                <button
                  phx-click="hide_banner_upload_modal"
                  phx-target={@myself}
                  type="button"
                  class="rounded-md bg-white text-gray-400 hover:text-gray-500 focus:outline-none"
                >
                  <span class="sr-only">Close</span>
                  <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <div class="text-center">
                <div class="mb-4">
                  <h3 class="text-lg font-medium text-gray-900">Upload Banner Image</h3>
                  <p class="text-sm text-gray-500 mt-1">Upload a banner image with a 16:9 aspect ratio</p>
                  <p class="mt-1 text-xs text-blue-600">
                    Need to adjust your image? Use this free
                    <a href="https://imagy.app/image-aspect-ratio-changer/" target="_blank" rel="noopener noreferrer" class="underline hover:text-blue-800">
                      aspect ratio changer tool
                    </a>
                  </p>
                </div>

                <div class="mt-6" id="banner-upload-hook" phx-hook="BannerUpload" data-project-id={@film.id} phx-target={@myself}>
                  <!-- Banner Preview Area -->
                  <div class="flex justify-center mb-6">
                    <div class="w-full aspect-video border-2 border-dashed border-gray-300 rounded-lg flex flex-col items-center justify-center bg-gray-50">
                      <%= if BannerUploader.banner_exists?(@film) do %>
                        <img
                          src={banner_url_with_cache_bust(@film, @banner_updated_at)}
                          alt={"Banner for #{@film.title}"}
                          class="w-full h-full object-cover rounded-lg"
                        />
                      <% else %>
                        <div class="text-center">
                          <svg class="mx-auto h-12 w-12 text-gray-400 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                          </svg>
                          <p class="text-xs text-gray-500">16:9 Aspect Ratio</p>
                          <p class="text-xs text-gray-400">JPG, PNG, WEBP</p>
                        </div>
                      <% end %>
                    </div>
                  </div>

                  <!-- Hidden file input -->
                  <input
                    type="file"
                    id="banner-file-input"
                    accept=".jpg,.jpeg,.png,.webp"
                    style="display: none;"
                  />

                  <!-- Action Buttons -->
                  <div class="flex justify-center gap-3">
                    <button
                      type="button"
                      phx-click="hide_banner_upload_modal"
                      phx-target={@myself}
                      class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                    >
                      Cancel
                    </button>
                    <button
                      type="button"
                      onclick="document.dispatchEvent(new CustomEvent('banner-upload:choose-file'))"
                      class={[
                        "px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500",
                        @banner_uploading && "opacity-50 cursor-not-allowed"
                      ]}
                      disabled={@banner_uploading}
                    >
                      <%= if @banner_uploading do %>
                        <svg class="animate-spin -ml-1 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                          <path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                        </svg>
                        Uploading...
                      <% else %>
                        Choose File
                      <% end %>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Login Message Modal -->
      <%= if @show_login_message do %>
        <div class="fixed inset-0 z-60 overflow-y-auto">
          <div class="fixed inset-0 bg-black bg-opacity-50"></div>
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative bg-white rounded-lg p-6 max-w-md w-full">
              <div class="text-center">
                <h3 class="text-lg font-medium text-gray-900 mb-4">Uh oh, please log in or sign up</h3>
                <p class="text-gray-600 mb-6">You need to be logged in to rent films.</p>
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
                  Do you want to rent "<%= @film.title %>" for <%= format_price(if @is_premiere, do: @film.premiere_price, else: @film.rental_price) %>?
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

      <!-- Insufficient Funds Modal -->
      <%= if @show_insufficient_funds do %>
        <div class="fixed inset-0 z-60 overflow-y-auto">
          <div class="fixed inset-0 bg-black bg-opacity-50"></div>
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative bg-white rounded-lg p-6 max-w-md w-full">
              <div class="text-center">
                <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-red-100 mb-4">
                  <svg class="h-6 w-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.232 15.5c-.77.833.192 2.5 1.732 2.5z" />
                  </svg>
                </div>
                <h3 class="text-lg font-medium text-gray-900 mb-4">Insufficient Funds</h3>
                <p class="text-gray-600 mb-6">
                  You don't have enough funds in your wallet to rent "<%= @film.title %>" for <%= format_price(if @is_premiere, do: @film.premiere_price, else: @film.rental_price) %>.
                  <br><br>
                  Would you like to add funds to your wallet?
                </p>
                <div class="flex space-x-3 justify-center">
                  <button
                    type="button"
                    class="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 font-medium"
                    phx-click="go_to_shop"
                    phx-target={@myself}
                  >
                    Add Funds
                  </button>
                  <button
                    type="button"
                    class="px-4 py-2 bg-gray-600 text-white rounded hover:bg-gray-700 font-medium"
                    phx-click="close_insufficient_funds"
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

      <!-- Rental Success Modal -->
      <%= if @show_rental_success do %>
        <div class="fixed inset-0 z-60 overflow-y-auto">
          <div class="fixed inset-0 bg-black bg-opacity-50"></div>
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative bg-white rounded-lg p-6 max-w-md w-full transform transition-all duration-300 ease-in-out scale-100">
              <div class="text-center">
                <!-- Success Animation -->
                <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-green-100 mb-4 animate-pulse">
                  <svg class="h-8 w-8 text-green-600 animate-bounce" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                </div>

                <h3 class="text-xl font-bold text-gray-900 mb-2">🎉 Rental Successful!</h3>
                <p class="text-gray-600 mb-6">
                  You now have access to "<span class="font-semibold"><%= @film.title %></span>" for 48 hours.
                  <br><br>
                  Ready to start watching? Your film is waiting in your personal library!
                </p>

                <div class="flex flex-col sm:flex-row space-y-2 sm:space-y-0 sm:space-x-3 justify-center">
                  <button
                    type="button"
                    class="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-semibold shadow-md hover:shadow-lg transition-all duration-200 transform hover:scale-105"
                    phx-click="go_to_library"
                    phx-target={@myself}
                  >
                    📚 Go to My Library
                  </button>
                  <button
                    type="button"
                    class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 font-medium"
                    phx-click="close_success"
                    phx-target={@myself}
                  >
                    Continue Browsing
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
    send(self(), :close_film_modal)
    {:noreply, socket}
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
  def handle_event("close_login_message", _params, socket) do
    {:noreply, assign(socket, show_login_message: false)}
  end

  @impl true
  def handle_event("confirm_rent", _params, socket) do
    user = socket.assigns.current_user
    film = socket.assigns.film

    # Convert rental price from Decimal to cents for comparison
    rental_price_cents = if film.rental_price do
      Decimal.to_integer(Decimal.mult(film.rental_price, 100))
    else
      0
    end

    # Check if user has sufficient wallet balance
    if user.wallet_balance >= rental_price_cents do
      # User has sufficient balance - process the rental
      case process_rental(user, film, rental_price_cents) do
        {:ok, _ownership_record} ->
          # Get the updated user to reflect the new wallet balance
          updated_user = Accounts.get_user!(user.id)

          {:noreply,
           socket
           |> assign(show_rent_confirmation: false, show_rental_success: true)
           |> assign(current_user: updated_user)  # Update current_user with new balance
           |> put_flash(:info, "Rental successful! You now have access to \"#{film.title}\" for 48 hours.")
          }

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(show_rent_confirmation: false)
           |> put_flash(:error, "Rental failed: #{reason}. Please try again.")
          }
      end
    else
      # Show insufficient funds modal
      {:noreply, assign(socket,
        show_rent_confirmation: false,
        show_insufficient_funds: true
      )}
    end
  end

  # Helper function to process the rental
  defp process_rental(user, film, rental_price_cents) do
    # Start a database transaction to ensure all operations succeed or fail together
    Repo.transaction(fn ->
      # 1. Generate JWT token for the film's playback
      playback_id = get_film_playback_id(film)
      jwt_token = if playback_id do
        MuxToken.generate_playback_token(playback_id)
      else
        nil
      end

      # 2. Create or update ownership record
      case Ownership.create_rental(user.id, film.id, jwt_token) do
        {:ok, ownership_record} ->
          # 3. Deduct funds from user's wallet
          case Accounts.deduct_wallet_funds(user.id, rental_price_cents) do
            {:ok, _updated_user} ->
              ownership_record

            {:error, reason} ->
              Repo.rollback("Failed to deduct wallet funds: #{reason}")
          end

        {:error, :already_owns} ->
          Repo.rollback("You already have an active rental for this film")

        {:error, changeset} ->
          Repo.rollback("Failed to create rental record: #{inspect(changeset.errors)}")
      end
    end)
  end

  # Helper function to get the playback ID from a film
  defp get_film_playback_id(film) do
    cond do
      film.film && Map.get(film.film, :film_playback_id) ->
        film.film.film_playback_id

      film.film && Map.get(film.film, :trailer_playback_id) ->
        film.film.trailer_playback_id

      true ->
        nil
    end
  end

  @impl true
  def handle_event("cancel_rent", _params, socket) do
    {:noreply, assign(socket, show_rent_confirmation: false)}
  end

  @impl true
  def handle_event("close_insufficient_funds", _params, socket) do
    {:noreply, assign(socket, show_insufficient_funds: false)}
  end

  @impl true
  def handle_event("go_to_shop", _params, socket) do
    {:noreply,
     socket
     |> assign(show_insufficient_funds: false)
     |> push_navigate(to: ~p"/shop")
    }
  end

  @impl true
  def handle_event("close_success", _params, socket) do
    {:noreply, assign(socket, show_rental_success: false)}
  end

  @impl true
  def handle_event("go_to_library", _params, socket) do
    {:noreply,
     socket
     |> assign(show_rental_success: false)
     |> push_navigate(to: ~p"/library")  # Assuming this is the library route
    }
  end

  @impl true
  def handle_event("show_banner_upload_modal", _params, socket) do
    {:noreply, assign(socket, :show_banner_upload_modal, true)}
  end

  @impl true
  def handle_event("hide_banner_upload_modal", _params, socket) do
    {:noreply, assign(socket, :show_banner_upload_modal, false)}
  end
end
