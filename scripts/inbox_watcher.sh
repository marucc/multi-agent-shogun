#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# inbox_watcher.sh — メールボックス監視＆起動シグナル配信
# Usage: bash scripts/inbox_watcher.sh <agent_id> <pane_target>
# Example: bash scripts/inbox_watcher.sh karo multiagent:0.0
#
# 設計思想:
#   メッセージ本体はファイル（inbox YAML）に書く = 確実
#   send-keys は短い起動シグナルのみ = ハング防止
#   エージェントが自分でinboxをReadして処理する
#   冪等: 2回届いてもunreadがなければ何もしない
#
# inotifywait でファイル変更を検知（イベント駆動、ポーリングではない）
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_ID="$1"
PANE_TARGET="$2"

INBOX="$SCRIPT_DIR/queue/inbox/${AGENT_ID}.yaml"
LOCKFILE="${INBOX}.lock"
SEND_KEYS_TIMEOUT=5  # seconds — prevents hang (PID 274337 incident)

if [ -z "$AGENT_ID" ] || [ -z "$PANE_TARGET" ]; then
    echo "Usage: inbox_watcher.sh <agent_id> <pane_target>" >&2
    exit 1
fi

# Initialize inbox if not exists
if [ ! -f "$INBOX" ]; then
    mkdir -p "$(dirname "$INBOX")"
    echo "messages: []" > "$INBOX"
fi

echo "[$(date)] inbox_watcher started — agent: $AGENT_ID, pane: $PANE_TARGET" >&2

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
    # Special types that need direct send-keys (CLI commands, not conversation)
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

# ─── Send CLI command directly via send-keys ───
# For /clear and /model only. These are CLI commands, not conversation messages.
send_cli_command() {
    local cmd="$1"
    echo "[$(date)] Sending CLI command to $AGENT_ID: $cmd" >&2

    if ! timeout "$SEND_KEYS_TIMEOUT" tmux send-keys -t "$PANE_TARGET" "$cmd" 2>/dev/null; then
        echo "[$(date)] WARNING: send-keys timed out for CLI command" >&2
        return 1
    fi
    sleep 0.3
    if ! timeout "$SEND_KEYS_TIMEOUT" tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null; then
        echo "[$(date)] WARNING: send-keys Enter timed out for CLI command" >&2
        return 1
    fi

    # /clear needs extra wait time before follow-up
    if [[ "$cmd" == "/clear" ]]; then
        sleep 3
    else
        sleep 1
    fi
}

# ─── Send wake-up nudge via send-keys ───
# ONLY sends a short nudge. Never sends message content.
# timeout prevents the 1.5-hour hang incident from recurring.
send_wakeup() {
    local unread_count="$1"
    local nudge="新着${unread_count}件。queue/inbox/${AGENT_ID}.yaml をReadして未読(read: false)を全て処理せよ。処理後 read: true に更新。"

    if ! timeout "$SEND_KEYS_TIMEOUT" tmux send-keys -t "$PANE_TARGET" "$nudge" 2>/dev/null; then
        echo "[$(date)] WARNING: send-keys nudge timed out ($SEND_KEYS_TIMEOUT s)" >&2
        return 1
    fi
    sleep 0.3
    if ! timeout "$SEND_KEYS_TIMEOUT" tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null; then
        echo "[$(date)] WARNING: send-keys Enter timed out ($SEND_KEYS_TIMEOUT s)" >&2
        return 1
    fi

    echo "[$(date)] Wake-up sent to $AGENT_ID (${unread_count} unread)" >&2
    return 0
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

    # Send wake-up nudge for normal messages
    local normal_count
    normal_count=$(echo "$info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))" 2>/dev/null)

    if [ "$normal_count" -gt 0 ] 2>/dev/null; then
        echo "[$(date)] $normal_count normal unread message(s) for $AGENT_ID" >&2
        send_wakeup "$normal_count"
    fi
}

# ─── Startup: process any existing unread messages ───
process_unread

# ─── Main loop: event-driven via inotifywait ───
while true; do
    # Block until file is modified (event-driven, NOT polling)
    if ! inotifywait -q -e modify -e close_write "$INBOX" 2>/dev/null; then
        echo "[$(date)] inotifywait error, restarting in 5s..." >&2
        sleep 5
        continue
    fi

    # Debounce: wait for burst writes to settle
    sleep 0.5

    # Send wake-up if there are unread messages
    process_unread
done
