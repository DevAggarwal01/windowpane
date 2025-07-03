defmodule WindowpaneWeb.CreatorRegistrationLive do
  use WindowpaneWeb, :live_view

  alias Windowpane.Creators
  alias Windowpane.Creators.Creator

  @impl true
  def mount(_params, _session, socket) do
    changeset = Creators.change_creator_registration(%Creator{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil], layout: {WindowpaneWeb.Layouts, :minimal}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#0073b1]">
      <div class="flex flex-col items-center pt-10 px-4">
        <div class="mb-6">
          <img src={~p"/images/logo-white.png"} alt="Windowpane Logo" class="h-8" />
        </div>
        <h2 class="text-2xl text-white font-light mb-8">Make the most of your creative journey</h2>

        <div class="bg-white rounded-lg p-6 shadow-lg w-full max-w-md">
          <.simple_form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            phx-trigger-action={@trigger_submit}
            action={~p"/creators/log_in?_action=registered"}
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
                  <a href="mailto:business@windowpane.tv" class="text-[#0073b1] hover:underline">business@windowpane.tv</a>
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
                By clicking Join now, you agree to our
                <.link href="#" class="text-[#0073b1] hover:underline">Terms of Service</.link>
                and
                <.link href="#" class="text-[#0073b1] hover:underline">Privacy Policy</.link>
              </p>

              <.button
                phx-disable-with="Creating account..."
                class="w-full bg-[#0073b1] hover:bg-[#006097] text-white font-normal py-2 rounded"
              >
                Join now
              </.button>
            </div>
          </.simple_form>

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
            <.link navigate={~p"/creators/log_in"} class="text-[#0073b1] hover:underline font-medium">
              Sign in
            </.link>
          </p>
        </div>

        <p class="text-center mt-8 text-sm text-white">
          Windowpane Studio Corporation © 2024
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("save", %{"creator" => creator_params}, socket) do
    changeset = Creators.change_creator_registration(%Creator{}, creator_params)

    if changeset.valid? do
      # Validate creator code before proceeding
      case Creators.valid_creator_code?(creator_params["creator_code"]) do
        true ->
          case Stripe.Account.create(%{
            type: "express",
            email: creator_params["email"],
            capabilities: %{transfers: %{requested: true}},
            business_profile: %{
              url: "https://windowpane.tv"
            },
            settings: %{
              payouts: %{
                schedule: %{
                  interval: "manual"
                }
              }
            }
          }) do
            {:ok, acct} ->
              IO.inspect(acct, label: "Created Stripe account")
              # Add stripe_account_id to the creator_params
              creator_params = Map.put(creator_params, "stripe_account_id", acct.id)

              # Register the creator immediately
              case Creators.register_creator(creator_params) do
                {:ok, creator} ->
                  {:ok, _} =
                    Creators.deliver_creator_confirmation_instructions(
                      creator,
                      &url(~p"/confirm/#{&1}")
                    )

                  {:noreply, socket |> assign(trigger_submit: true)}

                {:error, %Ecto.Changeset{} = changeset} ->
                  # If creator registration fails, we should clean up the Stripe account
                  _ = Stripe.Account.delete(acct.id)
                  {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
              end

            {:error, %Stripe.Error{message: message}} ->
              changeset =
                changeset
                |> Ecto.Changeset.add_error(:base, "Failed to create Stripe account: #{message}")
              {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}

            {:error, error} ->
              IO.inspect(error, label: "Unknown error creating Stripe account")
              changeset =
                changeset
                |> Ecto.Changeset.add_error(:base, "Failed to create Stripe account. Please try again later.")
              {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
          end

        false ->
          # Add error to changeset and return it
          changeset = Ecto.Changeset.add_error(changeset, :creator_code, "is invalid")
          {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
      end
    else
      {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  @impl true
  def handle_event("validate", %{"creator" => creator_params}, socket) do
    changeset = Creators.change_creator_registration(%Creator{}, creator_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
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
