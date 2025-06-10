defmodule WindowpaneWeb.AdminConfirmationControllerTest do
  use WindowpaneWeb.ConnCase, async: true

  alias Windowpane.Administration
  alias Windowpane.Repo
  import Windowpane.AdministrationFixtures

  setup do
    %{admin: admin_fixture()}
  end

  describe "GET /admins/confirm" do
    test "renders the resend confirmation page", %{conn: conn} do
      conn = get(conn, ~p"/admins/confirm")
      response = html_response(conn, 200)
      assert response =~ "Resend confirmation instructions"
    end
  end

  describe "POST /admins/confirm" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, admin: admin} do
      conn =
        post(conn, ~p"/admins/confirm", %{
          "admin" => %{"email" => admin.email}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Administration.AdminToken, admin_id: admin.id).context == "confirm"
    end

    test "does not send confirmation token if Admin is confirmed", %{conn: conn, admin: admin} do
      Repo.update!(Administration.Admin.confirm_changeset(admin))

      conn =
        post(conn, ~p"/admins/confirm", %{
          "admin" => %{"email" => admin.email}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      refute Repo.get_by(Administration.AdminToken, admin_id: admin.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/admins/confirm", %{
          "admin" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Administration.AdminToken) == []
    end
  end

  describe "GET /admins/confirm/:token" do
    test "renders the confirmation page", %{conn: conn} do
      token_path = ~p"/admins/confirm/some-token"
      conn = get(conn, token_path)
      response = html_response(conn, 200)
      assert response =~ "Confirm account"

      assert response =~ "action=\"#{token_path}\""
    end
  end

  describe "POST /admins/confirm/:token" do
    test "confirms the given token once", %{conn: conn, admin: admin} do
      token =
        extract_admin_token(fn url ->
          Administration.deliver_admin_confirmation_instructions(admin, url)
        end)

      conn = post(conn, ~p"/admins/confirm/#{token}")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Admin confirmed successfully"

      assert Administration.get_admin!(admin.id).confirmed_at
      refute get_session(conn, :admin_token)
      assert Repo.all(Administration.AdminToken) == []

      # When not logged in
      conn = post(conn, ~p"/admins/confirm/#{token}")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Admin confirmation link is invalid or it has expired"

      # When logged in
      conn =
        build_conn()
        |> log_in_admin(admin)
        |> post(~p"/admins/confirm/#{token}")

      assert redirected_to(conn) == ~p"/"
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, admin: admin} do
      conn = post(conn, ~p"/admins/confirm/oops")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Admin confirmation link is invalid or it has expired"

      refute Administration.get_admin!(admin.id).confirmed_at
    end
  end
end
