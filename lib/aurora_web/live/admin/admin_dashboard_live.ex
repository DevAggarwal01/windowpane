defmodule AuroraWeb.Admin.AdminDashboardLive do
  use AuroraWeb, :live_view

  alias Aurora.Administration

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_admin] do
      {:ok,
       assign(socket,
         page_title: "Admin Dashboard",
         stats: %{
           total_users: 0,
           total_creators: 0,
           total_content: 0,
           total_revenue: "$0.00"
         },
         selected_tab: "overview",
         admin_role: socket.assigns.current_admin.role
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
                  phx-value-tab="users"
                  class={"#{if @selected_tab == "users", do: "border-brand text-gray-900", else: "border-transparent text-gray-500"} inline-flex items-center border-b-2 px-1 pt-1 text-sm font-medium"}
                >
                  Users
                </button>
                <button
                  phx-click="select-tab"
                  phx-value-tab="creators"
                  class={"#{if @selected_tab == "creators", do: "border-brand text-gray-900", else: "border-transparent text-gray-500"} inline-flex items-center border-b-2 px-1 pt-1 text-sm font-medium"}
                >
                  Creators
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

            <% "users" -> %>
              <div class="bg-white shadow rounded-lg">
                <div class="p-6">
                  <h2 class="text-lg font-medium text-gray-900">User Management</h2>
                  <p class="mt-1 text-sm text-gray-500">Manage user accounts and permissions.</p>
                  <!-- Add user management UI here -->
                </div>
              </div>

            <% "creators" -> %>
              <div class="bg-white shadow rounded-lg">
                <div class="p-6">
                  <h2 class="text-lg font-medium text-gray-900">Creator Management</h2>
                  <p class="mt-1 text-sm text-gray-500">Manage creator accounts and content.</p>
                  <!-- Add creator management UI here -->
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
end
