defmodule AuroraWeb.CreatorSettingsLive do
  use AuroraWeb, :live_view

  alias Aurora.Creators
  import AuroraWeb.NavComponents
  alias Stripe.Session

  @impl true
  def mount(_params, _session, socket) do
    creator = socket.assigns.current_creator
    email_changeset = Creators.change_creator_email(creator)
    password_changeset = Creators.change_creator_password(creator)
    creator_plans = Creators.fetch_creator_plans()

    socket =
      socket
      |> assign(:current_email, creator.email)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_password_for_email, nil)
      |> assign(:password_form_current_password, nil)
      |> assign(:current_password_for_password, nil)
      |> assign(:trigger_submit, false)
      |> assign(:creator_plans, creator_plans)
      |> assign(:current_plan, creator.plan)
      |> assign(:selected_plan, nil)
      |> assign(:selected_price_id, nil)
      |> assign_form(:password_form, password_changeset)
      |> assign_form(:email_form, email_changeset)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <.main_header current_path={@live_action} is_creator={true} />

      <div class="container mx-auto px-4 py-8">
        <.header class="text-center">
          <h1 class="text-4xl font-bold tracking-tight text-gray-900">Account Settings</h1>
        </.header>

        <div class="space-y-12 divide-y max-w-2xl mx-auto">
          <!-- Creator Plans Section -->
          <div class="pt-8">
            <h2 class="text-2xl font-semibold mb-6">Billing</h2>
            <button
              phx-click="setup_billing"
              class="w-full sm:w-auto bg-[#0073b1] hover:bg-[#006097] text-white font-medium py-2 px-4 rounded transition-colors"
            >
              Setup Billing
            </button>

            <%!-- Commented out plans section
            <%= if @selected_plan do %>
              <div class="mb-6 bg-blue-50 p-4 rounded-lg border border-blue-200">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-blue-800 font-medium">
                      You selected the <%= @selected_plan.name %> plan at $<%= @selected_plan.price %>/month
                    </p>
                    <p class="text-blue-600 text-sm mt-1">
                      Click the button to proceed with billing setup
                    </p>
                  </div>
                  <div class="flex gap-3">
                    <button
                      phx-click="cancel_plan_selection"
                      class="px-3 py-2 text-sm text-blue-700 hover:text-blue-800"
                    >
                      Cancel
                    </button>
                    <button
                      phx-click="setup_billing"
                      phx-value-price-id={@selected_price_id}
                      class="px-4 py-2 bg-[#0073b1] hover:bg-[#006097] text-white font-medium rounded transition-colors"
                    >
                      Setup Billing
                    </button>
                  </div>
                </div>
              </div>
            <% end %>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <%= for plan <- @creator_plans do %>
                <div class={[
                  "bg-white rounded-lg shadow-sm p-6 border transition-colors cursor-pointer",
                  plan.id == @current_plan && "border-[#0073b1] ring-2 ring-[#0073b1]" || "border-gray-200 hover:border-[#0073b1]"
                ]}>
                  <div class="flex justify-between items-start mb-2">
                    <h3 class="text-xl font-semibold text-gray-900"><%= plan.name %></h3>
                    <%= if plan.id == @current_plan do %>
                      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-[#0073b1] text-white">
                        Current Plan
                      </span>
                    <% end %>
                  </div>
                  <p class="text-gray-600 mb-4 min-h-[3rem]"><%= plan.description %></p>
                  <div class="flex items-baseline">
                    <span class="text-3xl font-bold text-[#0073b1]">$<%= plan.price %></span>
                    <span class="text-gray-500 ml-1">/month</span>
                  </div>
                  <%= if plan.id != @current_plan do %>
                    <button
                      phx-click="select_plan"
                      phx-value-price-id={plan.price_id}
                      phx-value-plan-id={plan.id}
                      class="mt-4 w-full bg-[#0073b1] hover:bg-[#006097] text-white font-medium py-2 px-4 rounded transition-colors"
                    >
                      Select Plan
                    </button>
                  <% else %>
                    <div class="mt-4 w-full text-center text-gray-500 font-medium py-2 px-4">
                      Current Plan
                    </div>
                    <%= if plan.id != "free" do %>
                      <button
                        phx-click="deactivate_plan"
                        data-confirm="Are you sure you want to deactivate your current plan? This will downgrade you to the free plan."
                        class="mt-2 w-full bg-red-600 hover:bg-red-700 text-white font-medium py-2 px-4 rounded transition-colors"
                      >
                        Deactivate
                      </button>
                    <% end %>
                  <% end %>
                </div>
              <% end %>
            </div>
            --%>
          </div>
          <div>
            <h2 class="text-2xl font-semibold mb-6">Authentication Settings</h2>
            <.simple_form
              for={@email_form}
              id="email_form"
              phx-submit="update_email"
              phx-change="validate_email"
            >
              <.input field={@email_form[:email]} type="email" label="Email" required />
              <.input
                field={@email_form[:current_password]}
                name="current_password"
                id="current_password_for_email"
                type="password"
                label="Current password"
                value={@email_form_current_password}
                required
              />
              <:actions>
                <.button phx-disable-with="Changing...">Change Email</.button>
              </:actions>
            </.simple_form>
          </div>
          <div>
            <.simple_form
              for={@password_form}
              id="password_form"
              action={~p"/creators/log_in?_action=password_updated"}
              method="post"
              phx-change="validate_password"
              phx-submit="update_password"
              phx-trigger-action={@trigger_submit}
            >
              <.input
                field={@password_form[:email]}
                type="text"
                style="display: none;"
                id="hidden_creator_email"
                value={@current_email}
              />
              <.input field={@password_form[:password]} type="password" label="New password" required />
              <.input
                field={@password_form[:password_confirmation]}
                type="password"
                label="Confirm new password"
              />
              <.input
                field={@password_form[:current_password]}
                name="current_password"
                type="password"
                label="Current password"
                id="current_password_for_password"
                value={@password_form_current_password}
                required
              />
              <:actions>
                <.button phx-disable-with="Changing...">Change Password</.button>
              </:actions>
            </.simple_form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Creators.update_creator_email(socket.assigns.current_creator, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/creators/settings")}
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "creator" => creator_params} = params
    email_changeset = Creators.change_creator_email(socket.assigns.current_creator, creator_params)

    socket =
      assign(socket,
        email_form: to_form(email_changeset),
        email_form_current_password: password
      )

    {:noreply, socket}
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "creator" => creator_params} = params
    password_changeset = Creators.change_creator_password(socket.assigns.current_creator, creator_params)

    {:noreply,
     socket
     |> assign(:password_form, to_form(password_changeset))
     |> assign(:password_form_current_password, password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "creator" => creator_params} = params
    creator = socket.assigns.current_creator

    case Creators.apply_creator_email(creator, password, creator_params) do
      {:ok, applied_creator} ->
        Creators.deliver_creator_update_email_instructions(
          applied_creator,
          creator.email,
          &url(~p"/creators/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "creator" => creator_params} = params
    creator = socket.assigns.current_creator

    case Creators.update_creator_password(creator, password, creator_params) do
      {:ok, creator} ->
        password_changeset = Creators.change_creator_password(creator)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(:password_form, password_changeset)}

      {:error, changeset} ->
        {:noreply, assign(socket, :password_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("select_plan", %{"price-id" => price_id, "plan-id" => plan_id}, socket) do
    selected_plan = Enum.find(socket.assigns.creator_plans, &(&1.id == plan_id))
    {:noreply, socket
      |> assign(:selected_plan, selected_plan)
      |> assign(:selected_price_id, price_id)}
  end

  @impl true
  def handle_event("cancel_plan_selection", _params, socket) do
    {:noreply, socket
      |> assign(:selected_plan, nil)
      |> assign(:selected_price_id, nil)}
  end

  @impl true
  def handle_event("setup_billing", _params, socket) do
    creator = socket.assigns.current_creator

    if is_nil(creator.stripe_account_id) do
      {:noreply, socket |> put_flash(:error, "No Stripe account found. Please contact support.")}
    else
      refresh_url = URI.to_string(%{
        URI.parse(url(~p"/creators/settings?status=failure")) |
        host: "studio.aurora.com",
        port: 4000
      })

      return_url = URI.to_string(%{
        URI.parse(url(~p"/creators/settings?status=success")) |
        host: "studio.aurora.com",
        port: 4000
      })

      case Stripe.AccountLink.create(%{
        account: creator.stripe_account_id,
        refresh_url: refresh_url, # TODO need to change url during production
        return_url: return_url, # TODO need to change url during production
        type: "account_onboarding"
      }) do
        {:ok, link} ->
          IO.inspect(link, label: "Created Stripe account link")
          {:noreply, redirect(socket, external: link.url)}

        {:error, %Stripe.Error{} = error} ->
          IO.inspect(error, label: "Stripe error during account link creation")
          {:noreply, socket |> put_flash(:error, "Stripe error: #{error.message}")}

        {:error, error} ->
          IO.inspect(error, label: "Unknown error during account link creation")
          {:noreply, socket |> put_flash(:error, "Failed to setup billing. Please try again later.")}
      end
    end
  end

  def handle_params(%{"status" => "success"}, _uri, socket) do
    creator = socket.assigns.current_creator
    IO.inspect(creator, label: "Current creator before Stripe check")

    case get_connected_account(creator.stripe_account_id) do
      {:ok, response} when is_map(response) ->
        IO.inspect(response, label: "Raw Stripe response")
        case response do
          %{"details_submitted" => true} ->
            IO.inspect("Details submitted is true, attempting to update creator")
            case Creators.update_creator(creator, %{onboarded: true}) do
              {:ok, updated_creator} ->
                IO.inspect(updated_creator, label: "Successfully updated creator")
                {:noreply,
                 socket
                 |> assign(:current_creator, updated_creator)
                 |> put_flash(:info, "Stripe onboarding complete!")}

              {:error, changeset} ->
                IO.inspect(changeset, label: "Failed to update creator")
                {:noreply, put_flash(socket, :error, "Failed to update onboarding status. Please try again.")}
            end

          %{"details_submitted" => false} ->
            IO.puts("Details submitted is false")
            {:noreply, put_flash(socket, :error, "Onboarding incomplete. Please try again.")}

          _ ->
            IO.inspect(response, label: "Unexpected Stripe response format")
            {:noreply, put_flash(socket, :error, "Could not determine onboarding status. Please try again.")}
        end

      {:error, %Stripe.Error{} = error} ->
        IO.inspect(error, label: "Stripe API error")
        {:noreply, put_flash(socket, :error, "Stripe error: #{error.message}")}

      unexpected ->
        IO.inspect(unexpected, label: "Unexpected response structure from Stripe")
        {:noreply, put_flash(socket, :error, "Failed to verify onboarding status. Please try again.")}
    end
  end

  def get_connected_account(account_id) do
    secret_key = System.get_env("STRIPE_SECRET")

    case Req.get("https://api.stripe.com/v1/accounts/#{account_id}",
      auth: {secret_key, ""},
      headers: [{"Content-Type", "application/x-www-form-urlencoded"}]
    ) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} ->
        IO.inspect({status, body}, label: "Stripe API error response")
        {:error, "Stripe API error: #{status}"}
      {:error, error} ->
        IO.inspect(error, label: "Request failed")
        {:error, "Failed to connect to Stripe"}
    end
  end

  def handle_params(%{"status" => "failure"}, _uri, socket) do
    {:noreply, put_flash(socket, :error, "Onboarding was canceled or failed.")}
  end

  # Default clause for when there are no parameters
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("deactivate_plan", _params, socket) do
    # TODO: Implement plan deactivation logic
    {:noreply, socket |> put_flash(:info, "Plan deactivation will be implemented soon")}
  end

  defp assign_form(socket, name, %Ecto.Changeset{} = changeset) do
    assign(socket, name, to_form(changeset))
  end
end
