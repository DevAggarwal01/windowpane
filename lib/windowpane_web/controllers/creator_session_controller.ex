defmodule WindowpaneWeb.CreatorSessionController do
  use WindowpaneWeb, :controller

  alias Windowpane.Creators
  alias WindowpaneWeb.CreatorAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:creator_return_to, ~p"/creators/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"creator" => creator_params}, info) do
    %{"email" => email, "password" => password} = creator_params

    if creator = Creators.get_creator_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> CreatorAuth.log_in_creator(creator, creator_params)
    else
      # In order to prevent creator enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/creators/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> CreatorAuth.log_out_creator()
  end
end
