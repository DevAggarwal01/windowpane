defmodule WindowpaneWeb.Router do
  use WindowpaneWeb, :router

  import WindowpaneWeb.AdminAuth

  import WindowpaneWeb.UserAuth
  import WindowpaneWeb.CreatorAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WindowpaneWeb.Layouts, :minimal}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :studio_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WindowpaneWeb.Layouts, :minimal}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_creator
  end

  pipeline :admin_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WindowpaneWeb.Layouts, :minimal}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_admin
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Consumer site (windowpane.tv)
  scope "/", WindowpaneWeb, host: "windowpane.tv" do
    pipe_through [:browser]

    live_session :home_page,
      layout: {WindowpaneWeb.Layouts, :browse},
      on_mount: [{WindowpaneWeb.UserAuth, :mount_current_user}] do
      live "/", LandingLive, :home
    end

    live_session :watch_page,
      layout: {WindowpaneWeb.Layouts, :browse},
      on_mount: [{WindowpaneWeb.UserAuth, :mount_current_user}] do
      live "/watch", WatchLive, :watch
    end
  end

  # User authentication routes (windowpane.tv)
  scope "/", WindowpaneWeb, host: "windowpane.tv" do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{WindowpaneWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", WindowpaneWeb, host: "windowpane.tv" do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      layout: {WindowpaneWeb.Layouts, :browse},
      on_mount: [{WindowpaneWeb.UserAuth, :ensure_authenticated}] do
      live "/library", LibraryLive, :index
      live "/shop", ShopLive, :index
      live "/social", SocialLive, :index
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", WindowpaneWeb, host: "windowpane.tv" do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
    get "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{WindowpaneWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  scope "/", WindowpaneWeb do
    pipe_through [:api]
    # TODO after getting a domain, need to change the webhook url in mux settings
    post "/mux/webhook", MuxWebhookController, :create
    post "/stripe/webhook", StripeWebhookController, :create
  end

  # Creator authentication routes (studio.windowpane.tv)
  scope "/", WindowpaneWeb, host: "studio.windowpane.tv" do
    pipe_through [:studio_browser, :redirect_if_creator_is_authenticated]

    live_session :redirect_if_creator_is_authenticated,
      on_mount: [{WindowpaneWeb.CreatorAuth, :redirect_if_creator_is_authenticated}] do
      live "/creators/register", CreatorRegistrationLive, :new
      live "/creators/log_in", CreatorLoginLive, :new
      live "/creators/reset_password", CreatorForgotPasswordLive, :new
      live "/creators/reset_password/:token", CreatorResetPasswordLive, :edit
    end

    post "/creators/log_in", CreatorSessionController, :create
    get "/", PageController, :home
  end

  scope "/", WindowpaneWeb, host: "studio.windowpane.tv" do
    pipe_through [:studio_browser, :require_authenticated_creator]

    live_session :require_authenticated_creator,
      on_mount: [{WindowpaneWeb.CreatorAuth, :ensure_authenticated}] do
      live "/dashboard", HomeLive, :show
      live "/projects", ProjectLive.Index, :index
      live "/projects/new", ProjectLive.New, :new
      live "/social", SocialLive, :index
      live "/:id", ProjectLive.Show, :show
      live "/creators/settings", CreatorSettingsLive, :edit
      live "/creators/settings/confirm_email/:token", CreatorSettingsLive, :confirm_email
    end
  end

  scope "/", WindowpaneWeb, host: "studio.windowpane.tv" do
    pipe_through [:studio_browser]

    delete "/creators/log_out", CreatorSessionController, :delete
    get "/creators/log_out", CreatorSessionController, :delete

    live_session :current_creator,
      on_mount: [{WindowpaneWeb.CreatorAuth, :mount_current_creator}] do
      live "/creators/confirm/:token", CreatorConfirmationLive, :edit
      live "/creators/confirm", CreatorConfirmationInstructionsLive, :new
    end
  end

  # API routes for studio.windowpane.tv
  scope "/api", WindowpaneWeb.Api, host: "studio.windowpane.tv" do
    pipe_through [:api]

    post "/projects/:id/cover", CoverController, :create
    post "/projects/:id/banner", BannerController, :create
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:windowpane, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WindowpaneWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # Admin site (admin.windowpane.tv)
  scope "/", WindowpaneWeb, host: "admin.windowpane.tv" do
    pipe_through [:admin_browser, :redirect_if_admin_is_authenticated]

    get "/log_in", AdminSessionController, :new
    post "/log_in", AdminSessionController, :create
    get "/reset_password", AdminResetPasswordController, :new
    post "/reset_password", AdminResetPasswordController, :create
    get "/reset_password/:token", AdminResetPasswordController, :edit
    put "/reset_password/:token", AdminResetPasswordController, :update
  end

  scope "/", WindowpaneWeb, host: "admin.windowpane.tv" do
    pipe_through [:admin_browser, :require_authenticated_admin]

    live_session :require_authenticated_admin,
      on_mount: [{WindowpaneWeb.AdminAuth, :require_authenticated_admin}] do
      live "/", Admin.AdminDashboardLive, :index
      live "/settings", Admin.AdminSettingsLive, :edit
      live "/settings/confirm_email/:token", Admin.AdminSettingsLive, :confirm_email
      live "/:id", Admin.ProjectDetailsLive, :show
    end

    get "/settings", AdminSettingsController, :edit
    put "/settings", AdminSettingsController, :update
    get "/settings/confirm_email/:token", AdminSettingsController, :confirm_email
  end

  scope "/", WindowpaneWeb, host: "admin.windowpane.tv" do
    pipe_through [:admin_browser]

    delete "/log_out", AdminSessionController, :delete
    get "/log_out", AdminSessionController, :delete
    get "/confirm", AdminConfirmationController, :new
    post "/confirm", AdminConfirmationController, :create
    get "/confirm/:token", AdminConfirmationController, :edit
    post "/confirm/:token", AdminConfirmationController, :update
  end
end
