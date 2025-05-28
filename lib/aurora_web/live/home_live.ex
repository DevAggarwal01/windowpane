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

    show_billing_popup = is_creator && socket.assigns[:current_creator] && !socket.assigns[:current_creator].onboarded

    {:ok, assign(socket,
      user: user,
      is_creator: is_creator,
      stats: stats,
      current_path: socket.assigns.live_action,
      show_billing_popup: show_billing_popup
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <.main_header current_path={@current_path} is_creator={@is_creator} />

      <%= if @show_billing_popup do %>
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-50">
          <div class="fixed inset-0 z-50 overflow-y-auto">
            <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
              <div class="relative transform overflow-hidden rounded-lg bg-white px-4 pb-4 pt-5 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg sm:p-6">
                <div>
                  <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-blue-100">
                    <svg class="h-6 w-6 text-[#0073b1]" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 002.25-2.25V6.75A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25v10.5A2.25 2.25 0 004.5 19.5z" />
                    </svg>
                  </div>
                  <div class="mt-3 text-center sm:mt-5">
                    <h3 class="text-xl font-semibold leading-6 text-gray-900">
                      Set Up Your Billing Information
                    </h3>
                    <div class="mt-4">
                      <p class="text-gray-600">
                        Before you can start uploading content and earning money, we need to set up your billing information. This is required so we can pay you for your content.
                      </p>
                      <p class="mt-2 text-sm text-gray-500">
                        You won't be charged anything - this is just so we can send you money!
                      </p>
                    </div>
                  </div>
                </div>
                <div class="mt-6 sm:mt-6 sm:grid sm:grid-flow-row-dense sm:grid-cols-2 sm:gap-3">
                  <.link
                    navigate={~p"/creators/settings"}
                    class="inline-flex w-full justify-center rounded-md bg-[#0073b1] px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-[#006097] sm:col-start-2"
                  >
                    Set up now
                  </.link>
                  <.link
                    navigate={~p"/creators/log_out"}
                    class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:col-start-1 sm:mt-0"
                  >
                    Log out
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

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
