defmodule WindowpaneWeb.CreatorLoginModalComponent do
  use WindowpaneWeb, :live_component
  alias Windowpane.Creators
  alias Windowpane.Creators.Creator

  @impl true
  def mount(socket) do
    {:ok, assign(socket, error_message: nil, signup_mode: false, changeset: nil, check_errors: false, trigger_login: false, login_email: nil, login_password: nil)}
  end

  @impl true
  def update(%{show_signup: show_signup} = assigns, socket) do
    changeset = if show_signup, do: Creators.change_creator_registration(%Creator{}), else: nil
    {:ok, assign(socket, signup_mode: show_signup, changeset: changeset)}
  end

  defp current_path(assigns) do
    assigns[:current_path] || "/"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="relative w-full max-w-md border border-white rounded-lg shadow-2xl text-white p-0" style="backdrop-filter: blur(8px); background: rgba(10,10,10,0.8); padding: 2.5rem 2.5rem 2rem 2.5rem;">
        <button
          phx-click="close"
          phx-target={@myself}
          class="absolute top-3 right-4 text-white text-xl opacity-80 hover:opacity-100 focus:outline-none"
          aria-label="Close"
        >
          [x]
        </button>
        <div class="text-left">
          <%= if @signup_mode do %>
            <h2 class="text-3xl font-light mb-1 mt-2">Sign Up</h2>
            <p class="mb-6 text-base">Create your creator account to get started!</p>
            <%= if @check_errors do %>
              <div class="text-red-400 mb-4 text-sm text-center">Oops, something went wrong! Please check the errors below.</div>
            <% end %>
            <%= if @changeset do %>
              <% form = to_form(@changeset, as: "creator") %>
              <.form
                for={form}
                id="creator_registration_modal_form"
                phx-submit="register"
                phx-change="validate"
                phx-target={@myself}
                autocomplete="off"
                class="space-y-3"
              >
                <input
                  name="creator[creator_code]"
                  type="text"
                  value={form[:creator_code].value}
                  placeholder="Creator Code"
                  required
                  class="w-full bg-black bg-opacity-60 border border-white/80 rounded-none px-4 py-2 text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white text-base mb-2"
                  style="font-family: inherit; letter-spacing: 0.01em;"
                />
                <p class="mt-1 text-xs text-gray-400">
                  Need a creator code? Email us at business@windowpane.tv
                </p>
                <input
                  name="creator[name]"
                  type="text"
                  value={form[:name].value}
                  placeholder="Full name"
                  required
                  class="w-full bg-black bg-opacity-60 border border-white/80 rounded-none px-4 py-2 text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white text-base mb-2"
                  style="font-family: inherit; letter-spacing: 0.01em;"
                />
                <input
                  name="creator[email]"
                  type="email"
                  value={form[:email].value}
                  placeholder="Email"
                  required
                  class="w-full bg-black bg-opacity-60 border border-white/80 rounded-none px-4 py-2 text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white text-base mb-2"
                  style="font-family: inherit; letter-spacing: 0.01em;"
                />
                <input
                  name="creator[password]"
                  type="password"
                  value={form[:password].value}
                  placeholder="Password"
                  required
                  class="w-full bg-black bg-opacity-60 border border-white/80 rounded-none px-4 py-2 text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white text-base mb-2"
                  style="font-family: inherit; letter-spacing: 0.01em;"
                />
                <p class="mt-1 text-xs text-gray-400">
                  Must be at least 12 characters with 1 upper case, 1 lower case, and 1 number or special character
                </p>
                <button type="submit" class="w-full text-lg border border-white rounded-none py-2 mt-2 hover:bg-white/10 transition">
                  [sign up]
                </button>
              </.form>
              <%= if @trigger_login do %>
                <form id="auto-login-form" method="post" action={"/creators/log_in?_action=registered&redirect_to=" <> current_path(assigns)} phx-trigger-action={@trigger_login} style="display:none">
                  <input type="hidden" name="creator[email]" value={@login_email} />
                  <input type="hidden" name="creator[password]" value={@login_password} />
                </form>
              <% end %>
            <% end %>
            <div class="flex items-center justify-start text-sm mt-4 mb-2">
              <span>Already have an account? <a href="#" phx-click="toggle_mode" phx-target={@myself} class="underline hover:text-gray-300">Log in</a></span>
            </div>
          <% else %>
            <h2 class="text-3xl font-light mb-1 mt-2">Login</h2>
            <p class="mb-6 text-base">Welcome back to Studio. We all missed you :3</p>
            <%= if @error_message do %>
              <div class="text-red-400 mb-4 text-sm text-center"><%= @error_message %></div>
            <% end %>
            <form method="post" action="/creators/log_in" autocomplete="off" class="space-y-3">
              <input
                name="creator[email]"
                type="email"
                placeholder="Email"
                class="w-full bg-black bg-opacity-60 border border-white/80 rounded-none px-4 py-2 text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white text-base mb-2"
                style="font-family: inherit; letter-spacing: 0.01em;"
                required
              />
              <input
                name="creator[password]"
                type="password"
                placeholder="Password"
                class="w-full bg-black bg-opacity-60 border border-white/80 rounded-none px-4 py-2 text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white text-base mb-2"
                style="font-family: inherit; letter-spacing: 0.01em;"
                required
              />
              <div class="flex items-center justify-start text-sm mt-2 mb-4">
                <span>Don't have an account? <a href="#" phx-click="toggle_mode" phx-target={@myself} class="underline hover:text-gray-300">Sign up</a></span>
              </div>
              <button type="submit" class="w-full text-lg border border-white rounded-none py-2 mt-2 hover:bg-white/10 transition">
                [login]
              </button>
            </form>
          <% end %>
          <p class="mt-8 text-center text-xs text-white/70">
            By continuing, you agree to the <a href="/rules" class="underline">rules</a>.
          </p>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("close", _params, socket) do
    send(self(), :close_login_modal)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_mode", _params, socket) do
    changeset = if !socket.assigns.signup_mode, do: Creators.change_creator_registration(%Creator{}), else: nil
    {:noreply, assign(socket, signup_mode: !socket.assigns.signup_mode, error_message: nil, changeset: changeset, check_errors: false, trigger_login: false, login_email: nil, login_password: nil)}
  end

  @impl true
  def handle_event("register", %{"creator" => creator_params}, socket) do
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

                  {:noreply, assign(socket,
                    trigger_login: true,
                    login_email: creator_params["email"],
                    login_password: creator_params["password"],
                    changeset: socket.assigns.changeset,
                    check_errors: false
                  )}

                {:error, %Ecto.Changeset{} = changeset} ->
                  # If creator registration fails, we should clean up the Stripe account
                  _ = Stripe.Account.delete(acct.id)
                  {:noreply, assign(socket, changeset: changeset, check_errors: true, trigger_login: false, login_email: nil, login_password: nil)}
              end

            {:error, %Stripe.Error{message: message}} ->
              changeset =
                changeset
                |> Ecto.Changeset.add_error(:base, "Failed to create Stripe account: #{message}")
              {:noreply, assign(socket, changeset: changeset, check_errors: true, trigger_login: false, login_email: nil, login_password: nil)}

            {:error, error} ->
              IO.inspect(error, label: "Unknown error creating Stripe account")
              changeset =
                changeset
                |> Ecto.Changeset.add_error(:base, "Failed to create Stripe account. Please try again later.")
              {:noreply, assign(socket, changeset: changeset, check_errors: true, trigger_login: false, login_email: nil, login_password: nil)}
          end

        false ->
          # Add error to changeset and return it
          changeset = Ecto.Changeset.add_error(changeset, :creator_code, "is invalid")
          {:noreply, assign(socket, changeset: changeset, check_errors: true, trigger_login: false, login_email: nil, login_password: nil)}
      end
    else
      {:noreply, assign(socket, changeset: changeset, check_errors: true, trigger_login: false, login_email: nil, login_password: nil)}
    end
  end

  @impl true
  def handle_event("validate", %{"creator" => creator_params}, socket) do
    changeset = Creators.change_creator_registration(%Creator{}, creator_params)
    {:noreply, assign(socket, changeset: Map.put(changeset, :action, :validate))}
  end
end
