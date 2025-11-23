#!/bin/bash

# エラーが起きたら止まる設定
set -e

echo "🦄 ==================================="
echo "   ROGs Project: 全Worktree一括同期"
echo "=================================== 🦄"

# 1. まず自分自身 (Main) を最新にする
echo ""
echo "📡 [1/5] Updating Main (rogs_umbrella)..."
git fetch origin
git pull origin main

# 2. Identity (認証) に反映
echo ""
echo "🔐 [2/5] Syncing Identity (rogs-identity)..."
if [ -d "../rogs-identity" ]; then
    (cd "../rogs-identity" && git merge main -m "Sync with main" || echo "⚠️ Merge conflict or empty commit in rogs-identity. Check manually.")
    echo "✅ Identity OK"
else
    echo "⚠️ rogs-identity directory not found, skipping."
fi

# 3. Chat (通信) に反映
echo ""
echo "💬 [3/5] Syncing Chat (rogs-chat)..."
if [ -d "../rogs-chat" ]; then
    (cd "../rogs-chat" && git merge main -m "Sync with main" || echo "⚠️ Merge conflict or empty commit in rogs-chat. Check manually.")
    echo "✅ Chat OK"
else
    echo "⚠️ rogs-chat directory not found, skipping."
fi

# 4. Shinkanki (メインロジック) に反映
echo ""
echo "🧠 [4/5] Syncing Shinkanki (rogs-shinkanki)..."
if [ -d "../rogs-shinkanki" ]; then
    (cd "../rogs-shinkanki" && git merge main -m "Sync with main" || echo "⚠️ Merge conflict or empty commit in rogs-shinkanki. Check manually.")
    echo "✅ Shinkanki OK"
else
    echo "⚠️ rogs-shinkanki directory not found, skipping."
fi

# 5. UI (画面) に反映
echo ""
echo "🎨 [5/5] Syncing UI (rogs-ui)..."
if [ -d "../rogs-ui" ]; then
    (cd "../rogs-ui" && git merge main -m "Sync with main" || echo "⚠️ Merge conflict or empty commit in rogs-ui. Check manually.")
    echo "✅ UI OK"
else
    echo "⚠️ rogs-ui directory not found, skipping."
fi

echo ""
echo "🎉 All Done! 全ての影分身が最新になりました。"

