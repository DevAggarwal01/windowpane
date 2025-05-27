defmodule AuroraWeb.UserRegistrationLive do
  use AuroraWeb, :live_view

  alias Aurora.Accounts
  alias Aurora.Accounts.User

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})
    socket = assign(socket, trigger_submit: false, check_errors: false)
    {:ok, assign_form(socket, changeset), layout: {AuroraWeb.Layouts, :minimal}}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#0073b1]">
      <div class="flex flex-col items-center pt-10 px-4">
        <div class="mb-6">
          <img src={~p"/images/logo-white.png"} alt="Aurora" class="h-8" />
        </div>
        <h2 class="text-2xl text-white font-light mb-8">Make the most of your journey</h2>

        <div class="bg-white rounded-lg p-6 shadow-lg w-full max-w-md">
          <.simple_form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            phx-trigger-action={@trigger_submit}
            action={~p"/users/log_in?_action=registered"}
            method="post"
          >
            <.error :if={@check_errors}>
              Oops, something went wrong! Please check the errors below.
            </.error>

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
            <p class="mt-1 text-xs text-gray-500">
              Must be at least 12 characters with 1 upper case, 1 lower case, and 1 number or special character
            </p>

            <p class="text-xs text-gray-600 mt-4">
              By clicking Create account, you agree to our
              <.link href="#" class="text-[#0073b1] hover:underline">Terms of Service</.link>
              and
              <.link href="#" class="text-[#0073b1] hover:underline">Privacy Policy</.link>
            </p>

            <:actions>
              <.button
                phx-disable-with="Creating account..."
                class="w-full bg-[#0073b1] hover:bg-[#006097] text-white font-normal py-2 rounded"
              >
                Create account
              </.button>
            </:actions>
          </.simple_form>

          <div class="mt-6 text-center">
            <div class="relative">
              <div class="absolute inset-0 flex items-center">
                <div class="w-full border-t border-gray-300"></div>
              </div>
              <div class="relative flex justify-center text-sm">
                <span class="px-2 bg-white text-gray-500">Already have an account?</span>
              </div>
            </div>

            <.link
              navigate={~p"/users/log_in"}
              class="mt-4 w-full inline-block text-center px-4 py-2 border border-gray-300 rounded-md text-[#0073b1] hover:bg-gray-50"
            >
              Sign in
            </.link>
          </div>
        </div>

        <p class="text-center mt-8 text-sm text-white">
          Aurora Corporation © 2024
        </p>
      </div>
    </div>
    """
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
