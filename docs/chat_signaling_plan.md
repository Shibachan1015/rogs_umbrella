# WebRTC Signaling API Draft (rogs_comm)

この文書は `rogs_comm` が提供する WebRTC シグナリングレイヤーの方針をまとめた叩き台です。Phoenix Channel をベースに、テキストチャットと同じトポロジで `offer`/`answer`/`ice-candidate` をやり取りできるようにします。

## 1. トポロジ

- **トピック**: `room:<room_id>`
- **Channel モジュール**: 既存の `RogsCommWeb.ChatChannel` にシグナリングイベントを追加するか、`RogsCommWeb.SignalingChannel` を作成して用途を分離する。
- **ペイロード共通項目**
  - `room_id` (binary_id, 必須)
  - `from` (user_id)
  - `to` (user_id | `"broadcast"`)
  - `timestamp` (ISO8601)

## 2. イベント仕様

| Event             | Direction        | Payload fields                                                                          | Notes                                                   |
|-------------------|------------------|-----------------------------------------------------------------------------------------|--------------------------------------------------------|
| `"offer"`         | client → server  | `sdp`, `from`, `to?`, `constraints?`                                                    | Server が `broadcast!(topic, "offer", payload)`        |
| `"answer"`        | client → server  | `sdp`, `from`, `to`                                                                     | 相手を限定する場合は `to` を必須                       |
| `"ice-candidate"` | client ↔ client | `candidate`, `sdpMid`, `sdpMLineIndex`, `from`, `to?`                                   | 早期到着対策でキューを持つことを検討                   |
| `"peer-ready"`    | server → client | `from`, `tracks`                                                                        | 参加者が揃ったことを通知（任意）                      |

## 3. 認証・権限

1. Channel join 時に `socket.assigns.user_id` が必須。匿名参加は許容する場合でも `Ecto.UUID.generate()` を割り当ててブロードキャスト。
2. `to` を指定したイベントはサーバー側で `room_id` の所属を検証し、未参加ユーザーへの送信を防ぐ。
3. レートリミット（例: 1 秒あたり 5 イベント）を `Phoenix.PubSub` とは別に `:ets` で実装する案も検討。

## 4. 状態管理

- **短期**: サーバーは stateless（イベントを流すだけ）。
- **中期**: `SignalingSession` スキーマを設け、`offer`/`answer` の履歴や参加者リストを永続化。
- **長期**: SFU 等の別サービスを導入する場合は、この Channel を WebRTC Gateway へのブリッジとして利用。

## 5. フロントエンド API 例

```javascript
const channel = realtimeSocket.channel(`room:${roomId}`, {})

channel.push("offer", {
  room_id: roomId,
  from: currentUserId,
  to: targetUserId,
  sdp: offer.sdp
})

channel.on("answer", payload => {
  peerConnection.setRemoteDescription(new RTCSessionDescription(payload))
})
```

## 6. 次のステップ

1. `RogsCommWeb.ChatChannel` に `handle_in/3` を追加し、イベント検証・ブロードキャストの骨組みを実装。
2. `apps/rogs_comm/lib/rogs_comm/signaling/` に小さな context を作り、後で `SignalingSession` を追加しやすくする。
3. フロントエンド（`assets/js`）に WebRTC Hook を追加し、テスト peer 間で `offer/answer/ice` をやり取りできることを確認。
4. `docs/chat_auth_plan.md` と整合を取りながら、認証済みユーザーに限定した signaling を行う。

この草案はあくまで最初の方向性です。実装フェーズで詳細を更新してください。

