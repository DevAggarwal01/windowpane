defmodule AuroraWeb.HomeLive do
  use AuroraWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <nav class="bg-white shadow">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between h-16">
            <div class="flex">
              <div class="flex-shrink-0 flex items-center">
                <img class="h-8 w-auto" src={~p"/images/logo.png"} alt="Aurora" />
              </div>
            </div>
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.link
                  navigate={~p"/settings"}
                  class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-gray-700 bg-gray-100 hover:bg-gray-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-brand"
                >
                  Settings
                </.link>
                <.link
                  href={~p"/log_out"}
                  method="delete"
                  class="ml-4 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-brand hover:bg-accent focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-brand"
                >
                  Log out
                </.link>
              </div>
            </div>
          </div>
        </div>
      </nav>

      <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div class="px-4 py-6 sm:px-0">
          <div class="border-4 border-dashed border-gray-200 rounded-lg h-96 p-4">
            <h1 class="text-2xl font-semibold text-gray-900">Welcome to Aurora</h1>
            <p class="mt-2 text-gray-600">Your personal dashboard</p>
          </div>
        </div>
      </main>
    </div>
    """
  end
end
