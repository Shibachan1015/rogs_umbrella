# RogsIdentity 統合ガイド

このドキュメントは、ROGs Umbrellaプロジェクト内の他のアプリケーション（`rogs_comm`、`shinkanki_web`など）から`rogs_identity`の認証機能を利用する方法を説明します。

## 目次

1. [概要](#概要)
2. [認証連携の手順](#認証連携の手順)
3. [Plugの使用方法](#plugの使用方法)
4. [実装例](#実装例)
5. [ベストプラクティス](#ベストプラクティス)
6. [トラブルシューティング](#トラブルシューティング)

## 概要

`rogs_identity`は、ROGs Umbrellaプロジェクト全体で使用される認証システムです。他のアプリケーションは、`RogsIdentity.Plug`を使用して認証機能を統合できます。

### 主な機能

- セッションベースの認証
- ユーザー情報の取得
- 認証状態の確認
- 保護されたルートの実装

### セッション共有

すべてのアプリケーションは、同じドメインで実行される場合、Cookieベースのセッションを共有します。これにより、`rogs_identity`でログインしたユーザーは、他のアプリケーションでも自動的に認証されます。

## 認証連携の手順

### 1. 依存関係の追加

`mix.exs`に`rogs_identity`を依存関係として追加します：

```elixir
defp deps do
  [
    # ... 他の依存関係 ...
    {:rogs_identity, in_umbrella: true}
  ]
end
```

### 2. Routerの設定

`router.ex`で`RogsIdentity.Plug`をインポートし、パイプラインに追加します：

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  import RogsIdentity.Plug

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user  # 認証情報を取得
  end

  pipeline :authenticated do
    plug :require_authenticated  # 認証を必須にする
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/protected", MyAppWeb do
    pipe_through [:browser, :authenticated]

    get "/dashboard", DashboardController, :index
  end
end
```

### 3. コントローラーでの使用

コントローラーで認証されたユーザーにアクセスできます：

```elixir
defmodule MyAppWeb.DashboardController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    user = conn.assigns.current_user
    scope = conn.assigns.current_scope

    render(conn, :index, user: user)
  end
end
```

## Plugの使用方法

### `fetch_current_user`

現在のユーザーを取得します。認証されていない場合、`current_user`は`nil`になります。

```elixir
pipeline :browser do
  plug :fetch_current_user
end
```

**設定される値：**
- `conn.assigns.current_user` - 認証されたユーザー（または`nil`）
- `conn.assigns.current_scope` - ユーザースコープ（または`nil`）

### `require_authenticated`

認証を必須にします。認証されていない場合：
- ブラウザリクエスト: ログインページにリダイレクト
- APIリクエスト: 401 Unauthorizedを返す

```elixir
pipeline :authenticated do
  plug :require_authenticated
end
```

## 実装例

### 例1: 基本的な保護されたルート

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  import RogsIdentity.Plug

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_current_user
  end

  pipeline :authenticated do
    plug :require_authenticated
  end

  scope "/", MyAppWeb do
    pipe_through [:browser, :authenticated]

    get "/profile", ProfileController, :show
    get "/settings", SettingsController, :edit

    live_session :torii_profile,
      on_mount: [{RogsIdentityWeb.UserAuth, :require_authenticated}] do
      live "/users/profile", RogsIdentityWeb.UserLive.Profile, :show
    end
  end
end
```

### 例2: APIエンドポイントでの認証

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  import RogsIdentity.Plug

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_current_user
  end

  pipeline :api_authenticated do
    plug :require_authenticated
  end

  scope "/api", MyAppWeb.Api do
    pipe_through [:api, :api_authenticated]

    get "/user/data", DataController, :index
  end
end
```

### 例3: 条件付きアクセス

```elixir
defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller

  def home(conn, _params) do
    case conn.assigns.current_user do
      nil ->
        render(conn, :home, user: nil)

      user ->
        render(conn, :dashboard, user: user)
    end
  end
end
```

### 例4: ユーザー情報の取得

```elixir
defmodule MyAppWeb.UserHelper do
  alias RogsIdentity

  def get_user_display_name(user_id) do
    RogsIdentity.get_display_name(user_id)
  end

  def get_user(user_id) do
    RogsIdentity.get_user(user_id)
  end
end
```

### 例5: Federated apps設定

`config/config.exs` に以下のような `:federated_apps` を定義すると、`/users/profile` でTRDSスタイルのSSOカードが表示されます：

```elixir
config :rogs_identity, :federated_apps,
  [
    %{
      id: :shinkanki_web,
      name: "Shinkanki Web",
      description: "Game interface & LiveView HUD.",
      scopes: ["gameplay", "state-sync"],
      surface: :game,
      url: "http://localhost:4000",
      status: :connected
    }
  ]
```

## ベストプラクティス

### 1. パイプラインの順序

`fetch_current_user`は、`fetch_session`の後に配置してください：

```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session  # 先にセッションを取得
  plug :fetch_current_user  # その後、認証情報を取得
  # ... 他のプラグ ...
end
```

### 2. 認証が必要なルートのグループ化

認証が必要なルートは、専用のスコープにグループ化します：

```elixir
scope "/protected", MyAppWeb do
  pipe_through [:browser, :authenticated]

  get "/dashboard", DashboardController, :index
  get "/settings", SettingsController, :edit
end
```

### 3. ユーザー情報の取得

直接データベースにアクセスする代わりに、`RogsIdentity`モジュールの関数を使用します：

```elixir
# 良い例
user = RogsIdentity.get_user(user_id)
name = RogsIdentity.get_display_name(user_id)

# 避けるべき例
user = RogsIdentity.Accounts.get_user(user_id)  # 内部APIに直接アクセス
```

### 4. エラーハンドリング

認証が必要な操作では、適切なエラーハンドリングを実装します：

```elixir
def create(conn, params) do
  case conn.assigns.current_user do
    nil ->
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Authentication required"})

    user ->
      # 処理を続行
      # ...
  end
end
```

## トラブルシューティング

### 問題1: `current_user`が常に`nil`になる

**原因：**
- セッションが正しく設定されていない
- `fetch_session`が`fetch_current_user`の前に呼ばれていない

**解決方法：**
```elixir
pipeline :browser do
  plug :fetch_session  # これを先に
  plug :fetch_current_user  # その後
end
```

### 問題2: リダイレクトループが発生する

**原因：**
- ログインページ自体が`require_authenticated`パイプラインを通っている

**解決方法：**
ログインページは認証不要のスコープに配置します：

```elixir
scope "/", MyAppWeb do
  pipe_through :browser  # 認証不要

  get "/login", LoginController, :new
end

scope "/protected", MyAppWeb do
  pipe_through [:browser, :authenticated]  # 認証必須

  get "/dashboard", DashboardController, :index
end
```

### 問題3: セッションが他のアプリと共有されない

**原因：**
- 異なるドメインで実行されている
- Cookieの設定が正しくない

**解決方法：**
- 開発環境: すべてのアプリを同じドメイン（`localhost`）で実行
- 本番環境: Cookieドメインを適切に設定

### 問題4: `RogsIdentity.Plug`が見つからない

**原因：**
- `mix.exs`に依存関係が追加されていない
- `mix deps.get`が実行されていない

**解決方法：**
```bash
# mix.exsに追加
{:rogs_identity, in_umbrella: true}

# 依存関係を取得
mix deps.get
mix compile
```

### 問題5: APIリクエストで401エラーが返される

**原因：**
- セッショントークンが送信されていない
- トークンが無効または期限切れ

**解決方法：**
- ブラウザからのリクエスト: Cookieが自動的に送信されることを確認
- APIクライアント: セッションCookieをリクエストに含める

## 参考資料

- [RogsIdentity.Plug モジュールドキュメント](../lib/rogs_identity/plug.ex)
- [RogsIdentity モジュールドキュメント](../lib/rogs_identity.ex)
- [Phoenix Plug ドキュメント](https://hexdocs.pm/plug/readme.html)

