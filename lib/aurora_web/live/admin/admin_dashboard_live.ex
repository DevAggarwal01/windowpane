defmodule AuroraWeb.Admin.AdminDashboardLive do
  use AuroraWeb, :live_view

  alias Aurora.Administration

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_admin] do
      accounts = Administration.list_accounts()
      IO.puts("Current admin role: #{socket.assigns.current_admin.role}")
      admins = if socket.assigns.current_admin.role == "superadmin", do: Administration.list_admins(), else: []

      {:ok,
       assign(socket,
         page_title: "Admin Dashboard",
         stats: %{
           total_users: Enum.count(accounts, & &1.type == "user"),
           total_creators: Enum.count(accounts, & &1.type == "creator"),
           total_content: 0,
           total_revenue: "$0.00"
         },
         selected_tab: "overview",
         admin_role: socket.assigns.current_admin.role,
         account_filter: "all",
         filtered_accounts: accounts,
         admins: admins
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in as an admin to access this page.")
       |> redirect(to: ~p"/log_in")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100">
      <nav class="bg-white shadow-sm">
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="flex h-16 justify-between">
            <div class="flex">
              <div class="flex flex-shrink-0 items-center">
                <img class="h-8 w-auto" src={~p"/images/logo.png"} alt="Aurora Admin" />
                <span class="ml-2 text-lg font-semibold text-gray-900">Admin</span>
              </div>
              <div class="hidden sm:ml-6 sm:flex sm:space-x-8">
                <button
                  phx-click="select-tab"
                  phx-value-tab="overview"
                  class={"#{if @selected_tab == "overview", do: "border-brand text-gray-900", else: "border-transparent text-gray-500"} inline-flex items-center border-b-2 px-1 pt-1 text-sm font-medium"}
                >
                  Overview
                </button>
                <button
                  phx-click="select-tab"
                  phx-value-tab="accounts"
                  class={"#{if @selected_tab == "accounts", do: "border-brand text-gray-900", else: "border-transparent text-gray-500"} inline-flex items-center border-b-2 px-1 pt-1 text-sm font-medium"}
                >
                  Accounts
                </button>
                <button
                  phx-click="select-tab"
                  phx-value-tab="content"
                  class={"#{if @selected_tab == "content", do: "border-brand text-gray-900", else: "border-transparent text-gray-500"} inline-flex items-center border-b-2 px-1 pt-1 text-sm font-medium"}
                >
                  Content
                </button>
              </div>
            </div>
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <span class="text-sm text-gray-500 mr-4">
                  <%= @current_admin.email %> (<%= String.capitalize(@admin_role) %>)
                </span>
                <.link
                  href={~p"/settings"}
                  class="relative inline-flex items-center gap-x-1.5 rounded-md bg-brand px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
                >
                  Settings
                </.link>
                <.link
                  href={~p"/log_out"}
                  method="delete"
                  class="relative inline-flex items-center gap-x-1.5 rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
                >
                  Log out
                </.link>
              </div>
            </div>
          </div>
        </div>
      </nav>

      <main class="py-10">
        <div class="mx-auto max-w-7xl sm:px-6 lg:px-8">
          <%= case @selected_tab do %>
            <% "overview" -> %>
              <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
                <div class="overflow-hidden rounded-lg bg-white shadow">
                  <div class="p-5">
                    <div class="flex items-center">
                      <div class="flex-shrink-0">
                        <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                        </svg>
                      </div>
                      <div class="ml-5 w-0 flex-1">
                        <dl>
                          <dt class="truncate text-sm font-medium text-gray-500">Total Users</dt>
                          <dd class="text-lg font-semibold text-gray-900"><%= @stats.total_users %></dd>
                        </dl>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="overflow-hidden rounded-lg bg-white shadow">
                  <div class="p-5">
                    <div class="flex items-center">
                      <div class="flex-shrink-0">
                        <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                        </svg>
                      </div>
                      <div class="ml-5 w-0 flex-1">
                        <dl>
                          <dt class="truncate text-sm font-medium text-gray-500">Total Creators</dt>
                          <dd class="text-lg font-semibold text-gray-900"><%= @stats.total_creators %></dd>
                        </dl>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="overflow-hidden rounded-lg bg-white shadow">
                  <div class="p-5">
                    <div class="flex items-center">
                      <div class="flex-shrink-0">
                        <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                        </svg>
                      </div>
                      <div class="ml-5 w-0 flex-1">
                        <dl>
                          <dt class="truncate text-sm font-medium text-gray-500">Total Content</dt>
                          <dd class="text-lg font-semibold text-gray-900"><%= @stats.total_content %></dd>
                        </dl>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="overflow-hidden rounded-lg bg-white shadow">
                  <div class="p-5">
                    <div class="flex items-center">
                      <div class="flex-shrink-0">
                        <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                      </div>
                      <div class="ml-5 w-0 flex-1">
                        <dl>
                          <dt class="truncate text-sm font-medium text-gray-500">Total Revenue</dt>
                          <dd class="text-lg font-semibold text-gray-900"><%= @stats.total_revenue %></dd>
                        </dl>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

            <% "accounts" -> %>
              <div class="bg-white shadow rounded-lg">
                <div class="p-6">
                  <div class="sm:flex sm:items-center">
                    <div class="sm:flex-auto">
                      <h2 class="text-lg font-medium text-gray-900">Account Management</h2>
                      <p class="mt-1 text-sm text-gray-500">Manage all accounts in the system.</p>
                    </div>
                    <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
                      <div class="flex space-x-2">
                        <button
                          type="button"
                          phx-click="filter-accounts"
                          phx-value-type="all"
                          class={"#{if @account_filter == "all", do: "bg-brand text-white", else: "bg-white text-gray-900 ring-1 ring-inset ring-gray-300"} rounded-md px-3 py-2 text-sm font-semibold shadow-sm hover:bg-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"}
                        >
                          All
                        </button>
                        <button
                          type="button"
                          phx-click="filter-accounts"
                          phx-value-type="users"
                          class={"#{if @account_filter == "users", do: "bg-brand text-white", else: "bg-white text-gray-900 ring-1 ring-inset ring-gray-300"} rounded-md px-3 py-2 text-sm font-semibold shadow-sm hover:bg-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"}
                        >
                          Users
                        </button>
                        <button
                          type="button"
                          phx-click="filter-accounts"
                          phx-value-type="creators"
                          class={"#{if @account_filter == "creators", do: "bg-brand text-white", else: "bg-white text-gray-900 ring-1 ring-inset ring-gray-300"} rounded-md px-3 py-2 text-sm font-semibold shadow-sm hover:bg-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"}
                        >
                          Creators
                        </button>
                        <%= if @admin_role == "superadmin" do %>
                          <button
                            type="button"
                            phx-click="filter-accounts"
                            phx-value-type="admins"
                            class={"#{if @account_filter == "admins", do: "bg-brand text-white", else: "bg-white text-gray-900 ring-1 ring-inset ring-gray-300"} rounded-md px-3 py-2 text-sm font-semibold shadow-sm hover:bg-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"}
                          >
                            Admins
                          </button>
                          <%= if @account_filter == "admins" do %>
                            <button
                              type="button"
                              phx-click="new-admin"
                              class="rounded-md bg-brand px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
                            >
                              Add Admin
                            </button>
                          <% end %>
                        <% end %>
                      </div>
                    </div>
                  </div>
                  <div class="mt-8 flow-root">
                    <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
                      <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
                        <table class="min-w-full divide-y divide-gray-300">
                          <thead>
                            <tr>
                              <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-0">Email</th>
                              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Type</th>
                              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Status</th>
                              <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Joined</th>
                              <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-0">
                                <span class="sr-only">Actions</span>
                              </th>
                            </tr>
                          </thead>
                          <tbody class="divide-y divide-gray-200">
                            <%= case @account_filter do %>
                              <% "admins" -> %>
                                <%= for admin <- @admins do %>
                                  <tr>
                                    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-0"><%= admin.email %></td>
                                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                                      <span class={"inline-flex items-center rounded-md px-2 py-1 text-xs font-medium #{if admin.role == "superadmin", do: "bg-purple-50 text-purple-700", else: "bg-blue-50 text-blue-700"}"}>
                                        <%= String.capitalize(admin.role) %>
                                      </span>
                                    </td>
                                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                                      <span class={"inline-flex items-center rounded-md px-2 py-1 text-xs font-medium #{if admin.confirmed_at, do: "bg-green-50 text-green-700", else: "bg-yellow-50 text-yellow-700"}"}>
                                        <%= if admin.confirmed_at, do: "Active", else: "Pending" %>
                                      </span>
                                    </td>
                                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= Calendar.strftime(admin.inserted_at, "%Y-%m-%d") %></td>
                                    <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-0">
                                      <.link
                                        href="#"
                                        class="text-brand hover:text-accent"
                                        phx-click="edit-admin"
                                        phx-value-id={admin.id}
                                      >
                                        Edit<span class="sr-only">, <%= admin.email %></span>
                                      </.link>
                                    </td>
                                  </tr>
                                <% end %>
                              <% _ -> %>
                                <%= for account <- @filtered_accounts do %>
                                  <tr>
                                    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-0"><%= account.email %></td>
                                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                                      <span class={"inline-flex items-center rounded-md px-2 py-1 text-xs font-medium #{if account.type == "creator", do: "bg-indigo-50 text-indigo-700", else: "bg-gray-50 text-gray-700"}"}>
                                        <%= String.capitalize(account.type) %>
                                      </span>
                                    </td>
                                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                                      <span class={"inline-flex items-center rounded-md px-2 py-1 text-xs font-medium #{if account.confirmed_at, do: "bg-green-50 text-green-700", else: "bg-yellow-50 text-yellow-700"}"}>
                                        <%= if account.confirmed_at, do: "Active", else: "Pending" %>
                                      </span>
                                    </td>
                                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= Calendar.strftime(account.inserted_at, "%Y-%m-%d") %></td>
                                    <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-0">
                                      <.link
                                        href="#"
                                        class="text-brand hover:text-accent"
                                        phx-click="view-account"
                                        phx-value-id={account.id}
                                      >
                                        View<span class="sr-only">, <%= account.email %></span>
                                      </.link>
                                    </td>
                                  </tr>
                                <% end %>
                            <% end %>
                          </tbody>
                        </table>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

            <% "content" -> %>
              <div class="bg-white shadow rounded-lg">
                <div class="p-6">
                  <h2 class="text-lg font-medium text-gray-900">Content Management</h2>
                  <p class="mt-1 text-sm text-gray-500">Review and moderate content.</p>
                  <!-- Add content management UI here -->
                </div>
              </div>
          <% end %>
        </div>
      </main>
    </div>
    """
  end

  @impl true
  def handle_event("select-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, selected_tab: tab)}
  end

  @impl true
  def handle_event("filter-accounts", %{"type" => filter_type}, socket) do
    accounts = Administration.list_accounts(filter_type)
    {:noreply, assign(socket, account_filter: filter_type, filtered_accounts: accounts)}
  end

  @impl true
  def handle_event("view-account", %{"id" => account_id}, socket) do
    # TODO: Implement account viewing functionality
    {:noreply, socket}
  end

  @impl true
  def handle_event("new-admin", _params, socket) do
    # TODO: Implement new admin form
    {:noreply, socket}
  end

  @impl true
  def handle_event("edit-admin", %{"id" => admin_id}, socket) do
    # TODO: Implement admin editing
    {:noreply, socket}
  end
end
