defmodule ShinkankiWebWeb.Router do
  use ShinkankiWebWeb, :router

  import RogsIdentity.Plug

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ShinkankiWebWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :authenticated do
    plug :require_authenticated
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ShinkankiWebWeb do
    pipe_through :browser

    # ==============================
    # 静的ページ（認証不要）
    # ==============================
    get "/", PageController, :home
    get "/rulebook", PageController, :rulebook
    get "/cards/talent", PageController, :talent_cards
    get "/cards/cocreation", PageController, :cocreation_cards
    get "/cards/action", PageController, :action_cards
    get "/cards/hitoyo", PageController, :hitoyo_cards
    get "/cards/migaki", PageController, :migaki_cards
    get "/kuukan", PageController, :kuukan

    # ==============================
    # 認証（rogs_identity ドメイン）
    # ==============================
    live "/users/log-in", UserLive.Login, :new
    live "/users/register", UserLive.Registration, :new
    post "/users/log-in", UserSessionController, :create
    get "/users/auto-login", UserSessionController, :auto_login
    delete "/users/log-out", UserSessionController, :delete

    # ==============================
    # 認証済みユーザー用
    # ==============================
    live_session :with_user, on_mount: [{ShinkankiWebWeb.UserAuth, :default}] do
      # --- rogs_comm ドメイン: ルーム・ロビー ---
      live "/lobby", LobbyLive
      live "/room/:slug", WaitingRoomLive

      # --- shinkanki ドメイン: ゲーム ---
      live "/game/:room_id", GameLive

      # --- rogs_identity ドメイン: ユーザー管理 ---
      live "/profile", UserLive.Profile
      live "/friends", UserLive.Friends
      live "/messages", UserLive.Messages
      live "/messages/:user_id", UserLive.Messages
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", ShinkankiWebWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:shinkanki_web, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ShinkankiWebWeb.Telemetry
    end
  end
end
