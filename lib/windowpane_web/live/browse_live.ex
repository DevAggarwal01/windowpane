defmodule WindowpaneWeb.BrowseLive do
  use WindowpaneWeb, :live_view

  import WindowpaneWeb.NavComponents

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user] || socket.assigns[:current_creator]
    is_creator = !!socket.assigns[:current_creator]

    {:ok, assign(socket,
      user: user,
      is_creator: is_creator,
      current_path: socket.assigns.live_action
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <.main_header current_path={@current_path} is_creator={@is_creator} />

      <div class="container mx-auto px-4 py-8">
        <h1 class="text-3xl font-bold mb-8">Browse Content</h1>
        <div class="bg-white rounded-lg shadow p-6">
          <p class="text-gray-600">Discover amazing content from our creators.</p>

          <!-- Featured Content Section -->
          <div class="mt-8">
            <h2 class="text-2xl font-semibold mb-4">Featured Content</h2>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
              <!-- Sample featured items - replace with real data -->
              <div class="bg-gray-50 rounded-lg p-4">
                <div class="aspect-w-16 aspect-h-9 bg-gray-200 rounded-lg mb-4"></div>
                <h3 class="font-medium">Featured Item 1</h3>
                <p class="text-sm text-gray-600">Creator Name</p>
              </div>
              <div class="bg-gray-50 rounded-lg p-4">
                <div class="aspect-w-16 aspect-h-9 bg-gray-200 rounded-lg mb-4"></div>
                <h3 class="font-medium">Featured Item 2</h3>
                <p class="text-sm text-gray-600">Creator Name</p>
              </div>
              <div class="bg-gray-50 rounded-lg p-4">
                <div class="aspect-w-16 aspect-h-9 bg-gray-200 rounded-lg mb-4"></div>
                <h3 class="font-medium">Featured Item 3</h3>
                <p class="text-sm text-gray-600">Creator Name</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
