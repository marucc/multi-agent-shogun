#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# inbox_watcher.sh — メールボックス監視＆起動シグナル配信
# Usage: bash scripts/inbox_watcher.sh <agent_id> <pane_target> [cli_type]
# Example: bash scripts/inbox_watcher.sh karo multiagent:0.0 claude
#
# 設計思想:
#   メッセージ本体はファイル（inbox YAML）に書く = 確実
#   起動シグナルは tmux send-keys（テキストとEnterを分離送信）
#   エージェントが自分でinboxをReadして処理する
#   冪等: 2回届いてもunreadがなければ何もしない
#
# inotifywait でファイル変更を検知（イベント駆動、ポーリングではない）
# Fallback 1: 30秒タイムアウト（WSL2 inotify不発時の安全網）
# Fallback 2: rc=1処理（Claude Code atomic write = tmp+rename でinode変更時）
#
# エスカレーション（未読メッセージが放置されている場合）:
#   0〜2分: 通常nudge（send-keys）。ただしWorking中はスキップ
#   2〜4分: Escape×2 + nudge（カーソル位置バグ対策）
#   4分〜 : /clear送信（5分に1回まで。強制リセット+YAML再読）
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_ID="$1"
PANE_TARGET="$2"
CLI_TYPE="${3:-claude}"  # CLI種別（claude/codex/copilot）。未指定→claude（後方互換）

INBOX="$SCRIPT_DIR/queue/inbox/${AGENT_ID}.yaml"
LOCKFILE="${INBOX}.lock"


if [ -z "$AGENT_ID" ] || [ -z "$PANE_TARGET" ]; then
    echo "Usage: inbox_watcher.sh <agent_id> <pane_target> [cli_type]" >&2
    exit 1
fi

# Initialize inbox if not exists
if [ ! -f "$INBOX" ]; then
    mkdir -p "$(dirname "$INBOX")"
    echo "messages: []" > "$INBOX"
fi

echo "[$(date)] inbox_watcher started — agent: $AGENT_ID, pane: $PANE_TARGET, cli: $CLI_TYPE" >&2

# ─── Escalation state ───
# Time-based escalation: track how long unread messages have been waiting
FIRST_UNREAD_SEEN=0   # epoch when first unread was detected (0 = no unread)
LAST_CLEAR_TS=0       # epoch of last /clear escalation (throttle: max once per 5min)
ESCALATE_PHASE1=120   # seconds: switch to Escape+nudge (2 min)
ESCALATE_PHASE2=240   # seconds: switch to /clear (4 min)
ESCALATE_COOLDOWN=300  # seconds: min interval between /clear sends (5 min)

# Ensure inotifywait is available
if ! command -v inotifywait &>/dev/null; then
    echo "[inbox_watcher] ERROR: inotifywait not found. Install: sudo apt install inotify-tools" >&2
    exit 1
fi

# ─── Extract unread message info (lock-free read) ───
# Returns JSON lines: {"count": N, "has_special": true/false, "specials": [...]}
get_unread_info() {
    python3 -c "
import yaml, sys, json
try:
    with open('$INBOX') as f:
        data = yaml.safe_load(f)
    if not data or 'messages' not in data or not data['messages']:
        print(json.dumps({'count': 0, 'specials': []}))
        sys.exit(0)
    unread = [m for m in data['messages'] if not m.get('read', False)]
    # Special types that need direct pty write (CLI commands, not conversation)
    special_types = ('clear_command', 'model_switch')
    specials = [m for m in unread if m.get('type') in special_types]
    # Mark specials as read immediately (they'll be delivered directly)
    if specials:
        for m in data['messages']:
            if not m.get('read', False) and m.get('type') in special_types:
                m['read'] = True
        with open('$INBOX', 'w') as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
    normal_count = len(unread) - len(specials)
    print(json.dumps({
        'count': normal_count,
        'specials': [{'type': m.get('type',''), 'content': m.get('content','')} for m in specials]
    }))
except Exception as e:
    print(json.dumps({'count': 0, 'specials': []}), file=sys.stderr)
    print(json.dumps({'count': 0, 'specials': []}))
" 2>/dev/null
}

