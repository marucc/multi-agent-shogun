#!/bin/bash
# switch_account.sh - Claudeアカウント切り替えスクリプト

SHOGUN_ROOT="$(cd "$(dirname "$0")" && pwd)"

# WORK_DIR 発見ロジック
if [ -d "$(pwd)/.shogun" ]; then
    WORK_DIR="$(pwd)"
else
    WORK_DIR="$SHOGUN_ROOT"
fi

# プロジェクト共通変数を読み込み
source "${SHOGUN_ROOT}/scripts/project-env.sh"

echo "=========================================="
echo "  Claude アカウント切り替え"
echo "=========================================="
echo ""

# 1. 現在のセッション状態確認
echo "📊 現在のセッション状態:"
tmux has-session -t "${TMUX_SHOGUN}" 2>/dev/null && echo "  - ${TMUX_SHOGUN}: 稼働中" || echo "  - ${TMUX_SHOGUN}: 停止中"
tmux has-session -t "${TMUX_MULTIAGENT}" 2>/dev/null && echo "  - ${TMUX_MULTIAGENT}: 稼働中" || echo "  - ${TMUX_MULTIAGENT}: 停止中"
echo ""

# 2. dashboard.md 最終更新確認
if [ -f "${DASHBOARD_PATH}" ]; then
  echo "📋 dashboard.md 最終更新:"
  head -2 "${DASHBOARD_PATH}" | tail -1
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
tmux kill-session -t "${TMUX_SHOGUN}" 2>/dev/null && echo "  - ${TMUX_SHOGUN} 停止完了"
tmux kill-session -t "${TMUX_MULTIAGENT}" 2>/dev/null && echo "  - ${TMUX_MULTIAGENT} 停止完了"

# watchdog停止
if [ -f "${SHOGUN_DATA_DIR}/watchdog.pid" ]; then
    kill "$(cat "${SHOGUN_DATA_DIR}/watchdog.pid")" 2>/dev/null && echo "  - watchdog 停止完了"
else
    pkill -f watchdog.sh 2>/dev/null && echo "  - watchdog 停止完了"
fi

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
  cd "$WORK_DIR" || exit 1
  "${SHOGUN_ROOT}/shutsujin_departure.sh"
else
  echo ""
  echo "手動で起動する場合:"
  echo "  cd ${WORK_DIR} && ${SHOGUN_ROOT}/shutsujin_departure.sh"
  echo "  または: .shogun/bin/shutsujin.sh"
fi

echo ""
echo "=========================================="
echo "  切り替え完了"
echo "=========================================="
