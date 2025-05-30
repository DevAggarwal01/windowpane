defmodule AuroraWeb.NavComponents do
  use Phoenix.Component
  use AuroraWeb, :verified_routes  # This gives us access to ~p sigil

  alias Phoenix.LiveView.JS
  import AuroraWeb.CoreComponents

  attr :current_path, :atom, required: true
  attr :is_creator, :boolean, required: true
  attr :class, :string, default: nil

  def main_header(assigns) do
    ~H"""
    <header class={["bg-gray-800 text-white", @class]}>
      <div class="container mx-auto px-4">
        <div class="flex items-center justify-between h-16">
          <div class="flex items-center">
            <div class="text-xl font-semibold">Aurora</div>
            <nav class="ml-10 flex space-x-8">
              <.nav_link navigate={~p"/dashboard"} active={@current_path == :show}>
                Dashboard
              </.nav_link>
              <.nav_link navigate={~p"/browse"} active={@current_path == :browse}>
                Browse
              </.nav_link>
              <.nav_link navigate={~p"/library"} active={@current_path == :library}>
                Library
              </.nav_link>
              <.nav_link navigate={~p"/social"} active={@current_path == :social}>
                Social
              </.nav_link>
            </nav>
          </div>
          <div class="flex items-center space-x-4">
            <%= if @is_creator do %>
              <.link
                navigate={~p"/creators/settings"}
                class="text-gray-300 hover:text-white px-3 py-2 rounded-md text-sm font-medium"
              >
                Settings
              </.link>
              <.link
                href={~p"/creators/log_out"}
                method="delete"
                class="text-gray-300 hover:text-white px-3 py-2 rounded-md text-sm font-medium"
              >
                Log out
              </.link>
            <% else %>
              <.link
                navigate={~p"/users/settings"}
                class="text-gray-300 hover:text-white px-3 py-2 rounded-md text-sm font-medium"
              >
                Settings
              </.link>
              <.link
                href={~p"/users/log_out"}
                method="delete"
                class="text-gray-300 hover:text-white px-3 py-2 rounded-md text-sm font-medium"
              >
                Log out
              </.link>
            <% end %>
          </div>
        </div>
      </div>
    </header>
    """
  end

  def nav_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "px-3 py-2 rounded-md text-sm font-medium",
        @active && "bg-gray-900 text-white",
        !@active && "text-gray-300 hover:bg-gray-700 hover:text-white"
      ]}
    >
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end
end
