# RogsIdentity アーキテクチャドキュメント

このドキュメントは、`rogs_identity`認証システムのアーキテクチャと内部実装の詳細を説明します。

## 目次

1. [概要](#概要)
2. [認証フロー](#認証フロー)
3. [セッション管理](#セッション管理)
4. [トークン管理](#トークン管理)
5. [セキュリティ対策](#セキュリティ対策)

## 概要

`rogs_identity`は、ROGs Umbrellaプロジェクト全体で使用される認証システムです。以下の主要コンポーネントで構成されています：

- **Accounts Context**: ユーザー管理と認証ロジック
- **UserAuth Module**: ブラウザベースの認証処理
- **Plug Module**: 他のアプリからの認証連携
- **API Controllers**: RESTful APIエンドポイント
- **LiveViews**: ユーザーインターフェース

## 認証フロー

### 1. ユーザー登録フロー

```
1. ユーザーが登録フォームに入力
   ↓
2. Accounts.register_user/1 が呼ばれる
   ↓
3. ユーザーがデータベースに作成される（confirmed_at: nil）
   ↓
4. メール確認トークンが生成される（オプション）
   ↓
5. セッショントークンが生成され、ユーザーがログイン状態になる
```

### 2. ログインフロー

#### パスワードログイン

```
1. ユーザーがemail/passwordを入力
   ↓
2. Accounts.get_user_by_email_and_password/2 で検証
   ↓
3. パスワードが正しい場合、セッショントークンを生成
   ↓
4. トークンがセッションとCookieに保存される
   ↓
5. ユーザーが認証済み状態になる
```

#### マジックリンクログイン

```
1. ユーザーがemailを入力
   ↓
2. Accounts.deliver_login_instructions/2 が呼ばれる
   ↓
3. メールにマジックリンクトークンが送信される
   ↓
4. ユーザーがリンクをクリック
   ↓
5. Accounts.login_user_by_magic_link/1 でトークンを検証
   ↓
6. 未確認ユーザーの場合、メール確認も同時に実行
   ↓
7. セッショントークンが生成され、ログイン完了
```

### 3. 認証状態の確認フロー

```
1. リクエストが到着
   ↓
2. fetch_session でセッションを取得
   ↓
3. fetch_current_user でセッションからトークンを取得
   ↓
4. Accounts.get_user_by_session_token/1 でトークンを検証
   ↓
5. トークンが有効な場合、ユーザー情報を取得
   ↓
6. conn.assigns.current_user に設定
```

## セッション管理

### セッショントークンの生成

セッショントークンは、`UserToken.build_session_token/1`で生成されます：

```elixir
def build_session_token(user) do
  token = :crypto.strong_rand_bytes(32)
  {token, %UserToken{
    token: token,
    context: "session",
    user_id: user.id,
    authenticated_at: NaiveDateTime.utc_now(:second)
  }}
end
```

### セッションの保存

トークンは以下の場所に保存されます：

1. **データベース**: `users_tokens`テーブル（永続化）
2. **セッションCookie**: `:user_token`キー（ブラウザセッション）
3. **Remember Me Cookie**: `_rogs_identity_web_user_remember_me`（14日間有効）

### セッションの有効期限

- **デフォルト有効期限**: 14日間
- **再発行タイミング**: 7日経過後（アクティブなユーザー向け）
- **設定**: `UserToken.@session_validity_in_days`

### セッションの無効化

セッションは以下の場合に無効化されます：

1. **明示的なログアウト**: `Accounts.delete_user_session_token/1`
2. **パスワード変更**: すべてのトークンが削除される
3. **有効期限切れ**: 14日経過後、自動的に無効化
4. **手動削除**: `Accounts.delete_user_session_token_by_id/2`

### セッション固定化攻撃の防止

ログイン時にセッションIDを更新することで、セッション固定化攻撃を防止します：

```elixir
defp renew_session(conn, _user) do
  conn
  |> configure_session(renew: true)  # セッションIDを更新
  |> clear_session()  # 既存のセッションデータをクリア
end
```

## トークン管理

### トークンの種類

1. **セッショントークン** (`context: "session"`)
   - 用途: 通常のログインセッション
   - 有効期限: 14日間
   - 保存場所: データベース + Cookie

2. **マジックリンクトークン** (`context: "login"`)
   - 用途: メール経由のログイン
   - 有効期限: 15分
   - 保存場所: データベース（ハッシュ化）

3. **パスワードリセットトークン** (`context: "reset_password"`)
   - 用途: パスワードリセット
   - 有効期限: 6時間
   - 保存場所: データベース（ハッシュ化）

4. **メール確認トークン** (`context: "change:email"`)
   - 用途: メールアドレス変更
   - 有効期限: 7日間
   - 保存場所: データベース（ハッシュ化）

### トークンの生成

#### セッショントークン

```elixir
# プレーンテキスト（署名済みCookieに保存）
token = :crypto.strong_rand_bytes(32)
```

#### メールトークン（ハッシュ化）

```elixir
# 1. ランダムトークンを生成
token = :crypto.strong_rand_bytes(32)

# 2. ハッシュ化
hashed_token = :crypto.hash(:sha256, token)

# 3. URL-safeエンコード
encoded_token = Base.url_encode64(token, padding: false)

# 4. データベースにはハッシュのみ保存
# メールにはエンコードされたトークンを送信
```

### トークンの検証

```elixir
def verify_session_token_query(token) do
  query =
    from token in UserToken,
      where: token.token == ^token,
      where: token.context == "session",
      where: token.inserted_at > ago(14, "day"),
      join: user in assoc(token, :user),
      select: {user, token.inserted_at}

  {:ok, query}
end
```

## セキュリティ対策

### 1. レート制限

#### ログイン試行の制限

- **最大試行回数**: 5回
- **時間窓**: 5分間（300秒）
- **キー**: メールアドレスまたはIPアドレス

#### パスワードリセットの制限

- **最大試行回数**: 3回
- **時間窓**: 1時間（3600秒）
- **キー**: メールアドレス

#### 実装

```elixir
plug RogsIdentityWeb.Plug.RateLimit,
  max_attempts: 5,
  window_seconds: 300,
  key_type: :login
```

### 2. パスワードセキュリティ

- **ハッシュアルゴリズム**: bcrypt
- **コスト**: 12（デフォルト）
- **保存**: プレーンテキストは保存しない

### 3. CSRF対策

- **ブラウザリクエスト**: `protect_from_forgery`で保護
- **APIリクエスト**: トークンベース認証のため不要

### 4. セキュリティヘッダー

以下のヘッダーが自動的に設定されます：

- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`

### 5. セッション固定化攻撃の防止

- ログイン時にセッションIDを更新
- 異なるユーザーでログインした場合、セッションをクリア

### 6. トークンのセキュリティ

- **セッショントークン**: 32バイトのランダムデータ
- **メールトークン**: SHA-256でハッシュ化
- **有効期限**: 用途に応じて適切な期間を設定

## データベーススキーマ

### users テーブル

```elixir
- id: binary_id (UUID)
- email: string (unique)
- hashed_password: binary
- name: string (nullable)
- confirmed_at: naive_datetime (nullable)
- inserted_at: datetime
- updated_at: datetime
```

### users_tokens テーブル

```elixir
- id: binary_id (UUID)
- token: binary
- context: string
- sent_to: string (nullable)
- authenticated_at: naive_datetime (nullable)
- user_id: binary_id (foreign key)
- inserted_at: datetime
```

## パフォーマンス考慮事項

### 1. トークン検証の最適化

- インデックス: `users_tokens`テーブルの`token`と`context`にインデックス
- クエリ最適化: `inserted_at`で期限切れトークンをフィルタリング

### 2. セッション管理

- ETSテーブル: レート制限用（メモリ内）
- データベース: セッショントークン（永続化）

### 3. キャッシュ戦略

現在は実装されていませんが、将来的に以下を検討：

- ユーザー情報のキャッシュ
- セッショントークンのキャッシュ（Redis等）

## 拡張性

### カスタムスコープの追加

`Accounts.Scope`を拡張して、追加の権限情報を保持できます：

```elixir
defmodule RogsIdentity.Accounts.Scope do
  defstruct user: nil, role: :user, permissions: []

  def for_user(%User{} = user) do
    %__MODULE__{
      user: user,
      role: get_user_role(user),
      permissions: get_user_permissions(user)
    }
  end
end
```

### 追加の認証方法

新しい認証方法（OAuth、SAML等）を追加する場合：

1. `Accounts`コンテキストに新しい関数を追加
2. 新しいトークンタイプを`UserToken`に追加
3. 対応するコントローラーまたはLiveViewを実装

## 参考資料

- [Phoenix Authentication Guide](https://hexdocs.pm/phoenix/authentication.html)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)