# ─── Send CLI command via pty direct write ───
# For /clear and /model only. These are CLI commands, not conversation messages.
# CLI_TYPE別分岐: claude→そのまま, codex→/clear対応・/modelスキップ,
#                  copilot→Ctrl-C+再起動・/modelスキップ
# 全CLIでpty直接書き込み。send-keys完全不使用。
send_cli_command() {
    local cmd="$1"

    # CLI別コマンド変換
    local actual_cmd="$cmd"
    case "$CLI_TYPE" in
        codex)
            # Codex: /clear不存在→/newで新規会話開始, /model非対応→スキップ
            # /clearはCodexでは未定義コマンドでCLI終了してしまうため、/newに変換
            if [[ "$cmd" == "/clear" ]]; then
                echo "[$(date)] [SEND-KEYS] Codex /clear→/new: starting new conversation for $AGENT_ID" >&2
                timeout 5 tmux send-keys -t "$PANE_TARGET" "/new" 2>/dev/null
                sleep 0.3
                timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null
                sleep 3
                return 0
            fi
            if [[ "$cmd" == /model* ]]; then
                echo "[$(date)] Skipping $cmd (not supported on codex)" >&2
                return 0
            fi
            ;;
        copilot)
            # Copilot: /clearはCtrl-C+再起動, /model非対応→スキップ
            if [[ "$cmd" == "/clear" ]]; then
                echo "[$(date)] [SEND-KEYS] Copilot /clear: sending Ctrl-C + restart for $AGENT_ID" >&2
                timeout 5 tmux send-keys -t "$PANE_TARGET" C-c 2>/dev/null
                sleep 2
                timeout 5 tmux send-keys -t "$PANE_TARGET" "copilot --yolo" 2>/dev/null
                sleep 0.3
                timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null
                sleep 3
                return 0
            fi
            if [[ "$cmd" == /model* ]]; then
                echo "[$(date)] Skipping $cmd (not supported on copilot)" >&2
                return 0
            fi
            ;;
        # claude: commands pass through as-is
    esac

    echo "[$(date)] [SEND-KEYS] Sending CLI command to $AGENT_ID ($CLI_TYPE): $actual_cmd" >&2
    # Clear stale input first, then send command (text and Enter separated for Codex TUI)
    timeout 5 tmux send-keys -t "$PANE_TARGET" C-c 2>/dev/null
    sleep 0.5
    timeout 5 tmux send-keys -t "$PANE_TARGET" "$actual_cmd" 2>/dev/null
    sleep 0.3
    timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null

    # /clear needs extra wait time before follow-up
    if [[ "$actual_cmd" == "/clear" ]]; then
        sleep 3
    else
        sleep 1
    fi
}

# ─── Agent self-watch detection ───
# Check if the agent has an active inotifywait on its inbox.
# If yes, the agent will self-wake — no nudge needed.
agent_has_self_watch() {
    pgrep -f "inotifywait.*inbox/${AGENT_ID}.yaml" >/dev/null 2>&1
}

# ─── Agent busy detection ───
# Check if the agent's CLI is currently processing (Working/thinking/etc).
# Sending nudge during Working causes text to queue but Enter to be lost.
# Returns 0 (true) if agent is busy, 1 if idle.
agent_is_busy() {
    local pane_content
    pane_content=$(timeout 2 tmux capture-pane -t "$PANE_TARGET" -p 2>/dev/null | tail -15)
    # Codex CLI: "Working", "Thinking", "Planning", "Sending"
    # Claude CLI: thinking spinner, tool execution
    if echo "$pane_content" | grep -qiE '(Working|Thinking|Planning|Sending|esc to interrupt)'; then
        return 0  # busy
    fi
    return 1  # idle
}

# ─── Send wake-up nudge ───
# Layered approach:
#   1. If agent has active inotifywait self-watch → skip (agent wakes itself)
#   2. If agent is busy (Working) → skip (nudge during Working loses Enter)
#   3. tmux send-keys (短いnudgeのみ、timeout 5s)
send_wakeup() {
    local unread_count="$1"
    local nudge="inbox${unread_count}"

    # 優先度1: Agent self-watch — nudge不要（エージェントが自分で気づく）
    if agent_has_self_watch; then
        echo "[$(date)] [SKIP] Agent $AGENT_ID has active self-watch, no nudge needed" >&2
        return 0
    fi

    # 優先度2: Agent busy — nudge送信するとEnterが消失するためスキップ
    if agent_is_busy; then
        echo "[$(date)] [SKIP] Agent $AGENT_ID is busy (Working), deferring nudge" >&2
        return 0
    fi

    # 優先度3: tmux send-keys（テキストとEnterを分離 — Codex TUI対策）
    echo "[$(date)] [SEND-KEYS] Sending nudge to $PANE_TARGET for $AGENT_ID" >&2
    if timeout 5 tmux send-keys -t "$PANE_TARGET" "$nudge" 2>/dev/null; then
        sleep 0.3
        timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null
        echo "[$(date)] Wake-up sent to $AGENT_ID (${unread_count} unread)" >&2
        return 0
    fi

    echo "[$(date)] WARNING: send-keys failed or timed out for $AGENT_ID" >&2
    return 1
}

