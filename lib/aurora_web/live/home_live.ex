defmodule AuroraWeb.HomeLive do
  use AuroraWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user] || socket.assigns[:current_creator]
    is_creator = !!socket.assigns[:current_creator]

    # Sample data - replace with real data from your context
    stats = %{
      total_revenue: "$12,345",
      content_performance: "Good",
      viewer_feedback: "Positive"
    }

    {:ok, assign(socket,
      user: user,
      is_creator: is_creator,
      stats: stats
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Top Navigation -->
      <header class="bg-gray-800 text-white">
        <div class="container mx-auto px-4">
          <div class="flex items-center justify-between h-16">
            <div class="text-xl font-semibold">Dashboard</div>
            <div class="flex items-center space-x-8">
              <nav class="flex space-x-8">
                <.link navigate={~p"/"} class="text-gray-300 hover:text-white">Browse</.link>
                <.link navigate={~p"/library"} class="text-gray-300 hover:text-white">My Library</.link>
                <.link navigate={~p"/social"} class="text-gray-300 hover:text-white">Social</.link>
                <.link navigate={~p"/settings"} class="text-gray-300 hover:text-white">Account Settings</.link>
              </nav>
              <.link
                href={if @is_creator, do: ~p"/creators/log_out", else: ~p"/users/log_out"}
                method="delete"
                class="text-gray-300 hover:text-white px-3 py-2 rounded-md text-sm font-medium"
              >
                Log out
              </.link>
            </div>
          </div>
        </div>
      </header>

      <!-- Main Content -->
      <main class="container mx-auto px-4 py-8">
        <h1 class="text-3xl font-bold mb-8">Studio Homepage</h1>

        <!-- Stats Grid -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-2">Total Revenue</h3>
            <p class="text-4xl font-bold"><%= @stats.total_revenue %></p>
          </div>

          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-2">Content Performance</h3>
            <p class="text-4xl font-bold"><%= @stats.content_performance %></p>
          </div>

          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-2">Viewer Feedback</h3>
            <p class="text-4xl font-bold"><%= @stats.viewer_feedback %></p>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
          <.link
            navigate={~p"/projects/new"}
            class="inline-flex items-center justify-center px-6 py-4 bg-gray-800 text-white text-lg font-medium rounded-lg hover:bg-gray-700"
          >
            Create New Project
          </.link>

          <.link
            navigate={~p"/projects"}
            class="inline-flex items-center justify-center px-6 py-4 bg-white text-gray-800 text-lg font-medium rounded-lg border-2 border-gray-200 hover:bg-gray-50"
          >
            View/Manage Past Projects
          </.link>
        </div>

        <!-- Bottom Section -->
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between">
            <div class="text-xl font-semibold">Actions</div>
            <div class="flex space-x-6">
              <.link navigate={~p"/"} class="text-gray-600 hover:text-gray-900">Browse</.link>
              <.link navigate={~p"/social"} class="text-gray-600 hover:text-gray-900">Mocial</.link>
              <.link navigate={~p"/settings"} class="text-gray-600 hover:text-gray-900">Account Settings</.link>
              <span class="text-gray-300">→</span>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end
end
