defmodule WindowpaneWeb.UserSessionController do
  use WindowpaneWeb, :controller

  alias Windowpane.Accounts
  alias WindowpaneWeb.UserAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, %{"redirect_to" => redirect_to} = params) do
    conn
    |> put_session(:user_return_to, redirect_to)
    |> create(params, "Welcome back!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      referer = get_req_header(conn, "referer") |> List.first()
      redirect_path =
        case referer && URI.parse(referer) do
          %URI{host: _, path: path, query: query} when is_binary(path) ->
            if query, do: path <> "?" <> query, else: path
          _ -> UserAuth.signed_in_path(conn)
        end
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params, redirect_path)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
