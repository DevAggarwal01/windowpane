defmodule AuroraWeb.SocialLive do
  use AuroraWeb, :live_view

  import AuroraWeb.NavComponents

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
      <h1 class="text-3xl font-bold mb-8">Social</h1>
      <div class="bg-white rounded-lg shadow p-6">
          <p class="text-gray-600">Your social feed and connections will appear here.</p>
        </div>
      </div>
    </div>
    """
  end
end
