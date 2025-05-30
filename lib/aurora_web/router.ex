defmodule AuroraWeb.Router do
  use AuroraWeb, :router

  import AuroraWeb.UserAuth
  import AuroraWeb.CreatorAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AuroraWeb.Layouts, :minimal}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :studio_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AuroraWeb.Layouts, :minimal}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_creator
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Consumer site (aurora.com)
  scope "/", AuroraWeb, host: "aurora.com" do
    pipe_through :browser

    get "/", PageController, :home
  end

  # User authentication routes (aurora.com)
  scope "/", AuroraWeb, host: "aurora.com" do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{AuroraWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", AuroraWeb, host: "aurora.com" do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{AuroraWeb.UserAuth, :ensure_authenticated}] do
      live "/dashboard", HomeLive, :show
      live "/browse", BrowseLive, :index
      live "/library", LibraryLive, :index
      live "/social", SocialLive, :index
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", AuroraWeb, host: "aurora.com" do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
    get "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{AuroraWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  # Creators site (studio.aurora.com)
  scope "/", AuroraWeb, host: "studio.aurora.com" do
    pipe_through :studio_browser

    get "/", PageController, :home
  end

  # Creator authentication routes (studio.aurora.com)
  scope "/", AuroraWeb, host: "studio.aurora.com" do
    pipe_through [:studio_browser, :redirect_if_creator_is_authenticated]

    live_session :redirect_if_creator_is_authenticated,
      on_mount: [{AuroraWeb.CreatorAuth, :redirect_if_creator_is_authenticated}] do
      live "/creators/register", CreatorRegistrationLive, :new
      live "/creators/log_in", CreatorLoginLive, :new
      live "/creators/reset_password", CreatorForgotPasswordLive, :new
      live "/creators/reset_password/:token", CreatorResetPasswordLive, :edit
    end

    post "/creators/log_in", CreatorSessionController, :create
  end

  scope "/", AuroraWeb, host: "studio.aurora.com" do
    pipe_through [:studio_browser, :require_authenticated_creator]

    live_session :require_authenticated_creator,
      on_mount: [{AuroraWeb.CreatorAuth, :ensure_authenticated}] do
      live "/dashboard", HomeLive, :show
      live "/projects", ProjectLive.Index, :index
      live "/projects/new", ProjectLive.New, :new
      live "/projects/:id", ProjectLive.Show, :show
      live "/creators/settings", CreatorSettingsLive, :edit
      live "/creators/settings/confirm_email/:token", CreatorSettingsLive, :confirm_email
    end
  end

  scope "/", AuroraWeb, host: "studio.aurora.com" do
    pipe_through [:studio_browser]

    delete "/creators/log_out", CreatorSessionController, :delete
    get "/creators/log_out", CreatorSessionController, :delete

    live_session :current_creator,
      on_mount: [{AuroraWeb.CreatorAuth, :mount_current_creator}] do
      live "/creators/confirm/:token", CreatorConfirmationLive, :edit
      live "/creators/confirm", CreatorConfirmationInstructionsLive, :new
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:aurora, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AuroraWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
