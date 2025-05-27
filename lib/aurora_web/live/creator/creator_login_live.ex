defmodule AuroraWeb.CreatorLoginLive do
  use AuroraWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns, :email)
    form = to_form(%{"email" => email}, as: "creator")
    {:ok, assign(socket, form: form, trigger_submit: false), layout: {AuroraWeb.Layouts, :minimal}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#0073b1]">
      <div class="flex flex-col items-center pt-10 px-4">
        <div class="mb-6">
          <img src={~p"/images/logo-white.png"} alt="Aurora Studio" class="h-8" />
        </div>
        <h2 class="text-2xl text-white font-light mb-8">Welcome back to Studio</h2>

        <div class="bg-white rounded-lg p-6 shadow-lg w-full max-w-md">
          <.simple_form for={@form} id="login_form" action={~p"/creators/log_in"} phx-update="ignore">
            <.input
              field={@form[:email]}
              type="email"
              label="Email"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-[#0073b1] focus:border-[#0073b1]"
            />

            <.input
              field={@form[:password]}
              type="password"
              label="Password"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-[#0073b1] focus:border-[#0073b1]"
            />

            <div class="flex items-center justify-between">
              <label class="flex items-center gap-2 cursor-pointer">
                <.input
                  field={@form[:remember_me]}
                  type="checkbox"
                  class="rounded border-gray-300 text-[#0073b1] focus:ring-[#0073b1]"
                />
                <span class="text-sm text-gray-600">Keep me signed in</span>
              </label>
              <.link navigate={~p"/creators/reset_password"} class="text-sm text-[#0073b1] hover:underline">
                Forgot password?
              </.link>
            </div>

            <:actions>
              <.button
                phx-disable-with="Signing in..."
                class="w-full bg-[#0073b1] hover:bg-[#006097] text-white font-normal py-2 rounded"
              >
                Sign in to Studio
              </.button>
            </:actions>
          </.simple_form>

          <div class="mt-6 text-center">
            <div class="relative">
              <div class="absolute inset-0 flex items-center">
                <div class="w-full border-t border-gray-300"></div>
              </div>
              <div class="relative flex justify-center text-sm">
                <span class="px-2 bg-white text-gray-500">New to Aurora Studio?</span>
              </div>
            </div>

            <.link
              navigate={~p"/creators/register"}
              class="mt-4 w-full inline-block text-center px-4 py-2 border border-gray-300 rounded-md text-[#0073b1] hover:bg-gray-50"
            >
              Join Studio now
            </.link>
          </div>
        </div>

        <p class="text-center mt-8 text-sm text-white">
          Aurora Studio Corporation © 2024
        </p>
      </div>
    </div>
    """
  end
end