# ─── Send wake-up nudge with Escape prefix ───
# Phase 2 escalation: send Escape×2 + C-c to clear stuck input, then nudge.
# Addresses the "echo last tool call" cursor position bug and stale input.
send_wakeup_with_escape() {
    local unread_count="$1"
    local nudge="inbox${unread_count}"

    if agent_has_self_watch; then
        return 0
    fi

    # Phase 2 still skips if agent is busy — Escape during Working would interrupt
    if agent_is_busy; then
        echo "[$(date)] [SKIP] Agent $AGENT_ID is busy (Working), deferring Phase 2 nudge" >&2
        return 0
    fi

    echo "[$(date)] [SEND-KEYS] ESCALATION Phase 2: Escape×2 + C-c + nudge for $AGENT_ID" >&2
    # Escape×2 to exit any mode, C-c to clear stale input
    timeout 5 tmux send-keys -t "$PANE_TARGET" Escape Escape 2>/dev/null
    sleep 0.5
    timeout 5 tmux send-keys -t "$PANE_TARGET" C-c 2>/dev/null
    sleep 0.5
    if timeout 5 tmux send-keys -t "$PANE_TARGET" "$nudge" 2>/dev/null; then
        sleep 0.3
        timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null
        echo "[$(date)] Escape+nudge sent to $AGENT_ID (${unread_count} unread)" >&2
        return 0
    fi

    echo "[$(date)] WARNING: send-keys failed for Escape+nudge ($AGENT_ID)" >&2
    return 1
}

# ─── Process cycle ───
process_unread() {
    local info
    info=$(get_unread_info)

    # Handle special CLI commands first (/clear, /model)
    local specials
    specials=$(echo "$info" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for s in data.get('specials', []):
    if s['type'] == 'clear_command':
        print('/clear')
        print(s['content'])  # post-clear instruction
    elif s['type'] == 'model_switch':
        print(s['content'])  # /model command
" 2>/dev/null)

    if [ -n "$specials" ]; then
        echo "$specials" | while IFS= read -r cmd; do
            [ -n "$cmd" ] && send_cli_command "$cmd"
        done
    fi

    # Send wake-up nudge for normal messages (with escalation)
    local normal_count
    normal_count=$(echo "$info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))" 2>/dev/null)

    if [ "$normal_count" -gt 0 ] 2>/dev/null; then
        local now
        now=$(date +%s)

        # Track when we first saw unread messages
        if [ "$FIRST_UNREAD_SEEN" -eq 0 ]; then
            FIRST_UNREAD_SEEN=$now
        fi

        local age=$((now - FIRST_UNREAD_SEEN))

        if [ "$age" -lt "$ESCALATE_PHASE1" ]; then
            # Phase 1 (0-2 min): Standard nudge
            echo "[$(date)] $normal_count unread for $AGENT_ID (${age}s)" >&2
            send_wakeup "$normal_count"
        elif [ "$age" -lt "$ESCALATE_PHASE2" ]; then
            # Phase 2 (2-4 min): Escape + nudge
            echo "[$(date)] $normal_count unread for $AGENT_ID (${age}s — escalating: Escape+nudge)" >&2
            send_wakeup_with_escape "$normal_count"
        else
            # Phase 3 (4+ min): /clear (throttled to once per 5 min)
            if [ "$LAST_CLEAR_TS" -lt "$((now - ESCALATE_COOLDOWN))" ]; then
                echo "[$(date)] ESCALATION Phase 3: Agent $AGENT_ID unresponsive for ${age}s. Sending /clear." >&2
                send_cli_command "/clear"
                LAST_CLEAR_TS=$now
                FIRST_UNREAD_SEEN=0  # Reset — will re-detect on next cycle
            else
                # Cooldown active — fall back to Escape+nudge
                echo "[$(date)] $normal_count unread for $AGENT_ID (${age}s — /clear cooldown, using Escape+nudge)" >&2
                send_wakeup_with_escape "$normal_count"
            fi
        fi
    else
        # No unread messages — reset escalation tracker
        if [ "$FIRST_UNREAD_SEEN" -ne 0 ]; then
            echo "[$(date)] All messages read for $AGENT_ID — escalation reset" >&2
        fi
        FIRST_UNREAD_SEEN=0
        # Clear stale nudge text from input field (Codex CLI prefills last input on idle).
        # Only send C-u when agent is idle — during Working it would be disruptive.
        if ! agent_is_busy; then
            timeout 2 tmux send-keys -t "$PANE_TARGET" C-u 2>/dev/null
        fi
    fi
}

# ─── Startup: process any existing unread messages ───
process_unread

# ─── Main loop: event-driven via inotifywait ───
# Timeout 30s: WSL2 /mnt/c/ can miss inotify events.
# Shorter timeout = faster escalation retry for stuck agents.
INOTIFY_TIMEOUT=30

while true; do
    # Block until file is modified OR timeout (safety net for WSL2)
    # set +e: inotifywait returns 2 on timeout, which would kill script under set -e
    set +e
    inotifywait -q -t "$INOTIFY_TIMEOUT" -e modify -e close_write "$INBOX" 2>/dev/null
    rc=$?
    set -e

    # rc=0: event fired (instant delivery)
    # rc=1: watch invalidated — Claude Code uses atomic write (tmp+rename),
    #        which replaces the inode. inotifywait sees DELETE_SELF → rc=1.
    #        File still exists with new inode. Treat as event, re-watch next loop.
    # rc=2: timeout (30s safety net for WSL2 inotify gaps)
    # All cases: check for unread, then loop back to inotifywait (re-watches new inode)
    sleep 0.3

    process_unread
done
