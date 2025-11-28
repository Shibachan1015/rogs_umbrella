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

    get "/", PageController, :home

    # 認証ルート（未ログイン用）
    live "/users/log-in", UserLive.Login, :new
    live "/users/register", UserLive.Registration, :new
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete

    # ユーザー情報を取得するLiveSession
    live_session :with_user, on_mount: [{ShinkankiWebWeb.UserAuth, :default}] do
      # ロビー（ルーム一覧・作成）
      live "/lobby", LobbyLive

      # 待機室（ゲーム開始前）
      live "/room/:slug", WaitingRoomLive

      # ゲーム画面（ゲーム中）
      live "/game/:room_id", GameLive

      # プロフィール編集
      live "/profile", UserLive.Profile

      # フレンドリスト
      live "/friends", UserLive.Friends

      # ダイレクトメッセージ
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
