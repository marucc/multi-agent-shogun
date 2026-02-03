#!/bin/bash
# watchdog.sh - multi-agent-shogun 監視スクリプト
# 使い方: ./watchdog.sh &
#
# 機能:
#   - 将軍・家老のLimit検知とリセット後の自動通知
#   - dashboard.md更新検知 → 将軍に通知
#   - 家老のアイドル検知（未処理報告がある場合）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/watchdog.log"
CHECK_INTERVAL=300  # 5分ごとにチェック
LIMIT_RESET_FILE="$SCRIPT_DIR/.limit_reset_times"

# ログディレクトリ作成
mkdir -p "$SCRIPT_DIR/logs"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

notify() {
  local pane=$1
  local message=$2
  "$SCRIPT_DIR/scripts/notify.sh" "$pane" "$message"
}

# 12時間形式の時刻をUNIXタイムスタンプに変換（今日の日付で）
# 例: "2pm" → 今日の14:00のタイムスタンプ
#     "2:30pm" → 今日の14:30のタイムスタンプ
parse_reset_time_to_timestamp() {
  local reset_time=$1
  local hour minute ampm

  # 時刻と分を抽出（例: "2:30pm" → hour=2, minute=30, ampm=pm）
  if echo "$reset_time" | grep -q ":"; then
    hour=$(echo "$reset_time" | grep -oE "^[0-9]+" | head -1)
    minute=$(echo "$reset_time" | grep -oE ":[0-9]+" | sed 's/://')
  else
    hour=$(echo "$reset_time" | grep -oE "^[0-9]+" | head -1)
    minute=0
  fi

  # AM/PM判定
  if echo "$reset_time" | grep -qi "pm"; then
    [ "$hour" -ne 12 ] && hour=$((hour + 12))
  else
    [ "$hour" -eq 12 ] && hour=0
  fi

  # 今日の日付でタイムスタンプを生成
  local today=$(date "+%Y-%m-%d")
  date -j -f "%Y-%m-%d %H:%M" "$today $hour:$minute" "+%s" 2>/dev/null || \
    date -d "$today $hour:$minute" "+%s" 2>/dev/null
}

# 1. Limit検知（将軍・家老のみログ出力・記録）
check_limit() {
  local pane=$1
  local name=$2
  local log_enabled=${3:-true}  # 将軍・家老はtrue、足軽はfalse

  local output=$(tmux capture-pane -t "$pane" -p 2>/dev/null | tail -20)

  # Limit検知（リセット時刻付き）
  # 例: "resets 1pm (Asia/Tokyo)" or "resets 2:30pm"
  if echo "$output" | grep -qE "You've used [0-9]+% of your session limit|resets [0-9]+"; then
    local reset_time=$(echo "$output" | grep -oE "resets [0-9]+:?[0-9]*[ap]m" | tail -1 | sed 's/resets //')

    if [ -n "$reset_time" ]; then
      # 将軍・家老のみログ出力と記録
      if [ "$log_enabled" = true ]; then
        # 既に記録済みでなければ記録
        if ! grep -q "^$name:$reset_time:" "$LIMIT_RESET_FILE" 2>/dev/null; then
          local reset_ts=$(parse_reset_time_to_timestamp "$reset_time")
          log "🚨 [$name] Limit検知 - リセット時刻: $reset_time"
          echo "$name:$reset_time:$reset_ts:$(date +%s)" >> "$LIMIT_RESET_FILE"
        fi
      fi
    fi
    return 0
  fi

  # Limit完全停止検知
  if echo "$output" | grep -qE "You've hit your limit|Stop and wait for limit to reset"; then
    if [ "$log_enabled" = true ]; then
      log "🚨 [$name] Limit完全停止検知"
    fi
    return 0
  fi

  return 1
}

# 2. Limitリセット後の自動再開（将軍・家老のみ通知）
check_limit_reset() {
  [ ! -f "$LIMIT_RESET_FILE" ] && return 1
  [ ! -s "$LIMIT_RESET_FILE" ] && return 1  # 空ファイルもスキップ

  local now=$(date +%s)
  local notified_names=""

  while IFS= read -r line; do
    [ -z "$line" ] && continue

    local name=$(echo "$line" | cut -d: -f1)
    local reset_time=$(echo "$line" | cut -d: -f2)
    local reset_ts=$(echo "$line" | cut -d: -f3)
    local recorded_ts=$(echo "$line" | cut -d: -f4)

    # 将軍・家老以外はスキップ
    if [ "$name" != "shogun" ] && [ "$name" != "karo" ]; then
      continue
    fi

    # リセット時刻を過ぎたか確認（UNIXタイムスタンプで比較）
    if [ "$now" -ge "$reset_ts" ]; then
      # 記録から6時間以内なら通知
      local age=$((now - recorded_ts))
      if [ "$age" -lt 21600 ]; then  # 6時間以内の記録
        log "✅ [$name] Limitリセット時刻($reset_time)を過ぎた - 再開指示"

        case "$name" in
          shogun)
            notify "shogun:0.0" "Limitがリセットされた。作業を再開せよ。"
            ;;
          karo)
            notify "multiagent:0.0" "Limitがリセットされた。作業を再開せよ。"
            ;;
        esac

        notified_names="$notified_names $name"
      fi
    fi
  done < "$LIMIT_RESET_FILE"

  # 通知済みの記録を削除
  for name in $notified_names; do
    grep -v "^$name:" "$LIMIT_RESET_FILE" > "$LIMIT_RESET_FILE.tmp" 2>/dev/null
    mv "$LIMIT_RESET_FILE.tmp" "$LIMIT_RESET_FILE" 2>/dev/null || true
  done

  return 0
}

