defmodule WindowpaneWeb.PageLive do
  use WindowpaneWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, show_login_modal: false, show_signup: false), layout: {WindowpaneWeb.Layouts, :minimal}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen relative bg-black">
      <!-- Background Video -->
      <video
        autoplay
        muted
        loop
        class="absolute left-1/2 transform -translate-x-1/2 w-auto h-auto max-w-none z-0"
        style="max-height: 50vh; margin-top: 100px;"
      >
        <source src="/images/wpbw4.webm" type="video/webm">
        <!-- Fallback for browsers that don't support webm -->
        Your browser does not support the video tag.
      </video>

      <!-- Content overlay -->
      <div class="relative z-10 min-h-screen flex flex-col">
        <!-- Header -->
        <header class="p-2 border-b border-gray-200">
          <div class="flex justify-between items-center w-full">
            <!-- Left: Windowpane Studio -->
            <div class="flex items-center">
              <span class="text-white text-lg font-semibold">Windowpane Studio</span>
            </div>

            <!-- Center: Empty space -->
            <div class="flex items-center">
            </div>

            <!-- Right: Login/Signup -->
            <div class="flex items-center space-x-4">
              <button
                phx-click="show_login_modal"
                class="text-white text-sm font-medium transition-transform duration-150 hover:scale-110"
              >
                [login]
              </button>
              <button
                phx-click="show_signup_modal"
                class="text-white text-sm font-medium transition-transform duration-150 hover:scale-110"
              >
                [signup]
              </button>
            </div>
          </div>
        </header>

        <!-- Main Content -->
        <main class="flex-grow flex flex-col">
          <!-- Upper section with windowpane.tv below the gif -->
          <div class="flex-1 flex items-end justify-center pb-8">
            <div class="text-center">
              <h1 class="text-6xl font-bold text-white" style="font-family: 'Crimson Text', serif;">
                windowpane.tv
              </h1>
            </div>
          </div>

          <!-- Lower section with check it out -->
          <div class="flex-1 flex items-start justify-center pt-8">
            <div class="text-center">
              <a
                href="https://windowpane.tv"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-block text-white text-lg font-medium transition-transform duration-150 hover:scale-110"
              >
                [check-it-out]
              </a>
            </div>
          </div>
        </main>
      </div>

      <%= if @show_login_modal do %>
        <.live_component
          module={WindowpaneWeb.CreatorLoginModalComponent}
          id="creator-login-modal"
          show_signup={@show_signup}
        />
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("show_login_modal", _params, socket) do
    {:noreply, assign(socket, show_login_modal: true, show_signup: false)}
  end

  @impl true
  def handle_event("show_signup_modal", _params, socket) do
    {:noreply, assign(socket, show_login_modal: true, show_signup: true)}
  end

  @impl true
  def handle_info(:close_login_modal, socket) do
    {:noreply, assign(socket, show_login_modal: false, show_signup: false)}
  end
end
