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
          <div class="text-xl font-semibold">Aurora</div>
          <div class="flex items-center space-x-8">
            <nav class="flex space-x-8">
              <%= if @is_creator do %>
                <.link navigate={~p"/dashboard"} class="text-gray-300 hover:text-white">Dashboard</.link>
              <% end %>
              <.link navigate={~p"/browse"} class="text-gray-300 hover:text-white">Browse</.link>
              <.link navigate={~p"/library"} class="text-gray-300 hover:text-white">My Library</.link>
              <.link navigate={~p"/social"} class="text-gray-300 hover:text-white">Social</.link>
              <.link navigate={if(@is_creator, do: ~p"/creators/settings", else: ~p"/users/settings")} class="text-gray-300 hover:text-white">Account Settings</.link>
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
    """
  end
end
