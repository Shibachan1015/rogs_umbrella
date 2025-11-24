#!/bin/bash

# エラーが起きたら止まる設定
set -e

echo "🦄 ==================================="
echo "   ROGs Project: 全Worktree一括同期"
echo "=================================== 🦄"

sync_repo() {
    local dir="$1"
    local header="$2"
    local display="$3"
    local target="../$dir"

    echo ""
    echo "$header"

    if [ ! -d "$target" ]; then
        echo "⚠️  $dir directory not found, skipping."
        return
    fi

    (
        cd "$target"

        merge_output=$(git merge main --no-edit 2>&1)
        merge_status=$?

        if [ $merge_status -eq 0 ]; then
            if printf '%s' "$merge_output" | grep -q "Already up to date."; then
                echo "ℹ️  $display is already up to date (no changes)."
            elif printf '%s' "$merge_output" | grep -q "Fast-forward"; then
                echo "✅ $display fast-forwarded to main."
            else
                echo "✅ $display merged with main."
            fi
        else
            if printf '%s' "$merge_output" | grep -qi "CONFLICT"; then
                echo "❌ Merge conflict detected in $display. Resolve manually in $target."
            else
                echo "⚠️  Merge failed in $display. Details below:"
            fi
            echo "$merge_output"
            exit 1
        fi
    )
}

# 1. まず自分自身 (Main) を最新にする
echo ""
echo "📡 [1/5] Updating Main (rogs_umbrella)..."
git fetch origin
git pull origin main

sync_repo "rogs-identity" "🔐 [2/5] Syncing Identity (rogs-identity)..." "Identity"
sync_repo "rogs-chat" "💬 [3/5] Syncing Chat (rogs-chat)..." "Chat"
sync_repo "rogs-shinkanki" "🧠 [4/5] Syncing Shinkanki (rogs-shinkanki)..." "Shinkanki"
sync_repo "rogs-ui" "🎨 [5/5] Syncing UI (rogs-ui)..." "UI"

echo ""
echo "🎉 All Done! 全ての影分身が最新になりました。"

