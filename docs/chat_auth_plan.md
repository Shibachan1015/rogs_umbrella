# Chat Authentication & Message Integrity Plan

このメモは `rogs_comm` のチャット機能を `rogs_identity` と連携させる際の設計方針と、追加で確認すべきメッセージ永続化テストの観点をまとめたものです。

## 1. 認証連携の方針

1. **セッション共有**
   - `rogs_identity` 側でサインイン済みユーザーの `user_id`/`email` をセッションに格納し、同一ドメイン内の `rogs_comm` にも送る。
   - Plug レイヤー（例: `RogsCommWeb.UserAssignPlug`）を用意して、セッションから `current_user_id` と `current_user_email` を `conn.assigns` に積む。

2. **LiveView 連携**
   - `ChatLive.mount/3` の第2引数 `session` に `user_id`/`user_email` を受け取り、`socket.assigns.display_name` と `socket.assigns.user_id` に投入する。
   - 匿名アクセス時は現在と同様にランダム UUID＋`anonymous` を採用。

3. **Channel 連携**
   - `/socket` 接続時に `params` へ `user_token` を付け、`RogsCommWeb.UserSocket` が `Phoenix.Token.verify` でユーザー情報を復元し `socket.assigns` へ格納する。
   - `ChatChannel` の `handle_in/3` では `socket.assigns.user_id/email` を信頼し、クライアント送信 payload の上書きを禁止する。

4. **API 提供**
   - 将来的に `rogs_identity` へ `display_name` を問い合わせる API (`GET /api/users/:id`) を用意し、`rogs_comm` がユーザー一覧をキャッシュできるようにする。

## 2. メッセージ永続化テスト

1. **Cascade 削除**
   - `rooms` 行削除時に `messages` が `on_delete: :delete_all` で確実に消えるかを `Rooms.delete_room/1` 経由でテストする。

2. **Pagination/Limit**
   - `Messages.list_messages(room_id, limit: N)` が `N` 件のみ返却し、古い順で並ぶことを確認済み。追加で `reset: true` を使った LiveView ストリーム向けのリセットテストを検討。

3. **Validation**
   - `content` 長さ（1..5000）、`user_email` 長さ（<=160）を超えた際にエラーが返ることを Changeset テストで担保。

4. **Demurrage/Retention (将来)**
   - ログ保管期間を設定する場合は `messages.inserted_at` ベースのクレンジングタスクを別途テストする。

## 3. 次のアクション

1. `rogs_identity` でサインイン済みセッションのキー名を決める（例: `"current_user_token"`）。
2. `RogsCommWeb.UserSocket` と `ChatLive` にユーザー情報を受け渡す仕組みを実装。
3. 上記に合わせて `Messages.create_message/1` から `user_email` を必須→任意にする検討（`user_id`のみ必須にして `display_name` は別テーブルで解決）。
4. テスト (`messages_test.exs`) にカスケード削除・バリデーションのケースを追加。

このメモをベースに、実装時は個別タスクへ分解してください。


