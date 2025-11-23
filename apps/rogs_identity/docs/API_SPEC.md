# RogsIdentity API仕様書

このドキュメントは、`rogs_identity`のRESTful APIエンドポイントの仕様を説明します。

## ベースURL

```
http://localhost:4000/api/auth
```

## 認証方法

APIエンドポイントは、セッションCookieベースの認証を使用します。ログイン後、セッションCookieが自動的に設定され、以降のリクエストで使用されます。

## エンドポイント一覧

### 1. POST /api/auth/login

ユーザーをログインさせます。

#### リクエスト（Email/Password）

```json
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

#### レスポンス（成功）

```json
HTTP/1.1 200 OK
Set-Cookie: _rogs_identity_key=...; Path=/; HttpOnly

{
  "success": true,
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

#### レスポンス（失敗）

```json
HTTP/1.1 401 Unauthorized

{
  "error": "Invalid email or password"
}
```

#### リクエスト（Magic Link Token）

```json
POST /api/auth/login
Content-Type: application/json

{
  "token": "abc123..."
}
```

#### レスポンス（成功）

```json
HTTP/1.1 200 OK
Set-Cookie: _rogs_identity_key=...; Path=/; HttpOnly

{
  "success": true,
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

#### レスポンス（失敗）

```json
HTTP/1.1 401 Unauthorized

{
  "error": "Invalid or expired token"
}
```

#### エラーレスポンス

| ステータスコード | 説明 |
|----------------|------|
| 400 | 必須パラメータが不足 |
| 401 | 認証情報が無効 |
| 429 | レート制限超過 |

### 2. POST /api/auth/register

新しいユーザーを登録します。

#### リクエスト

```json
POST /api/auth/register
Content-Type: application/json

{
  "email": "newuser@example.com",
  "name": "New User"
}
```

#### レスポンス（成功）

```json
HTTP/1.1 200 OK
Set-Cookie: _rogs_identity_key=...; Path=/; HttpOnly

{
  "success": true,
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "newuser@example.com",
    "name": "New User",
    "confirmed_at": null
  }
}
```

#### レスポンス（失敗）

```json
HTTP/1.1 422 Unprocessable Entity

{
  "error": "Validation failed",
  "errors": {
    "email": ["has already been taken"]
  }
}
```

#### エラーレスポンス

| ステータスコード | 説明 |
|----------------|------|
| 400 | 必須パラメータが不足 |
| 422 | バリデーションエラー |

### 3. GET /api/auth/me

現在認証されているユーザー情報を取得します。

#### リクエスト

```http
GET /api/auth/me
Cookie: _rogs_identity_key=...
```

#### レスポンス（成功）

```json
HTTP/1.1 200 OK

{
  "success": true,
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "name": "John Doe",
    "confirmed_at": "2024-01-01T00:00:00Z",
    "email_confirmed": true
  }
}
```

#### レスポンス（失敗）

```json
HTTP/1.1 401 Unauthorized

{
  "error": "Authentication required"
}
```

#### エラーレスポンス

| ステータスコード | 説明 |
|----------------|------|
| 401 | 認証されていない |

### 4. POST /api/auth/logout

ユーザーをログアウトさせます。

#### リクエスト

```http
POST /api/auth/logout
Cookie: _rogs_identity_key=...
```

#### レスポンス（成功）

```json
HTTP/1.1 200 OK
Set-Cookie: _rogs_identity_key=; Path=/; Max-Age=0

{
  "success": true,
  "message": "Logged out successfully"
}
```

#### エラーレスポンス

このエンドポイントは常に200を返します（認証されていない場合でも）。

## エラーレスポンス形式

### 標準エラーレスポンス

```json
{
  "error": "Error message"
}
```

### バリデーションエラー

```json
{
  "error": "Validation failed",
  "errors": {
    "field_name": ["error message 1", "error message 2"]
  }
}
```

## レート制限

以下のエンドポイントはレート制限が適用されます：

- `POST /api/auth/login`: 5回/5分（メールアドレスまたはIPアドレスごと）

レート制限に達した場合：

```json
HTTP/1.1 429 Too Many Requests

{
  "error": "Too many login attempts. Please try again later."
}
```

## セキュリティヘッダー

すべてのAPIレスポンスに以下のセキュリティヘッダーが含まれます：

```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
```

## 使用例

### cURL

```bash
# ログイン
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}' \
  -c cookies.txt

# ユーザー情報取得
curl -X GET http://localhost:4000/api/auth/me \
  -b cookies.txt

# ログアウト
curl -X POST http://localhost:4000/api/auth/logout \
  -b cookies.txt
```

### JavaScript (Fetch API)

```javascript
// ログイン
const loginResponse = await fetch('http://localhost:4000/api/auth/login', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  credentials: 'include',  // Cookieを送信
  body: JSON.stringify({
    email: 'user@example.com',
    password: 'password123'
  })
});

const loginData = await loginResponse.json();

// ユーザー情報取得
const meResponse = await fetch('http://localhost:4000/api/auth/me', {
  credentials: 'include'
});

const userData = await meResponse.json();

// ログアウト
await fetch('http://localhost:4000/api/auth/logout', {
  method: 'POST',
  credentials: 'include'
});
```

## 注意事項

1. **セッションCookie**: すべてのリクエストで`credentials: 'include'`を設定してください
2. **CORS**: 本番環境では適切なCORS設定が必要です
3. **HTTPS**: 本番環境では必ずHTTPSを使用してください
4. **トークンの有効期限**: セッショントークンは14日間有効です

