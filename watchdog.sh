#!/bin/bash
# watchdog.sh - multi-agent-shogun 監視スクリプト
# 使い方: ./watchdog.sh [--project-dir=/path/to/project]
#         ./watchdog.sh &
#
# 機能:
#   - 全JOBのLimit検知（ログは1件のみ）、リセット後は将軍・家老に自動通知
#   - dashboard.md更新検知 → 将軍に通知
#   - 家老のアイドル検知（未処理報告がある場合）

SHOGUN_ROOT="$(cd "$(dirname "$0")" && pwd)"

# WORK_DIR 発見ロジック
PROJECT_DIR=""
for arg in "$@"; do
    case $arg in
        --project-dir=*) PROJECT_DIR="${arg#*=}" ;;
    esac
done

if [ -n "$PROJECT_DIR" ] && [ -d "${PROJECT_DIR}/.shogun" ]; then
    WORK_DIR="$PROJECT_DIR"
elif [ -d "$(pwd)/.shogun" ]; then
    WORK_DIR="$(pwd)"
else
    WORK_DIR="$SHOGUN_ROOT"
fi

# プロジェクト共通変数を読み込み
source "${SHOGUN_ROOT}/scripts/project-env.sh"

LOG_FILE="${LOGS_DIR}/watchdog.log"
CHECK_INTERVAL=300  # 5分ごとにチェック
LIMIT_RESET_FILE="${SHOGUN_DATA_DIR}/.limit_reset_times"
PID_FILE="${SHOGUN_DATA_DIR}/watchdog.pid"
LAST_DASHBOARD_CHECK_FILE="${SHOGUN_DATA_DIR}/.last_dashboard_check"

# ログディレクトリ作成
mkdir -p "${LOGS_DIR}"

# PID を保存
echo $$ > "$PID_FILE"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

