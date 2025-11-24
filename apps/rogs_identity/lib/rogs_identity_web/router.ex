defmodule RogsIdentityWeb.Router do
  use RogsIdentityWeb, :router

  import RogsIdentityWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RogsIdentityWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug RogsIdentityWeb.UserAuth, action: :fetch_current_scope_for_api
    plug RogsIdentityWeb.Plug.SecurityHeaders
    # Note: CSRF protection is not needed for API endpoints using token-based auth
    # The session-based authentication already provides protection
  end

  pipeline :api_authenticated do
    plug RogsIdentityWeb.UserAuth, action: :require_authenticated_api
  end

  pipeline :rate_limit_login do
    plug RogsIdentityWeb.Plug.RateLimit,
      max_attempts: 5,
      window_seconds: 300,
      key_type: :login,
      error_message: "Login attempts are cooling down. Hold for a moment and retry."
  end

  pipeline :rate_limit_password_reset do
    plug RogsIdentityWeb.Plug.RateLimit,
      max_attempts: 3,
      window_seconds: 3600,
      key_type: :password_reset,
      error_message: "Password reset is cooling down. Try again after a short pause."
  end

  scope "/", RogsIdentityWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # API routes
  scope "/api/auth", RogsIdentityWeb.Api do
    pipe_through [:api, :rate_limit_login]

    post "/login", AuthController, :login
    post "/register", AuthController, :register
  end

  scope "/api/auth", RogsIdentityWeb.Api do
    pipe_through [:api, :api_authenticated]

    get "/me", AuthController, :me
  end

  scope "/api/auth", RogsIdentityWeb.Api do
    pipe_through :api

    post "/logout", AuthController, :logout
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:rogs_identity, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RogsIdentityWeb.Telemetry
    end
  end

  ## Authentication routes

  scope "/", RogsIdentityWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{RogsIdentityWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/users/profile", UserLive.Profile, :show
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", RogsIdentityWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{RogsIdentityWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
      live "/users/forgot-password", UserLive.ForgotPassword, :new
      live "/users/reset-password/:token", UserLive.ResetPassword, :edit
    end

    delete "/users/log-out", UserSessionController, :delete
  end

  # Login with rate limiting
  scope "/", RogsIdentityWeb do
    pipe_through [:browser, :rate_limit_login]

    post "/users/log-in", UserSessionController, :create
  end
end