# 3. アイドル検知（お見合い状態）
check_idle() {
  local pane=$1
  local name=$2

  local output=$(tmux capture-pane -t "$pane" -p 2>/dev/null | tail -5)

  # プロンプト（❯）が表示されている = アイドル
  if echo "$output" | grep -qE "^❯ *$"; then
    # 家老の場合、未処理報告があるか確認
    if [ "$name" = "karo" ]; then
      local report_count=$(find "$SCRIPT_DIR/queue/reports" -name "*.yaml" -mmin -10 -type f 2>/dev/null | wc -l | tr -d ' ')

      if [ "$report_count" -gt 0 ]; then
        log "⚠️  [karo] アイドル状態 + 未処理報告あり ($report_count件) - 起床"
        notify "$pane" "queue/reports/ に未処理報告がある。確認せよ。"
        return 0
      fi
    fi
  fi

  return 1
}

# 4. dashboard.md更新検知 → 将軍に報告
check_dashboard_update() {
  local dashboard="$SCRIPT_DIR/dashboard.md"
  local last_check_file="$SCRIPT_DIR/.last_dashboard_check"

  # 初回実行時
  if [ ! -f "$last_check_file" ]; then
    stat -f %m "$dashboard" > "$last_check_file" 2>/dev/null || stat -c %Y "$dashboard" > "$last_check_file"
    return 0
  fi

  # 前回チェック時のタイムスタンプ
  local last_mtime=$(cat "$last_check_file")
  # 現在のタイムスタンプ (macOS/Linux互換)
  local current_mtime=$(stat -f %m "$dashboard" 2>/dev/null || stat -c %Y "$dashboard")

  # 更新されていたら通知
  if [ "$current_mtime" -gt "$last_mtime" ]; then
    log "📊 dashboard.md 更新検知"

    # macOS通知
    if command -v osascript &> /dev/null; then
      osascript -e 'display notification "dashboard.mdが更新されました" with title "multi-agent-shogun" sound name "Glass"' 2>/dev/null
    fi

    # 将軍が稼働中でアイドルなら起こす
    if tmux has-session -t shogun 2>/dev/null; then
      local shogun_output=$(tmux capture-pane -t shogun:0.0 -p 2>/dev/null | tail -5)

      if echo "$shogun_output" | grep -qE "^❯ *$"; then
        log "  → 将軍を起床させる"
        notify "shogun:0.0" "dashboard.md が更新された。確認せよ。"
      else
        log "  → 将軍は殿と会話中（起こさない）"
      fi
    else
      log "  → 将軍は停止中"
    fi

    # タイムスタンプ更新
    echo "$current_mtime" > "$last_check_file"
    return 0
  fi

  return 1
}

# 5. 長時間thinking検知
check_long_thinking() {
  local pane=$1
  local name=$2

  local output=$(tmux capture-pane -t "$pane" -p 2>/dev/null | tail -5)

  # thinking状態が10分以上続いている場合
  if echo "$output" | grep -E "(thinking|Effecting|Boondoggling|Puzzling)" | grep -qE "[0-9]{2}m|[1-9][0-9]{2}s"; then
    log "⚠️  [$name] 長時間thinking検知（10分以上）"
    # 通知のみ（自動介入はしない）
    return 0
  fi

  return 1
}

# メインループ
log "🚀 watchdog.sh 起動 (チェック間隔: ${CHECK_INTERVAL}秒)"

while true; do
  # dashboard.md更新チェック（最優先）
  check_dashboard_update

  # Limitリセット後の自動再開チェック
  check_limit_reset

  # shogunセッション
  if tmux has-session -t shogun 2>/dev/null; then
    check_limit "shogun:0.0" "shogun" true
    check_long_thinking "shogun:0.0" "shogun"
  fi

  # multiagentセッション
  if tmux has-session -t multiagent 2>/dev/null; then
    # Pane 0: karo（ログ出力あり）
    check_limit "multiagent:0.0" "karo" true
    check_idle "multiagent:0.0" "karo"
    check_long_thinking "multiagent:0.0" "karo"

    # Pane 1: metsuke（ログ出力なし、リセット通知なし）
    check_limit "multiagent:0.1" "metsuke" false

    # Pane 2-N: ashigaru（ログ出力なし、リセット通知なし）
    for i in {2..9}; do
      if tmux list-panes -t multiagent -F '#{pane_index}' 2>/dev/null | grep -q "^$i$"; then
        check_limit "multiagent:0.$i" "ashigaru$((i-1))" false
      fi
    done
  fi

  sleep "$CHECK_INTERVAL"
done
