defmodule AuroraWeb.SocialLive do
  use AuroraWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Social</h1>
      <div class="bg-white rounded-lg shadow p-6">
        <p class="text-gray-600">Connect with other users and creators here.</p>
      </div>
    </div>
    """
  end
end
