defmodule AuroraWeb.HomeLive do
  use AuroraWeb, :live_view

  import AuroraWeb.NavComponents

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
      stats: stats,
      current_path: socket.assigns.live_action
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <.main_header current_path={@current_path} is_creator={@is_creator} />

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

        <!-- Projects Section -->
        <div class="mb-8">
          <h2 class="text-2xl font-bold mb-4">My Projects</h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
            <!-- Create New Project Card -->
            <.link
              navigate={~p"/projects/new"}
              class="flex flex-col items-center justify-center p-6 bg-white rounded-lg shadow-sm border-2 border-dashed border-gray-300 hover:border-gray-400 hover:bg-gray-50 transition-all duration-200"
            >
              <div class="w-16 h-16 flex items-center justify-center rounded-full bg-gray-100 mb-4">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
              </div>
              <h3 class="text-lg font-medium text-gray-900">Create New Project</h3>
              <p class="mt-1 text-sm text-gray-500">Start a new creative project</p>
            </.link>

            <!-- Sample Project Cards - Replace with real data -->
            <div class="bg-white rounded-lg shadow-sm p-6">
              <div class="aspect-w-16 aspect-h-9 bg-gray-200 rounded-lg mb-4"></div>
              <h3 class="text-lg font-medium text-gray-900">Project Title</h3>
              <p class="text-sm text-gray-500">Last updated: 2 days ago</p>
            </div>

            <div class="bg-white rounded-lg shadow-sm p-6">
              <div class="aspect-w-16 aspect-h-9 bg-gray-200 rounded-lg mb-4"></div>
              <h3 class="text-lg font-medium text-gray-900">Project Title</h3>
              <p class="text-sm text-gray-500">Last updated: 5 days ago</p>
            </div>

            <div class="bg-white rounded-lg shadow-sm p-6">
              <div class="aspect-w-16 aspect-h-9 bg-gray-200 rounded-lg mb-4"></div>
              <h3 class="text-lg font-medium text-gray-900">Project Title</h3>
              <p class="text-sm text-gray-500">Last updated: 1 week ago</p>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end
end
