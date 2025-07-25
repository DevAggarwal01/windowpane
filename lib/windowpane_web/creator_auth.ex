defmodule WindowpaneWeb.CreatorAuth do
  use WindowpaneWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Windowpane.Creators

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in CreatorToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_windowpane_web_creator_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the creator in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_creator(conn, creator, params \\ %{}) do
    token = Creators.generate_creator_session_token(creator)
    creator_return_to = get_session(conn, :creator_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: creator_return_to || signed_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the creator out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_creator(conn) do
    creator_token = get_session(conn, :creator_token)
    creator_token && Creators.delete_creator_session_token(creator_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      WindowpaneWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the creator by looking into the session
  and remember me token.
  """
  def fetch_current_creator(conn, _opts) do
    {creator_token, conn} = ensure_creator_token(conn)
    creator = creator_token && Creators.get_creator_by_session_token(creator_token)
    assign(conn, :current_creator, creator)
  end

  defp ensure_creator_token(conn) do
    if token = get_session(conn, :creator_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Handles mounting and authenticating the current_creator in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_creator` - Assigns current_creator
      to socket assigns based on creator_token, or nil if
      there's no creator_token or no matching creator.

    * `:ensure_authenticated` - Authenticates the creator from the session,
      and assigns the current_creator to socket assigns based
      on creator_token.
      Redirects to login page if there's no logged creator.

    * `:redirect_if_creator_is_authenticated` - Authenticates the creator from the session.
      Redirects to signed_in_path if there's a logged creator.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_creator:

      defmodule WindowpaneWeb.PageLive do
        use WindowpaneWeb, :live_view

        on_mount {WindowpaneWeb.CreatorAuth, :mount_current_creator}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{WindowpaneWeb.CreatorAuth, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_creator, _params, session, socket) do
    {:cont, mount_current_creator(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_creator(socket, session)

    if socket.assigns.current_creator do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/creators/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_creator_is_authenticated, _params, session, socket) do
    socket = mount_current_creator(socket, session)

    if socket.assigns.current_creator do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_creator(socket, session) do
    Phoenix.Component.assign_new(socket, :current_creator, fn ->
      if creator_token = session["creator_token"] do
        Creators.get_creator_by_session_token(creator_token)
      end
    end)
  end

  @doc """
  Used for routes that require the creator to not be authenticated.
  """
  def redirect_if_creator_is_authenticated(conn, _opts) do
    if conn.assigns[:current_creator] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the creator to be authenticated.

  If you want to enforce the creator email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_creator(conn, _opts) do
    if conn.assigns[:current_creator] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/creators/log_in")
      |> halt()
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:creator_token, token)
    |> put_session(:live_socket_id, "creators_sessions:#{Base.url_encode64(token)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :creator_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/dashboard"
end
