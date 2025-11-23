#!/bin/bash

# ROGs Umbrella - 全サーバー起動スクリプト
# このスクリプトは、Phoenix Umbrellaプロジェクトのすべてのアプリケーションを起動します

set -e

# カラー出力用
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  ROGs Umbrella サーバー起動${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# プロジェクトルートに移動
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# データベースのマイグレーション確認
echo -e "${YELLOW}データベースの状態を確認中...${NC}"
if ! mix ecto.migrate --quiet 2>/dev/null; then
  echo -e "${YELLOW}データベースのマイグレーションを実行中...${NC}"
  mix ecto.migrate
fi

# ポート番号の設定（環境変数が設定されていない場合）
export PORT=${PORT:-4000}
export PORT_ID=${PORT_ID:-4001}
export PORT_COMM=${PORT_COMM:-4002}

echo -e "${GREEN}起動するサーバー:${NC}"
echo -e "  ${BLUE}ShinkankiWeb${NC}    (ゲームUI)      → http://localhost:${PORT}"
echo -e "  ${BLUE}RogsIdentity${NC}    (認証)          → http://localhost:${PORT_ID}"
echo -e "  ${BLUE}RogsComm${NC}        (通信)          → http://localhost:${PORT_COMM}"
echo ""
echo -e "${YELLOW}サーバーを起動しています...${NC}"
echo -e "${YELLOW}(Ctrl+C で停止)${NC}"
echo ""

# Phoenixサーバーを起動（Umbrellaプロジェクトではすべてのアプリが起動される）
mix phx.server

