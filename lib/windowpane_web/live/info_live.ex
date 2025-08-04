defmodule WindowpaneWeb.InfoLive do
  use WindowpaneWeb, :live_view
  require Logger

  alias Windowpane.Projects
  alias Windowpane.{Repo, Ownership, Accounts, MuxToken, Creators, PricingCalculator}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      project: nil,
      playback_id: nil,
      content_type: nil,
      ownership_record: nil,
      show_rent_confirmation: false,
      show_insufficient_funds: false,
      show_rental_success: false,
      show_login_modal: false
    )}
  end

  @impl true
  def handle_params(%{"trailer_id" => trailer_id}, _url, socket) do
    Logger.info("InfoLive: Starting trailer handle_params with trailer_id=#{trailer_id}")

    try do
      project_id = String.to_integer(trailer_id)
      Logger.info("InfoLive: Parsed project_id=#{project_id}")

      # Get the project with film data preloaded
      project = Projects.get_project_with_film_and_creator_name!(project_id)
      Logger.info("InfoLive: Found project id=#{project.id}, title='#{project.title}', type=#{project.type}")

      # Check if project is published
      if project.status != "published" do
        Logger.warning("InfoLive: Project not published (status=#{project.status})")
        redirect_to_home(socket)
      else
        # Check if project has a trailer
        if project.film && project.film.trailer_playback_id do
          Logger.info("InfoLive: Setting up info page for project '#{project.title}' (trailer_playback_id=#{project.film.trailer_playback_id})")
          setup_info_page(socket, project)
        else
          Logger.warning("InfoLive: No trailer available for project id=#{project.id}")
          redirect_to_home(socket)
        end
      end
    rescue
      ArgumentError ->
        # Invalid ID format
        Logger.error("InfoLive: Invalid trailer_id format for trailer_id=#{trailer_id}")
        redirect_to_home(socket)
      Ecto.NoResultsError ->
        # Project not found
        Logger.error("InfoLive: Project not found for trailer_id=#{trailer_id}")
        redirect_to_home(socket)
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  @impl true
  def handle_event("rent_film", _params, socket) do
    if socket.assigns[:current_user] do
      {:noreply, assign(socket, show_rent_confirmation: true)}
    else
      {:noreply, assign(socket, show_login_modal: true)}
    end
  end

  @impl true
  def handle_event("confirm_rent", _params, socket) do
    user = socket.assigns.current_user
    project = socket.assigns.project
    price = project.rental_price
    price_cents = if price, do: Decimal.to_integer(Decimal.mult(price, 100)), else: 0

    if user.wallet_balance >= price_cents do
      case process_rental(user, project, price_cents) do
        {:ok, _ownership_record} ->
          updated_user = Accounts.get_user!(user.id)
          {:noreply,
            socket
            |> assign(show_rent_confirmation: false, show_rental_success: true)
            |> assign(current_user: updated_user)
            |> put_flash(:info, "Rental successful! You now have access to \"#{project.title}\" for 48 hours.")
          }
        {:error, reason} ->
          {:noreply,
            socket
            |> assign(show_rent_confirmation: false)
            |> put_flash(:error, "Rental failed: #{reason}. Please try again.")
          }
      end
    else
      {:noreply, assign(socket, show_rent_confirmation: false, show_insufficient_funds: true)}
    end
  end

  defp process_rental(user, project, price_cents) do
    Repo.transaction(fn ->
      playback_id = project.film && project.film.film_playback_id
      expires_at = DateTime.utc_now() |> DateTime.add(48 * 3600, :second) |> DateTime.truncate(:second)
      seconds_until_expiration = DateTime.diff(expires_at, DateTime.utc_now())
      jwt_token = if playback_id, do: MuxToken.generate_playback_token(playback_id, seconds_until_expiration), else: nil

      case Ownership.create_rental(user.id, project.id, jwt_token, expires_at) do
        {:ok, ownership_record} ->
          case Accounts.deduct_wallet_funds(user.id, price_cents) do
            {:ok, _updated_user} ->
              creator_cut = project.rental_creator_cut || Decimal.new("0")
              creator_cut_cents = Decimal.to_integer(Decimal.mult(creator_cut, 100))
              Creators.add_wallet_funds(project.creator_id, creator_cut_cents)
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
      |> push_navigate(to: ~p"/wallet")
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
      |> push_navigate(to: ~p"/library")
    }
  end

  @impl true
  def handle_event("browse_more", _params, socket) do
    {:noreply,
      socket
      |> assign(show_rental_success: false)
      |> push_navigate(to: ~p"/browse")
    }
  end

  @impl true
  def handle_event("show_login_modal", _params, socket) do
    {:noreply, assign(socket, show_login_modal: true)}
  end

  @impl true
  def handle_info(:close_login_modal, socket) do
    {:noreply, assign(socket, show_login_modal: false)}
  end

  @impl true
  def handle_info({:login_success, user, token}, socket) do
    # TODO: Set session cookie if needed
    {:noreply, socket |> assign(current_user: user, show_login_modal: false)}
  end

  # Helper function to redirect to home page
  defp redirect_to_home(socket) do
    Logger.info("InfoLive: Redirecting to home page")
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  # Helper function to set up the info page
  defp setup_info_page(socket, project) do
    Logger.info("InfoLive: Setting up info page for project '#{project.title}' (trailer_playback_id=#{project.film.trailer_playback_id})")

    # Check for ownership if user is logged in
    current_user = socket.assigns[:current_user]
    {user_owns_film, ownership_id} =
      if current_user do
        case Ownership.get_active_ownership_record(current_user.id, project.id) do
          nil -> {false, nil}
          record -> {true, record.id}
        end
      else
        {false, nil}
      end

    socket =
      socket
      |> assign(:project, project)
      |> assign(:playback_id, project.film.trailer_playback_id)
      |> assign(:content_type, "trailer")
      |> assign(:playback_token, nil)
      |> assign(:ownership_record, nil)
      |> assign(:page_title, project.title)
      |> assign(:invalid_type, false)
      |> assign(:user_owns_film, user_owns_film)
      |> assign(:ownership_id, ownership_id)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-black">
      <!-- Main Content -->
      <div class="flex pl-8">
        <!-- Left Side - Video Player (maintain exact current size) -->
        <div class="w-4/5 pr-4 pb-12 flex-shrink-0">
          <!-- Player Container -->
          <div class="aspect-video bg-black">
            <mux-player
              playback-id={@project.film.trailer_playback_id}
              stream-type="on-demand"
              class="w-full h-full"
            ></mux-player>
          </div>

          <!-- Creator Info Below Video -->
          <div class="mt-4">
            <p class="text-white font-bold text-lg">
              <%= @project.creator.name %>
            </p>
          </div>
        </div>

        <!-- Right Side - Film Details Card -->
        <div class="flex-1 p-4">
          <div style="border: 4px solid #ffffff;" class="relative">
            <!-- Film Cover -->
            <div class="aspect-[3/4] bg-gray-900 relative">
              <%= if Windowpane.Uploaders.CoverUploader.cover_exists?(@project) do %>
                <img
                  src={Windowpane.Uploaders.CoverUploader.cover_url(@project)}
                  alt={"Cover for #{@project.title}"}
                  class="w-full h-full object-cover"
                />
              <% else %>
                <div class="flex items-center justify-center w-full h-full">
                  <div class="text-center text-gray-700">
                    <span class="text-6xl mb-2 block">🎬</span>
                    <span class="text-sm font-medium">No Cover</span>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Film Details -->
            <div class="p-4">
              <h1 class="text-xl font-bold text-white mb-2"><%= @project.title %></h1>

              <!-- Status Badge -->
              <div class="flex items-center gap-2 mb-4">
                <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-bold bg-blue-900 text-white">
                  🎬 TRAILER
                </span>
              </div>

              <!-- Film Info -->
              <div class="space-y-2 text-sm">
                <%= if @project.description && String.trim(@project.description) != "" do %>
                  <div>
                    <p class="text-white font-bold leading-relaxed">
                      <%= @project.description %>
                    </p>
                  </div>
                <% end %>

                <div class="pt-2 border-t border-gray-800">
                  <div class="space-y-1">
                    <div class="flex justify-between">
                      <span class="text-white font-bold">Type:</span>
                      <span class="text-white font-bold capitalize"><%= @project.type %></span>
                    </div>
                    <%= if @project.premiere_date do %>
                      <div class="flex justify-between">
                        <span class="text-white font-bold">Premiered:</span>
                        <span class="text-white font-bold">
                          <%= Calendar.strftime(@project.premiere_date, "%B %Y") %>
                        </span>
                      </div>
                    <% end %>
                    <div class="flex justify-between">
                      <span class="text-white font-bold">Status:</span>
                      <span class="text-white font-bold">
                        Trailer Preview
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <!-- Rent/Watch Button Below Film Card -->
          <div class="flex items-center justify-center gap-6 mt-6" style="border: 4px solid #ffffff;">
            <%= if @user_owns_film && @ownership_id do %>
              <.link
                navigate={~p"/watch?id=#{@ownership_id}"}
                class="text-white font-bold px-8 py-3 bg-black border-8 border-white border-solid text-xl"
                style="outline: none;"
              >
                ▶️ Watch Now
              </.link>
            <% else %>
              <div class="flex flex-col items-end w-full">
                <button
                  class="block w-full text-white font-bold px-8 py-3 bg-black border-4 border-white border-solid text-xl transition-colors duration-150 hover:bg-white hover:text-black focus:bg-white focus:text-black active:bg-white active:text-black ring-0 mb-2"
                  style="outline: none;"
                  phx-click="rent_film"
                >
                  RENT $<%= Decimal.to_string(@project.rental_price, :normal) %>
                </button>
              </div>
            <% end %>
          </div>
          <%= !if @user_owns_film || !@ownership_id do %>
            <div class="flex justify-end w-full mt-2">
              <span class="text-white text-xs opacity-80 pr-2">Rental lasts for 48 hours.</span>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Rent Confirmation Modal -->
    <%= if @show_rent_confirmation do %>
      <div class="fixed inset-0 z-60 overflow-y-auto">
        <div class="fixed inset-0 bg-black bg-opacity-50"></div>
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="relative bg-black p-6 max-w-md w-full" style="border: 8px solid #ffffff;">
            <div class="text-center">
              <h3 class="text-lg font-medium text-white mb-4">Are you sure?</h3>
              <p class="text-white mb-6">
                Do you want to rent "<%= @project.title %>" for $<%= Decimal.to_string(@project.rental_price, :normal) %>?
              </p>
              <div class="flex space-x-6 justify-center">
                <button
                  type="button"
                  class="text-white font-bold text-lg transition-transform duration-150 hover:scale-110 focus:scale-110 outline-none"
                  style="background: none; border: none; padding: 0;"
                  phx-click="confirm_rent"
                >
                  [yes, rent it]
                </button>
                <button
                  type="button"
                  class="text-white font-bold text-lg transition-transform duration-150 hover:scale-110 focus:scale-110 outline-none"
                  style="background: none; border: none; padding: 0;"
                  phx-click="cancel_rent"
                >
                  [cancel]
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
          <div class="relative bg-black p-6 max-w-md w-full" style="border: 8px solid #ffffff;">
            <div class="text-center">
              <h3 class="text-lg font-medium text-white mb-4">Insufficient Funds</h3>
              <p class="text-white mb-6">
                You don't have enough funds in your wallet to rent "<%= @project.title %>" for $<%= Decimal.to_string(@project.rental_price, :normal) %>.
                <br><br>
                Would you like to add funds to your wallet?
              </p>
              <div class="flex space-x-6 justify-center">
                <button
                  type="button"
                  class="text-white font-bold text-lg transition-transform duration-150 hover:scale-110 focus:scale-110 outline-none"
                  style="background: none; border: none; padding: 0;"
                  phx-click="go_to_shop"
                >
                  [add funds]
                </button>
                <button
                  type="button"
                  class="text-white font-bold text-lg transition-transform duration-150 hover:scale-110 focus:scale-110 outline-none"
                  style="background: none; border: none; padding: 0;"
                  phx-click="close_insufficient_funds"
                >
                  [cancel]
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
          <div class="relative bg-black p-6 max-w-md w-full" style="border: 8px solid #ffffff;">
            <div class="text-center">
              <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-green-600 mb-4 animate-pulse">
                <svg class="h-8 w-8 text-white animate-bounce" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <h3 class="text-xl font-bold text-white mb-2">🎉 Rental Successful!</h3>
              <p class="text-white mb-6">
                You now have access to "<span class="font-semibold"><%= @project.title %></span>" for 48 hours.
                <br><br>
                Ready to start watching? Your film is waiting in your personal library!
              </p>
              <div class="flex space-x-6 justify-center">
                <button
                  type="button"
                  class="text-white font-bold text-lg transition-transform duration-150 hover:scale-110 focus:scale-110 outline-none"
                  style="background: none; border: none; padding: 0;"
                  phx-click="go_to_library"
                >
                  [go to library]
                </button>
                <button
                  type="button"
                  class="text-white font-bold text-lg transition-transform duration-150 hover:scale-110 focus:scale-110 outline-none"
                  style="background: none; border: none; padding: 0;"
                  phx-click="browse_more"
                >
                  [browse more]
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
