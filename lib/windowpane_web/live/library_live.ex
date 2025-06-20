defmodule WindowpaneWeb.LibraryLive do
  use WindowpaneWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user] || socket.assigns[:current_creator]
    is_creator = !!socket.assigns[:current_creator]

    {:ok, assign(socket,
      user: user,
      is_creator: is_creator,
      page_title: "My Library"
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Main Content -->
    <main class="max-w-7xl mx-auto px-4 py-6">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-white mb-2">My Library</h1>
        <p class="text-gray-400">Your purchased and rented films</p>
      </div>

      <!-- Content Area -->
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
    </main>
    """
  end
end
