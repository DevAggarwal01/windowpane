defmodule AuroraWeb.ProjectLive.Index do
  use AuroraWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold">Projects</h1>
        <.link
          navigate={~p"/projects/new"}
          class="inline-flex items-center px-4 py-2 bg-gray-800 text-white rounded-lg hover:bg-gray-700"
        >
          New Project
        </.link>
      </div>
      <div class="bg-white rounded-lg shadow p-6">
        <p class="text-gray-600">Your projects will appear here.</p>
      </div>
    </div>
    """
  end
end
