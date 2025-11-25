# RogsComm

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Available Features

- **TRDSベースのチャットUI**  
  和紙・朱・松などのカラートークンを使ったヒーロー／サイドバー／メッセージカード。
- **高度な検索とハイライト**  
  ルーム内検索＋ハイライト表示、検索モード時は `ChatStateHook` が状態を通知。
- **WebRTCシグナリングUI**  
  Audioパネルで接続・切断・マイク/スピーカーのトグルを操作でき、状態はピルとステータス文に反映。
- **ページネーション & メッセージ編集**  
  古いメッセージの読み込みや自身のメッセージ編集/削除に対応。

## Local Development

```bash
# 依存取得と初期セットアップ
cd apps/rogs_comm
mix setup

# サーバー起動
mix phx.server

# 単体テスト
mix test apps/rogs_comm
```

## Design System

チャットUIは Torii Resonance Design System (TRDS) に準拠しています。  
スタイルガイドは [`../../docs/torii_resonance_design_system.md`](../../docs/torii_resonance_design_system.md) を参照してください。

## Reference

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
- Source: https://github.com/phoenixframework/phoenix