notify() {
  local pane=$1
  local message=$2
  "$SHOGUN_ROOT/scripts/notify.sh" "$pane" "$message"
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

# 1. Limit検知（全JOB対象で記録、ログは別途まとめて出力）
# 戻り値: 0=Limit検知, 1=検知なし
check_limit() {
  local pane=$1
  local name=$2

  local output=$(tmux capture-pane -t "$pane" -p 2>/dev/null | tail -20)

  # Limit検知（リセット時刻付き）
  # 例: "resets 1pm (Asia/Tokyo)" or "resets 2:30pm"
  if echo "$output" | grep -qE "You've used [0-9]+% of your session limit|resets [0-9]+"; then
    local reset_time=$(echo "$output" | grep -oE "resets [0-9]+:?[0-9]*[ap]m" | tail -1 | sed 's/resets //')

    if [ -n "$reset_time" ]; then
      # 既に記録済みでなければ記録（全JOB対象）
      if ! grep -q "^$name:$reset_time:" "$LIMIT_RESET_FILE" 2>/dev/null; then
        local reset_ts=$(parse_reset_time_to_timestamp "$reset_time")
        echo "$name:$reset_time:$reset_ts:$(date +%s)" >> "$LIMIT_RESET_FILE"
        return 0  # 新規記録あり
      fi
    fi
    return 2  # 既に記録済み
  fi

  # Limit完全停止検知
  if echo "$output" | grep -qE "You've hit your limit|Stop and wait for limit to reset"; then
    return 0
  fi

  return 1
}

# 2. Limitリセット後の自動再開（全JOBの記録を見て、将軍・家老に通知）
check_limit_reset() {
  [ ! -f "$LIMIT_RESET_FILE" ] && return 1
  [ ! -s "$LIMIT_RESET_FILE" ] && return 1  # 空ファイルもスキップ

  local now=$(date +%s)
  local should_notify=false
  local reset_info=""

  while IFS= read -r line; do
    [ -z "$line" ] && continue

    local name=$(echo "$line" | cut -d: -f1)
    local reset_time=$(echo "$line" | cut -d: -f2)
    local reset_ts=$(echo "$line" | cut -d: -f3)
    local recorded_ts=$(echo "$line" | cut -d: -f4)

    # リセット時刻を過ぎたか確認（UNIXタイムスタンプで比較）
    if [ "$now" -ge "$reset_ts" ]; then
      # 記録から6時間以内なら通知対象
      local age=$((now - recorded_ts))
      if [ "$age" -lt 21600 ]; then  # 6時間以内の記録
        should_notify=true
        reset_info="$reset_time"
        break  # 1つ見つかれば十分
      fi
    fi
  done < "$LIMIT_RESET_FILE"

  # リセット時刻を過ぎていたら将軍・家老に通知
  if [ "$should_notify" = true ]; then
    log "✅ Limitリセット時刻($reset_info)を過ぎた - 将軍・家老に再開指示"

    # 家老に通知（先に通知）
    if tmux has-session -t "${TMUX_MULTIAGENT}" 2>/dev/null; then
      tmux send-keys -t "${TMUX_MULTIAGENT}:0.0" "" Enter
      sleep 1
      notify "${TMUX_MULTIAGENT}:0.0" "Limitがリセットされた。作業再開せよ。目付や各足軽にも再開指示をせよ。"
    fi

    # 将軍に通知
    if tmux has-session -t "${TMUX_SHOGUN}" 2>/dev/null; then
      sleep 1
      tmux send-keys -t "${TMUX_SHOGUN}:0.0" "" Enter
      sleep 1
      notify "${TMUX_SHOGUN}:0.0" "Limitがリセットされた。家老にも指示したので家老が動いていなかったら追加指示をすること。"
    fi

    # 記録ファイルをクリア
    : > "$LIMIT_RESET_FILE"
  fi

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
      local report_count=$(find "$SHOGUN_ROOT/queue/reports" -name "*.yaml" -mmin -10 -type f 2>/dev/null | wc -l | tr -d ' ')

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
  local dashboard="${DASHBOARD_PATH}"

  [ ! -f "$dashboard" ] && return 0

  # 初回実行時
  if [ ! -f "$LAST_DASHBOARD_CHECK_FILE" ]; then
    stat -f %m "$dashboard" > "$LAST_DASHBOARD_CHECK_FILE" 2>/dev/null || stat -c %Y "$dashboard" > "$LAST_DASHBOARD_CHECK_FILE"
    return 0
  fi

  # 前回チェック時のタイムスタンプ
  local last_mtime=$(cat "$LAST_DASHBOARD_CHECK_FILE")
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
    if tmux has-session -t "${TMUX_SHOGUN}" 2>/dev/null; then
      local shogun_output=$(tmux capture-pane -t "${TMUX_SHOGUN}:0.0" -p 2>/dev/null | tail -5)

      if echo "$shogun_output" | grep -qE "^❯ *$"; then
        log "  → 将軍を起床させる"
        notify "${TMUX_SHOGUN}:0.0" "dashboard.md が更新された。確認せよ。"
      else
        log "  → 将軍は殿と会話中（起こさない）"
      fi
    else
      log "  → 将軍は停止中"
    fi

    # タイムスタンプ更新
    echo "$current_mtime" > "$LAST_DASHBOARD_CHECK_FILE"
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
log "🚀 watchdog.sh 起動 (プロジェクト: ${PROJECT_NAME_SAFE}, チェック間隔: ${CHECK_INTERVAL}秒)"

while true; do
  # dashboard.md更新チェック（最優先）
  check_dashboard_update

  # Limit検知フラグ（新規記録があれば1件だけログ出力）
  limit_detected=false

  # shogunセッション
  if tmux has-session -t "${TMUX_SHOGUN}" 2>/dev/null; then
    check_limit "${TMUX_SHOGUN}:0.0" "shogun"
    [ $? -eq 0 ] && limit_detected=true
    check_long_thinking "${TMUX_SHOGUN}:0.0" "shogun"
  fi

  # multiagentセッション
  if tmux has-session -t "${TMUX_MULTIAGENT}" 2>/dev/null; then
    # Pane 0: karo
    check_limit "${TMUX_MULTIAGENT}:0.0" "karo"
    [ $? -eq 0 ] && limit_detected=true
    check_idle "${TMUX_MULTIAGENT}:0.0" "karo"
    check_long_thinking "${TMUX_MULTIAGENT}:0.0" "karo"

    # Pane 1: metsuke
    check_limit "${TMUX_MULTIAGENT}:0.1" "metsuke"
    [ $? -eq 0 ] && limit_detected=true

    # Pane 2-N: ashigaru
    for i in {2..9}; do
      if tmux list-panes -t "${TMUX_MULTIAGENT}" -F '#{pane_index}' 2>/dev/null | grep -q "^$i$"; then
        check_limit "${TMUX_MULTIAGENT}:0.$i" "ashigaru$((i-1))"
        [ $? -eq 0 ] && limit_detected=true
      fi
    done
  fi

  # Limit検知があれば1件だけログ出力
  if [ "$limit_detected" = true ]; then
    log "🚨 Limit検知"
  fi

  # Limitリセット後の自動再開チェック（検知・記録の後に実行）
  check_limit_reset

  sleep "$CHECK_INTERVAL"
done
