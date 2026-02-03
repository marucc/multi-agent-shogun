#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# notify.sh - tmux send-keys ラッパー（Enter自動付与）
# ═══════════════════════════════════════════════════════════════════════════════
#
# 【重要】tmux send-keys を直接使うな！このスクリプトを使え！
#
# 理由:
#   - tmux send-keys でメッセージと Enter を同時に送ると届かないことがある
#   - このスクリプトは sleep 0.1 を挟んで確実に Enter を送信する
#
# 使い方:
#   ./scripts/notify.sh <pane> <message>
#
# 例:
#   ./scripts/notify.sh multiagent:0.2 'タスクあり。確認せよ。'
#   ./scripts/notify.sh shogun 'dashboard.md が更新された。確認せよ。'
#
# 送り先一覧:
#   | 送り先 | pane            |
#   |--------|-----------------|
#   | 将軍   | shogun:0.0      |
#   | 家老   | multiagent:0.0  |
#   | 目付   | multiagent:0.1  |
#   | 足軽1  | multiagent:0.2  |
#   | 足軽N  | multiagent:0.N+1|
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

pane="$1"
message="$2"

if [ -z "$pane" ] || [ -z "$message" ]; then
  echo "使い方: $0 <pane> <message>"
  echo "例: $0 multiagent:0.2 'タスクあり。確認せよ。'"
  exit 1
fi

tmux send-keys -t "$pane" "$message"
sleep 0.1
tmux send-keys -t "$pane" Enter
