defmodule WindowpaneWeb.Admin.AdminDashboardLive do
  use WindowpaneWeb, :live_view

  alias Windowpane.Administration
  alias Windowpane.Accounts
  alias Windowpane.Creators
  alias Windowpane.Accounts.User, as: User
  alias Windowpane.Accounts.{Creator}

  @accounts_per_page 10

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_admin] do
      accounts_data = Administration.list_accounts("users")
      IO.puts("Current admin role: #{socket.assigns.current_admin.role}")
      admins = if socket.assigns.current_admin.role == "superadmin", do: Administration.list_admins(), else: []

      {:ok,
       assign(socket,
         page_title: "Admin Dashboard",
         stats: %{
           total_users: accounts_data.total_count,
           total_creators: Administration.list_accounts("creators").total_count,
           total_content: 0,
           total_revenue: "$0.00"
         },
         selected_tab: "overview",
         admin_role: socket.assigns.current_admin.role,
         account_filter: "users",
         search_query: "",
         filtered_accounts: accounts_data.accounts,
         current_page: accounts_data.page,
         total_pages: accounts_data.total_pages,
         total_accounts: accounts_data.total_count,
         admins: admins,
         show_account_modal: false,
         selected_account: nil,
         show_registration_modal: false,
         registration_type: nil,
         registration_form: %{
           "email" => "",
           "password" => "",
           "creator_code" => "",
           "name" => "",
           "role" => ""
         },
         show_delete_confirmation_modal: false,
         account_to_delete: nil
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
                <img class="h-8 w-auto" src={~p"/images/logo.png"} alt="Windowpane Admin" />
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
                        <div class="flex">
                          <div class="relative rounded-md shadow-sm">
                            <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                              <svg class="h-5 w-5 text-gray-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                                <path fill-rule="evenodd" d="M9 3.5a5.5 5.5 0 100 11 5.5 5.5 0 000-11zM2 9a7 7 0 1112.452 4.391l3.328 3.329a.75.75 0 11-1.06 1.06l-3.329-3.328A7 7 0 012 9z" clip-rule="evenodd" />
                              </svg>
                            </div>
                            <form phx-submit="perform-search" class="flex" onsubmit="return false;">
                              <input
                                type="text"
                                name="search"
                                placeholder="Search by email..."
                                value={@search_query}
                                phx-change="update-search-query"
                                class="block w-full rounded-l-md border-0 py-1.5 pl-10 text-gray-900 ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-brand sm:text-sm sm:leading-6"
                              />
                              <button
                                type="submit"
                                phx-click="perform-search"
                                phx-value-search={@search_query}
                                class="relative -ml-px inline-flex items-center gap-x-1.5 rounded-r-md px-3 py-2 text-sm font-semibold text-white bg-brand hover:bg-accent"
                              >
                                <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                                  <path fill-rule="evenodd" d="M9 3.5a5.5 5.5 0 100 11 5.5 5.5 0 000-11zM2 9a7 7 0 1112.452 4.391l3.328 3.329a.75.75 0 11-1.06 1.06l-3.329-3.328A7 7 0 012 9z" clip-rule="evenodd" />
                                </svg>
                                <span class="sr-only">Search</span>
                              </button>
                            </form>
                          </div>
                          <button
                            :if={@search_query != ""}
                            phx-click="clear-search"
                            class="ml-2 inline-flex items-center rounded-md bg-white px-2.5 py-1.5 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
                          >
                            Clear
                          </button>
                        </div>
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
                        <%= if @account_filter in ["users", "creators"] do %>
                          <button
                            type="button"
                            phx-click={"new-#{@account_filter |> String.slice(0..-2)}"}
                            class="rounded-md bg-brand px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-accent focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
                          >
                            Add <%= @account_filter |> String.slice(0..-2) |> String.capitalize() %>
                          </button>
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
                                      <div class="flex justify-end space-x-3">
                                        <.link
                                          href="#"
                                          class="text-brand hover:text-accent"
                                          phx-click="edit-admin"
                                          phx-value-id={admin.id}
                                        >
                                          Edit<span class="sr-only">, <%= admin.email %></span>
                                        </.link>
                                        <%= if @admin_role == "superadmin" and admin.email != @current_admin.email do %>
                                          <button
                                            type="button"
                                            phx-click="confirm-delete-account"
                                            phx-value-uid={admin.id}
                                            phx-value-account-type="admin"
                                            class="text-red-600 hover:text-red-900"
                                          >
                                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                                              <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m6.5 0a48.667 48.667 0 00-7.5 0" />
                                            </svg>
                                            <span class="sr-only">Delete <%= admin.email %></span>
                                          </button>
                                        <% end %>
                                      </div>
                                    </td>
                                  </tr>
                                <% end %>
                              <% _ -> %>
                                <%= for account <- @filtered_accounts do %>
                                  <tr>
                                    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-0"><%= account.email %></td>
                                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                                      <span class={"inline-flex items-center rounded-md px-2 py-1 text-xs font-medium #{account_type_class(account)}"}>
                                        <%= account_type_label(account) %>
                                      </span>
                                    </td>
                                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                                      <span class={"inline-flex items-center rounded-md px-2 py-1 text-xs font-medium #{if account.confirmed_at, do: "bg-green-50 text-green-700", else: "bg-yellow-50 text-yellow-700"}"}>
                                        <%= if account.confirmed_at, do: "Active", else: "Pending" %>
                                      </span>
                                    </td>
                                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= Calendar.strftime(account.inserted_at, "%Y-%m-%d") %></td>
                                    <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-0">
                                      <div class="flex justify-end space-x-3">
                                        <button
                                          phx-click="view-account"
                                          phx-value-uid={account.uid}
                                          class="text-brand hover:text-accent"
                                        >
                                          View<span class="sr-only">, <%= account.email %></span>
                                        </button>
                                        <button
                                          type="button"
                                          phx-click="confirm-delete-account"
                                          phx-value-uid={account.uid}
                                          class="text-red-600 hover:text-red-900"
                                        >
                                          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m6.5 0a48.667 48.667 0 00-7.5 0" />
                                          </svg>
                                          <span class="sr-only">Delete <%= account.email %></span>
                                        </button>
                                      </div>
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

              <%= if @account_filter != "admins" do %>
                <div class="flex items-center justify-between border-t border-gray-200 bg-white px-4 py-3 sm:px-6">
                  <div class="flex flex-1 justify-between sm:hidden">
                    <button
                      phx-click="previous-page"
                      disabled={@current_page == 1}
                      class={"relative inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium #{if @current_page == 1, do: "text-gray-300 cursor-not-allowed", else: "text-gray-700 hover:bg-gray-50"}"}
                    >
                      Previous
                    </button>
                    <button
                      phx-click="next-page"
                      disabled={@current_page == @total_pages}
                      class={"relative ml-3 inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium #{if @current_page == @total_pages, do: "text-gray-300 cursor-not-allowed", else: "text-gray-700 hover:bg-gray-50"}"}
                    >
                      Next
                    </button>
                  </div>
                  <div class="hidden sm:flex sm:flex-1 sm:items-center sm:justify-between">
                    <div>
                      <p class="text-sm text-gray-700">
                        Showing page <span class="font-medium"><%= @current_page %></span> of
                        <span class="font-medium"><%= @total_pages %></span>
                      </p>
                    </div>
                    <div>
                      <nav class="isolate inline-flex -space-x-px rounded-md shadow-sm" aria-label="Pagination">
                        <button
                          phx-click="previous-page"
                          disabled={@current_page == 1}
                          class={"relative inline-flex items-center rounded-l-md px-2 py-2 #{if @current_page == 1, do: "text-gray-300 cursor-not-allowed", else: "text-gray-700 hover:bg-gray-50"} ring-1 ring-inset ring-gray-300 focus:z-20 focus:outline-offset-0"}
                        >
                          <span class="sr-only">Previous</span>
                          <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                            <path fill-rule="evenodd" d="M12.79 5.23a.75.75 0 01-.02 1.06L8.832 10l3.938 3.71a.75.75 0 11-1.04 1.08l-4.5-4.25a.75.75 0 010-1.08l4.5-4.25a.75.75 0 011.06.02z" clip-rule="evenodd" />
                          </svg>
                        </button>
                        <button
                          phx-click="next-page"
                          disabled={@current_page == @total_pages}
                          class={"relative inline-flex items-center rounded-r-md px-2 py-2 #{if @current_page == @total_pages, do: "text-gray-300 cursor-not-allowed", else: "text-gray-700 hover:bg-gray-50"} ring-1 ring-inset ring-gray-300 focus:z-20 focus:outline-offset-0"}
                        >
                          <span class="sr-only">Next</span>
                          <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                            <path fill-rule="evenodd" d="M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z" clip-rule="evenodd" />
                          </svg>
                        </button>
                      </nav>
                    </div>
                  </div>
                </div>
              <% end %>

              <.modal
                :if={@show_account_modal}
                id="account-modal"
                show
                on_cancel={JS.push("close_modal")}
              >
                <:title>Account Details</:title>

                <%= if @selected_account do %>
                  <div class="mt-6 border-t border-gray-100">
                    <dl class="divide-y divide-gray-100">
                      <div class="px-4 py-3 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-0">
                        <dt class="text-sm font-medium leading-6 text-gray-900">Email</dt>
                        <dd class="mt-1 text-sm leading-6 text-gray-700 sm:col-span-2 sm:mt-0">
                          <%= @selected_account.email %>
                        </dd>
                      </div>
                      <div class="px-4 py-3 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-0">
                        <dt class="text-sm font-medium leading-6 text-gray-900">Name</dt>
                        <dd class="mt-1 text-sm leading-6 text-gray-700 sm:col-span-2 sm:mt-0">
                          <%= @selected_account.name || "Not set" %>
                        </dd>
                      </div>
                      <div class="px-4 py-3 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-0">
                        <dt class="text-sm font-medium leading-6 text-gray-900">Plan</dt>
                        <dd class="mt-1 text-sm leading-6 text-gray-700 sm:col-span-2 sm:mt-0">
                          <%= String.capitalize(@selected_account.plan || "Free") %>
                        </dd>
                      </div>
                      <div class="px-4 py-3 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-0">
                        <dt class="text-sm font-medium leading-6 text-gray-900">Account Type</dt>
                        <dd class="mt-1 text-sm leading-6 text-gray-700 sm:col-span-2 sm:mt-0">
                          <%= String.capitalize(@selected_account.type || "") %>
                        </dd>
                      </div>
                      <div class="px-4 py-3 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-0">
                        <dt class="text-sm font-medium leading-6 text-gray-900">Status</dt>
                        <dd class="mt-1 text-sm leading-6 text-gray-700 sm:col-span-2 sm:mt-0">
                          <%= if @selected_account.confirmed_at, do: "Active", else: "Pending" %>
                        </dd>
                      </div>
                      <%= if @selected_account.type == "creator" do %>
                        <div class="px-4 py-3 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-0">
                          <dt class="text-sm font-medium leading-6 text-gray-900">Stripe Status</dt>
                          <dd class="mt-1 text-sm leading-6 text-gray-700 sm:col-span-2 sm:mt-0">
                            <%= if @selected_account.onboarded, do: "Onboarded", else: "Not Onboarded" %>
                          </dd>
                        </div>
                      <% end %>
                      <div class="px-4 py-3 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-0">
                        <dt class="text-sm font-medium leading-6 text-gray-900">Joined</dt>
                        <dd class="mt-1 text-sm leading-6 text-gray-700 sm:col-span-2 sm:mt-0">
                          <%= Calendar.strftime(@selected_account.inserted_at, "%B %d, %Y") %>
                        </dd>
                      </div>
                    </dl>
                  </div>
                <% end %>
              </.modal>

              <.modal
                :if={@show_registration_modal}
                id="registration-modal"
                show
                on_cancel={JS.push("close_registration_modal")}
              >
                <:title>
                  <%= case @registration_type do %>
                    <% "creator" -> %>
                      Add New Creator
                    <% "user" -> %>
                      Add New User
                    <% "admin" -> %>
                      Add New Admin
                  <% end %>
                </:title>

                <.form
                  for={%{}}
                  phx-submit="submit_registration"
                  class="space-y-4"
                >
                  <div>
                    <.label for="name">Name</.label>
                    <.input
                      type="text"
                      name="name"
                      id="name"
                      value={@registration_form["name"]}
                      required
                      phx-change="update_registration_form"
                    />
                  </div>

                  <div>
                    <.label for="email">Email</.label>
                    <.input
                      type="email"
                      name="email"
                      id="email"
                      value={@registration_form["email"]}
                      required
                      phx-change="update_registration_form"
                    />
                  </div>

                  <div>
                    <.label for="password">Password</.label>
                    <.input
                      type="password"
                      name="password"
                      id="password"
                      value={@registration_form["password"]}
                      required
                      phx-change="update_registration_form"
                    />
                  </div>

                  <%= if @registration_type == "creator" do %>
                    <div>
                      <.label for="creator_code">Creator Code</.label>
                      <.input
                        type="text"
                        name="creator_code"
                        id="creator_code"
                        value={@registration_form["creator_code"]}
                        required
                        phx-change="update_registration_form"
                      />
                    </div>
                  <% end %>

                  <%= if @registration_type == "admin" do %>
                    <div>
                      <.label for="role">Role</.label>
                      <select
                        name="role"
                        id="role"
                        value={@registration_form["role"]}
                        required
                        phx-change="update_registration_form"
                        class="mt-2 block w-full rounded-md border-0 py-1.5 pl-3 pr-10 text-gray-900 ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-brand sm:text-sm sm:leading-6"
                      >
                        <option value="">Select a role</option>
                        <option value="admin">Admin</option>
                        <option value="superadmin">Superadmin</option>
                      </select>
                    </div>
                  <% end %>

                  <div class="flex justify-end space-x-3 mt-6">
                    <.button
                      type="button"
                      phx-click="close_registration_modal"
                      class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50"
                    >
                      Cancel
                    </.button>
                    <.button
                      type="submit"
                      class="px-4 py-2 text-sm font-medium text-white bg-brand rounded-md shadow-sm hover:bg-accent"
                    >
                      Create Account
                    </.button>
                  </div>
                </.form>
              </.modal>

              <.modal
                :if={@show_delete_confirmation_modal}
                id="delete-confirmation-modal"
                show
                on_cancel={JS.push("cancel-delete")}
              >
                <:title>Confirm Account Deletion</:title>

                <div class="mt-6">
                  <p class="text-sm text-gray-500">
                    Are you sure you want to delete this account? This action cannot be undone.
                  </p>

                  <%= if @account_to_delete do %>
                    <div class="mt-4 bg-gray-50 p-4 rounded-md">
                      <dl class="divide-y divide-gray-200">
                        <div class="py-2">
                          <dt class="text-sm font-medium text-gray-500">Email</dt>
                          <dd class="mt-1 text-sm text-gray-900"><%= @account_to_delete.email %></dd>
                        </div>
                        <div class="py-2">
                          <dt class="text-sm font-medium text-gray-500">Account Type</dt>
                          <dd class="mt-1 text-sm text-gray-900"><%= String.capitalize(@account_to_delete.type) %></dd>
                        </div>
                      </dl>
                    </div>
                  <% end %>

                  <div class="mt-6 flex justify-end space-x-3">
                    <.button
                      type="button"
                      phx-click="cancel-delete"
                      class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50"
                    >
                      Cancel
                    </.button>
                    <.button
                      type="button"
                      phx-click="proceed-with-delete"
                      class="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-md shadow-sm hover:bg-red-700"
                    >
                      Delete Account
                    </.button>
                  </div>
                </div>
              </.modal>

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
    accounts_data = Administration.list_accounts(filter_type)

    {:noreply,
     socket
     |> assign(
       account_filter: filter_type,
       filtered_accounts: accounts_data.accounts,
       current_page: 1,
       total_pages: accounts_data.total_pages,
       total_accounts: accounts_data.total_count
     )}
  end

  @impl true
  def handle_event("view-account", %{"uid" => uid}, socket) do
    account = Enum.find(socket.assigns.filtered_accounts, fn account ->
      account.uid == uid
    end)

    {:noreply, assign(socket, show_account_modal: true, selected_account: account)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_account_modal: false)}
  end

  @impl true
  def handle_event("new-admin", _params, socket) do
    {:noreply, assign(socket,
      show_registration_modal: true,
      registration_type: "admin",
      registration_form: %{
        "email" => "",
        "password" => "",
        "creator_code" => "",
        "name" => "",
        "role" => ""
      }
    )}
  end

  @impl true
  def handle_event("new-user", _params, socket) do
    {:noreply, assign(socket,
      show_registration_modal: true,
      registration_type: "user",
      registration_form: %{
        "email" => "",
        "password" => "",
        "creator_code" => "",
        "name" => "",
        "role" => ""
      }
    )}
  end

  @impl true
  def handle_event("new-creator", _params, socket) do
    {:noreply, assign(socket,
      show_registration_modal: true,
      registration_type: "creator",
      registration_form: %{
        "email" => "",
        "password" => "",
        "creator_code" => "",
        "name" => "",
        "role" => ""
      }
    )}
  end

  @impl true
  def handle_event("edit-admin", %{"id" => admin_id}, socket) do
    # TODO: Implement admin editing
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_registration_modal", _params, socket) do
    {:noreply, assign(socket,
      show_registration_modal: false,
      registration_type: nil,
      registration_form: %{
        "email" => "",
        "password" => "",
        "creator_code" => "",
        "name" => "",
        "role" => ""
      }
    )}
  end

  @impl true
  def handle_event("update_registration_form", params = %{"_target" => [field]}, socket) do
    {:noreply, assign(socket,
      registration_form: Map.put(socket.assigns.registration_form, field, params[field])
    )}
  end

  @impl true
  def handle_event("submit_registration", params, socket) do
    IO.inspect(params, label: "Registration params")
    registration_params = %{
      "email" => socket.assigns.registration_form["email"],
      "password" => socket.assigns.registration_form["password"],
      "name" => socket.assigns.registration_form["name"],
      "creator_code" => socket.assigns.registration_form["creator_code"]
    }
    IO.inspect(registration_params, label: "Processed registration params")

    case socket.assigns.registration_type do
      "creator" ->
        case Creators.register_creator(registration_params) do
          {:ok, creator} ->
            IO.puts("Creator registered successfully")
            accounts_data = Administration.list_accounts(socket.assigns.account_filter)
            {:noreply,
             socket
             |> put_flash(:info, "Creator account created successfully")
             |> assign(
               show_registration_modal: false,
               filtered_accounts: accounts_data.accounts,
               total_pages: accounts_data.total_pages,
               total_accounts: accounts_data.total_count,
               registration_form: %{
                 "email" => "",
                 "password" => "",
                 "creator_code" => "",
                 "name" => "",
                 "role" => ""
               }
             )}

          {:error, changeset} ->
            IO.inspect(changeset, label: "Creator registration error")
            {:noreply,
             socket
             |> put_flash(:error, "Error creating creator account: #{error_to_string(changeset)}")}
        end

      "user" ->
        # Create regular user
        params = Map.put(params, "type", "user")
        case Accounts.register_user(params) do
          {:ok, user} ->
            accounts_data = Administration.list_accounts(socket.assigns.account_filter)
            {:noreply,
             socket
             |> put_flash(:info, "User account created successfully")
             |> assign(
               show_registration_modal: false,
               filtered_accounts: accounts_data.accounts,
               total_pages: accounts_data.total_pages,
               total_accounts: accounts_data.total_count,
               registration_form: %{
                 "email" => "",
                 "password" => "",
                 "creator_code" => "",
                 "name" => "",
                 "role" => ""
               }
             )}

          {:error, changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Error creating user account: #{error_to_string(changeset)}")}
        end

      "admin" ->
        # Create admin user
        case Administration.register_admin(params) do
          {:ok, admin} ->
            {:noreply,
             socket
             |> put_flash(:info, "Admin account created successfully")
             |> assign(
               show_registration_modal: false,
               admins: Administration.list_admins(),
               registration_form: %{
                 "email" => "",
                 "password" => "",
                 "creator_code" => "",
                 "name" => "",
                 "role" => ""
               }
             )}

          {:error, changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Error creating admin account: #{error_to_string(changeset)}")}
        end
    end
  end

  @impl true
  def handle_event("confirm-delete-account", params, socket) do
    account = case params do
      %{"uid" => uid, "account-type" => "admin"} ->
        admin = Enum.find(socket.assigns.admins, &(to_string(&1.id) == uid))
        if admin, do: Map.put(admin, :type, "admin"), else: nil
      %{"uid" => uid} ->
        Enum.find(socket.assigns.filtered_accounts, &(&1.uid == uid))
    end

    {:noreply, assign(socket, show_delete_confirmation_modal: true, account_to_delete: account)}
  end

  @impl true
  def handle_event("cancel-delete", _params, socket) do
    {:noreply, assign(socket, show_delete_confirmation_modal: false, account_to_delete: nil)}
  end

  @impl true
  def handle_event("proceed-with-delete", _params, socket) do
    account = socket.assigns.account_to_delete

    result = case account do
      %{type: "creator"} -> handle_creator_deletion(account, socket)
      %{type: "user"} -> handle_user_deletion(account, socket)
      %{type: "admin"} -> handle_admin_deletion(account, socket)
      _ -> {:error, socket |> put_flash(:error, "Invalid account type")}
    end

    case result do
      {:ok, socket} ->
        {:noreply, assign(socket, show_delete_confirmation_modal: false, account_to_delete: nil)}
      {:error, socket} ->
        {:noreply, assign(socket, show_delete_confirmation_modal: false, account_to_delete: nil)}
    end
  end

  defp handle_creator_deletion(account, socket) do
    case Creators.delete_creator(account) do
      {:ok, _} ->
        accounts_data = Administration.list_accounts(socket.assigns.account_filter)
        new_page = if accounts_data.total_pages < socket.assigns.current_page and socket.assigns.current_page > 1 do
          socket.assigns.current_page - 1
        else
          socket.assigns.current_page
        end
        updated_data = Administration.list_accounts(socket.assigns.account_filter, new_page)

        {:ok,
         socket
         |> put_flash(:info, "Creator account deleted successfully")
         |> assign(
           filtered_accounts: updated_data.accounts,
           total_pages: updated_data.total_pages,
           total_accounts: updated_data.total_count,
           current_page: new_page
         )}

      {:error, :not_found} ->
        {:error,
         socket
         |> put_flash(:error, "Creator account not found")}

      {:error, _} ->
        {:error,
         socket
         |> put_flash(:error, "Failed to delete creator account")}
    end
  end

  defp handle_user_deletion(account, socket) do
    case Accounts.delete_user(account) do
      {:ok, _} ->
        accounts_data = Administration.list_accounts(socket.assigns.account_filter)
        new_page = if accounts_data.total_pages < socket.assigns.current_page and socket.assigns.current_page > 1 do
          socket.assigns.current_page - 1
        else
          socket.assigns.current_page
        end
        updated_data = Administration.list_accounts(socket.assigns.account_filter, new_page)

        {:ok,
         socket
         |> put_flash(:info, "User account deleted successfully")
         |> assign(
           filtered_accounts: updated_data.accounts,
           total_pages: updated_data.total_pages,
           total_accounts: updated_data.total_count,
           current_page: new_page
         )}

      {:error, :not_found} ->
        {:error,
         socket
         |> put_flash(:error, "User account not found")}

      {:error, _} ->
        {:error,
         socket
         |> put_flash(:error, "Failed to delete user account")}
    end
  end

  defp handle_admin_deletion(account, socket) do
    case Administration.delete_admin(account) do
      {:ok, _} ->
        {:ok,
         socket
         |> put_flash(:info, "Admin account deleted successfully")
         |> assign(admins: Administration.list_admins())}

      {:error, :last_superadmin} ->
        {:error,
         socket
         |> put_flash(:error, "Cannot delete the last superadmin account")}

      {:error, :not_found} ->
        {:error,
         socket
         |> put_flash(:error, "Admin account not found")}

      {:error, _} ->
        {:error,
         socket
         |> put_flash(:error, "Failed to delete admin account")}
    end
  end

  @impl true
  def handle_event("next-page", _params, socket) do
    if socket.assigns.current_page < socket.assigns.total_pages do
      next_page = socket.assigns.current_page + 1
      accounts_data =
        if socket.assigns.search_query == "" do
          Administration.list_accounts(socket.assigns.account_filter, next_page)
        else
          Administration.search_accounts(socket.assigns.account_filter, socket.assigns.search_query, next_page)
        end

      {:noreply,
       socket
       |> assign(
         current_page: next_page,
         filtered_accounts: accounts_data.accounts,
         total_pages: accounts_data.total_pages,
         total_accounts: accounts_data.total_count
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("previous-page", _params, socket) do
    if socket.assigns.current_page > 1 do
      prev_page = socket.assigns.current_page - 1
      accounts_data =
        if socket.assigns.search_query == "" do
          Administration.list_accounts(socket.assigns.account_filter, prev_page)
        else
          Administration.search_accounts(socket.assigns.account_filter, socket.assigns.search_query, prev_page)
        end

      {:noreply,
       socket
       |> assign(
         current_page: prev_page,
         filtered_accounts: accounts_data.accounts,
         total_pages: accounts_data.total_pages,
         total_accounts: accounts_data.total_count
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update-search-query", %{"search" => query}, socket) do
    IO.puts("Updating search query to: #{query}")
    {:noreply, assign(socket, search_query: query)}
  end

  @impl true
  def handle_event("perform-search", params, socket) do
    IO.puts("\n=== Search Debug ===")
    IO.puts("Params received: #{inspect(params)}")
    IO.puts("Current filter: #{socket.assigns.account_filter}")
    IO.puts("Current search query: #{socket.assigns.search_query}")
    IO.puts("Current tab: #{socket.assigns.selected_tab}")

    search_term = params["search"] || params["value"] || socket.assigns.search_query
    IO.puts("\nUsing search term: #{search_term}")

    accounts_data = Administration.search_accounts(socket.assigns.account_filter, search_term)

    {:noreply,
     socket
     |> assign(
       search_query: search_term,
       filtered_accounts: accounts_data.accounts,
       current_page: 1,
       total_pages: accounts_data.total_pages,
       total_accounts: accounts_data.total_count
     )}
  end

  @impl true
  def handle_event("clear-search", _params, socket) do
    accounts_data = Administration.list_accounts(socket.assigns.account_filter)

    {:noreply,
     socket
     |> assign(
       search_query: "",
       filtered_accounts: accounts_data.accounts,
       current_page: 1,
       total_pages: accounts_data.total_pages,
       total_accounts: accounts_data.total_count
     )}
  end

  defp error_to_string(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k} #{v}" end)
    |> Enum.join(", ")
  end

  # Helper function to paginate accounts
  defp paginate(accounts, page) do
    accounts
    |> Enum.drop((page - 1) * @accounts_per_page)
    |> Enum.take(@accounts_per_page)
  end

  defp filter_accounts_by_search(accounts, query) when is_binary(query) and query != "" do
    query = String.downcase(query)
    Enum.filter(accounts, fn account ->
      String.contains?(String.downcase(account.email), query)
    end)
  end
  defp filter_accounts_by_search(accounts, _query), do: accounts

  defp account_type_class(account) do
    cond do
      match?(%Windowpane.Accounts.User{}, account) -> "bg-gray-50 text-gray-700"
      match?(%Windowpane.Creators.Creator{}, account) -> "bg-indigo-50 text-indigo-700"
      match?(%Windowpane.Administration.Admin{}, account) -> "bg-purple-50 text-purple-700"
      true -> "bg-gray-50 text-gray-700"
    end
  end

  defp account_type_label(account) do
    cond do
      match?(%Windowpane.Accounts.User{}, account) -> "User"
      match?(%Windowpane.Creators.Creator{}, account) -> "Creator"
      match?(%Windowpane.Administration.Admin{}, account) -> "Admin"
      true -> "Unknown"
    end
  end
end
