defmodule WindowpaneWeb.NavComponents do
  use Phoenix.Component
  use WindowpaneWeb, :verified_routes  # This gives us access to ~p sigil

  alias Phoenix.LiveView.JS
  import WindowpaneWeb.CoreComponents

  attr :current_path, :atom, required: true
  attr :is_creator, :boolean, required: true
  attr :class, :string, default: nil

  def main_header(assigns) do
    ~H"""
    <header class={["bg-black text-white", @class]}>
      <div class="container mx-auto px-4">
        <div class="flex items-center justify-between h-16">
          <div class="flex items-center">
            <.link navigate={~p"/dashboard"} class="text-2xl font-semibold text-white cursor-pointer transition-transform duration-150 hover:scale-110">
              Windowpane Studio
            </.link>
          </div>
          <div class="flex items-center space-x-8">
            <.link navigate={~p"/wallet"} class="text-sm font-medium text-white cursor-pointer transition-transform duration-150 hover:scale-110">
              [wallet]
            </.link>
            <.link navigate={~p"/social"} class="text-sm font-medium text-white cursor-pointer transition-transform duration-150 hover:scale-110">
              [social]
            </.link>
            <.link
              navigate={~p"/creators/settings"}
              class="text-sm font-medium text-white cursor-pointer transition-transform duration-150 hover:scale-110"
            >
              [settings]
            </.link>
            <.link
              href={~p"/creators/log_out"}
              method="delete"
              class="text-sm font-medium text-white cursor-pointer transition-transform duration-150 hover:scale-110"
            >
              [log out]
            </.link>
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
