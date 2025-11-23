# サーバー起動ガイド

## 全サーバーを起動する

### 方法1: スクリプトを使用（推奨）

```bash
./start_servers.sh
```

### 方法2: 直接コマンドを実行

```bash
mix phx.server
```

Phoenix Umbrellaプロジェクトでは、ルートディレクトリで `mix phx.server` を実行すると、すべてのアプリケーションが自動的に起動します。

## 各サーバーのポート

- **ShinkankiWeb** (ゲームUI): http://localhost:4000
- **RogsIdentity** (認証): http://localhost:4001
- **RogsComm** (通信): http://localhost:4002

## ポート番号の変更

環境変数でポート番号を変更できます：

```bash
PORT=5000 PORT_ID=5001 PORT_COMM=5002 mix phx.server
```

または、スクリプトを使用する場合：

```bash
PORT=5000 PORT_ID=5001 PORT_COMM=5002 ./start_servers.sh
```

## データベースのセットアップ

初回起動時やマイグレーションが必要な場合：

```bash
mix ecto.migrate
```

## サーバーの停止

`Ctrl+C` を押すと、すべてのサーバーが停止します。

## トラブルシューティング

### ポートが既に使用されている場合

```bash
# ポートを確認
lsof -i :4000
lsof -i :4001
lsof -i :4002

# プロセスを終了
kill -9 <PID>
```

### データベースエラーが発生した場合

```bash
# データベースをリセット（注意：データが削除されます）
mix ecto.reset

# または、マイグレーションのみ実行
mix ecto.migrate
```

