#!/bin/bash
# switch_account.sh - Claudeアカウント切り替えスクリプト

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=========================================="
echo "  Claude アカウント切り替え"
echo "=========================================="
echo ""

# 1. 現在のセッション状態確認
echo "📊 現在のセッション状態:"
tmux has-session -t shogun 2>/dev/null && echo "  - shogun: 稼働中" || echo "  - shogun: 停止中"
tmux has-session -t multiagent 2>/dev/null && echo "  - multiagent: 稼働中" || echo "  - multiagent: 停止中"
echo ""

# 2. dashboard.md 最終更新確認
if [ -f "$SCRIPT_DIR/dashboard.md" ]; then
  echo "📋 dashboard.md 最終更新:"
  head -2 "$SCRIPT_DIR/dashboard.md" | tail -1
  echo ""
fi

# 3. 確認
echo "⚠️  全セッションを停止してアカウントを切り替えます。"
echo "よろしいですか？ (y/n)"
read -r answer

if [ "$answer" != "y" ]; then
  echo "キャンセルしました。"
  exit 0
fi

# 4. セッション停止
echo ""
echo "🛑 セッションを停止中..."
tmux kill-session -t shogun 2>/dev/null && echo "  - shogun 停止完了"
tmux kill-session -t multiagent 2>/dev/null && echo "  - multiagent 停止完了"

# watchdog停止
pkill -f watchdog.sh 2>/dev/null && echo "  - watchdog 停止完了"

echo ""

# 5. 現在のアカウント表示
echo "🔍 現在のClaudeアカウント:"
claude auth whoami 2>/dev/null || echo "  (ログインしていません)"
echo ""

# 6. ログアウト
echo "🚪 ログアウト中..."
claude logout

# 7. 新規ログイン
echo ""
echo "🔑 新しいアカウントでログインしてください:"
claude login

if [ $? -ne 0 ]; then
  echo "❌ ログインに失敗しました。"
  exit 1
fi

echo ""
echo "✅ アカウント切り替え完了"
echo ""

# 8. 新アカウント確認
echo "📝 新しいアカウント:"
claude auth whoami
echo ""

# 9. 再起動確認
echo "🚀 セッションを再起動しますか？ (y/n)"
read -r restart_answer

if [ "$restart_answer" = "y" ]; then
  echo ""
  echo "起動中..."

  # shogun起動
  cd "$SCRIPT_DIR" || exit 1
  ./shogun.sh &
  SHOGUN_PID=$!
  sleep 2

  # multiagent起動
  ./multiagent.sh &
  MULTIAGENT_PID=$!
  sleep 2

  # watchdog起動
  ./watchdog.sh &
  WATCHDOG_PID=$!

  echo ""
  echo "✅ 起動完了"
  echo "  - shogun: PID $SHOGUN_PID"
  echo "  - multiagent: PID $MULTIAGENT_PID"
  echo "  - watchdog: PID $WATCHDOG_PID"
  echo ""
  echo "📊 dashboard確認: cat dashboard.md"
  echo "📋 ログ確認: tail -f logs/watchdog.log"
else
  echo ""
  echo "手動で起動する場合:"
  echo "  ./shogun.sh &"
  echo "  ./multiagent.sh &"
  echo "  ./watchdog.sh &"
fi

echo ""
echo "=========================================="
echo "  切り替え完了"
echo "=========================================="
