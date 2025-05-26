defmodule AuroraWeb.CreatorRegistrationLive do
  use AuroraWeb, :live_view

  alias Aurora.Creators
  alias Aurora.Creators.Creator

  @impl true
  def mount(_params, _session, socket) do
    changeset = Creators.change_creator_registration(%Creator{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false, form_validated: false, form_data: nil)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil], layout: {AuroraWeb.Layouts, :minimal}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#0073b1]">
      <div class="flex flex-col items-center pt-10 px-4">
        <div class="mb-6">
          <img src={~p"/images/logo-white.png"} alt="Aurora Logo" class="h-8" />
        </div>
        <h2 class="text-2xl text-white font-light mb-8">Make the most of your creative journey</h2>

        <div class="bg-white rounded-lg p-6 shadow-lg w-full max-w-md">
          <%= if @form_validated do %>
            <div class="text-center">
              <h3 class="text-xl font-medium text-gray-900 mb-4">Account details verified</h3>
              <.button
                phx-click="setup_billing"
                class="w-full bg-[#0073b1] hover:bg-[#006097] text-white font-normal py-2 rounded"
              >
                Setup billing
              </.button>
            </div>
          <% else %>
            <.simple_form
              for={@form}
              id="registration_form"
              phx-submit="save"
              phx-change="validate"
              phx-trigger-action={@trigger_submit}
              action={~p"/log_in?_action=registered"}
              method="post"
            >
              <.error :if={@check_errors}>
                Oops, something went wrong! Please check the errors below.
              </.error>

              <div class="space-y-4">
                <div>
                  <.input
                    field={@form[:creator_code]}
                    type="text"
                    label="Creator Code"
                    required
                    class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-[#0073b1] focus:border-[#0073b1]"
                  />
                  <p class="mt-1 text-sm text-gray-500">
                    Need a creator code? Email us at
                    <a href="mailto:abc@gmail.com" class="text-[#0073b1] hover:underline">abc@gmail.com</a>
                  </p>
                </div>

                <.input
                  field={@form[:name]}
                  type="text"
                  label="Full name"
                  required
                  class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-[#0073b1] focus:border-[#0073b1]"
                />

                <.input
                  field={@form[:email]}
                  type="email"
                  label="Email"
                  required
                  class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-[#0073b1] focus:border-[#0073b1]"
                />

                <div>
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
                </div>

                <p class="text-xs text-gray-600">
                  By clicking Next, you agree to our
                  <.link href="#" class="text-[#0073b1] hover:underline">Terms of Service</.link>
                  and
                  <.link href="#" class="text-[#0073b1] hover:underline">Privacy Policy</.link>
                </p>

                <.button
                  phx-disable-with="Validating..."
                  class="w-full bg-[#0073b1] hover:bg-[#006097] text-white font-normal py-2 rounded"
                >
                  Next
                </.button>
              </div>
            </.simple_form>
          <% end %>

          <div class="mt-4 text-center">
            <div class="relative">
              <div class="absolute inset-0 flex items-center">
                <div class="w-full border-t border-gray-300"></div>
              </div>
              <div class="relative flex justify-center text-sm">
                <span class="px-2 bg-white text-gray-500">or</span>
              </div>
            </div>
          </div>

          <p class="text-center mt-4 text-sm text-gray-600">
            Already have an account?
            <.link navigate={~p"/log_in"} class="text-[#0073b1] hover:underline font-medium">
              Sign in
            </.link>
          </p>
        </div>

        <p class="text-center mt-8 text-sm text-white">
          Aurora Studio Corporation © 2024
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("save", %{"creator" => creator_params}, socket) do
    changeset = Creators.change_creator_registration(%Creator{}, creator_params)

    if changeset.valid? do
      # Store the validated data in socket assigns
      socket =
        socket
        |> assign(:form_data, creator_params)
        |> assign(:form_validated, true)

      {:noreply, socket}
    else
      {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  @impl true
  def handle_event("validate", %{"creator" => creator_params}, socket) do
    changeset = Creators.change_creator_registration(%Creator{}, creator_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  @impl true
  def handle_event("setup_billing", _params, socket) do
    # Now we can use the stored form_data to register the creator
    case Creators.register_creator(socket.assigns.form_data) do
      {:ok, creator} ->
        {:ok, _} =
          Creators.deliver_creator_confirmation_instructions(
            creator,
            &url(~p"/confirm/#{&1}")
          )

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "creator")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
