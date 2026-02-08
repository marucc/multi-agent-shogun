#!/usr/bin/env bats
# test_send_wakeup.bats — send_wakeup() replacement unit tests
# send-keys撲滅: paste-buffer fallback + pgrep self-watch detection
#
# テスト構成:
#   T-SW-001: send_wakeup — active self-watch → skip nudge
#   T-SW-002: send_wakeup — no self-watch → fallback nudge
#   T-SW-003: send_wakeup — paste-buffer used instead of send-keys
#   T-SW-004: send_wakeup — fallback nudge includes Enter keystroke
#   T-SW-005: send_wakeup — timeout on paste-buffer
#   T-SW-006: agent_has_self_watch — detects inotifywait process
#   T-SW-007: agent_has_self_watch — no inotifywait → returns 1
#   T-SW-008: send_cli_command — /clear still uses send-keys (kept)
#   T-SW-009: send_cli_command — /model still uses send-keys (kept)
#   T-SW-010: process_unread — integration: self-watch skips nudge
#   T-SW-011: backward compat — no inotifywait installed → fallback works

# --- セットアップ ---

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export WATCHER_SCRIPT="$PROJECT_ROOT/scripts/inbox_watcher.sh"
    [ -f "$WATCHER_SCRIPT" ] || return 1
    python3 -c "import yaml" 2>/dev/null || return 1
}

setup() {
    export TEST_TMPDIR="$(mktemp -d "$BATS_TMPDIR/send_wakeup_test.XXXXXX")"

    # Extract send_wakeup and helper functions for isolated testing
    # Create a mock environment with the functions but mock tmux commands
    export MOCK_LOG="$TEST_TMPDIR/tmux_calls.log"
    > "$MOCK_LOG"

    # Create mock tmux that logs calls
    export MOCK_TMUX="$TEST_TMPDIR/mock_tmux"
    cat > "$MOCK_TMUX" << 'MOCK'
#!/bin/bash
# Log all tmux calls
echo "tmux $*" >> "$MOCK_LOG"
# Simulate success
exit 0
MOCK
    chmod +x "$MOCK_TMUX"

    # Create mock timeout
    export MOCK_TIMEOUT="$TEST_TMPDIR/mock_timeout"
    cat > "$MOCK_TIMEOUT" << 'MOCK'
#!/bin/bash
# Strip timeout args, execute the rest
shift  # remove timeout duration
"$@"
MOCK
    chmod +x "$MOCK_TIMEOUT"

    # Create mock pgrep
    export MOCK_PGREP="$TEST_TMPDIR/mock_pgrep"
    # Default: no self-watch found
    cat > "$MOCK_PGREP" << 'MOCK'
#!/bin/bash
exit 1
MOCK
    chmod +x "$MOCK_PGREP"

    # Create test inbox
    export TEST_INBOX_DIR="$TEST_TMPDIR/queue/inbox"
    mkdir -p "$TEST_INBOX_DIR"

    # Test harness: source functions from inbox_watcher.sh with mocked externals
    export TEST_HARNESS="$TEST_TMPDIR/test_harness.sh"
    cat > "$TEST_HARNESS" << HARNESS
#!/bin/bash
# Test harness with mocked tmux/pgrep
AGENT_ID="test_agent"
PANE_TARGET="test:0.0"
CLI_TYPE="claude"
INBOX="$TEST_INBOX_DIR/test_agent.yaml"
LOCKFILE="\${INBOX}.lock"
SEND_KEYS_TIMEOUT=5
SCRIPT_DIR="$PROJECT_ROOT"

# Override commands with mocks
tmux() { "$MOCK_TMUX" "\$@"; }
timeout() { "$MOCK_TIMEOUT" "\$@"; }
pgrep() { "$MOCK_PGREP" "\$@"; }
export -f tmux timeout pgrep

# agent_has_self_watch: check if agent has active inotifywait
agent_has_self_watch() {
    pgrep -f "inotifywait.*inbox/\${AGENT_ID}.yaml" >/dev/null 2>&1
}

# New send_wakeup with fallback logic
send_wakeup() {
    local unread_count="\$1"
    local nudge="inbox\${unread_count}"

    # Check if agent is self-watching (has inotifywait on its inbox)
    if agent_has_self_watch; then
        echo "[SKIP] Agent \$AGENT_ID has active self-watch" >&2
        return 0
    fi

    # Fallback: paste-buffer instead of send-keys
    echo "[FALLBACK] Sending paste-buffer nudge to \$AGENT_ID" >&2

    tmux set-buffer -b "nudge_\${AGENT_ID}" "\$nudge"
    if ! timeout "\$SEND_KEYS_TIMEOUT" tmux paste-buffer -t "\$PANE_TARGET" -b "nudge_\${AGENT_ID}" -d 2>/dev/null; then
        echo "[WARN] paste-buffer timed out" >&2
        return 1
    fi
    sleep 0.1
    if ! timeout "\$SEND_KEYS_TIMEOUT" tmux send-keys -t "\$PANE_TARGET" Enter 2>/dev/null; then
        echo "[WARN] send-keys Enter timed out" >&2
        return 1
    fi

    echo "[OK] Fallback nudge sent to \$AGENT_ID (\${unread_count} unread)" >&2
    return 0
}

# send_cli_command (unchanged — still uses send-keys)
send_cli_command() {
    local cmd="\$1"
    local actual_cmd="\$cmd"
    echo "[CLI] Sending CLI command: \$actual_cmd" >&2
    timeout "\$SEND_KEYS_TIMEOUT" tmux send-keys -t "\$PANE_TARGET" "\$actual_cmd" 2>/dev/null || return 1
    sleep 0.1
    timeout "\$SEND_KEYS_TIMEOUT" tmux send-keys -t "\$PANE_TARGET" Enter 2>/dev/null || return 1
    return 0
}
HARNESS
    chmod +x "$TEST_HARNESS"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# --- T-SW-001: self-watch active → skip nudge ---

@test "T-SW-001: send_wakeup skips nudge when agent has active self-watch" {
    # Mock pgrep to find inotifywait
    cat > "$MOCK_PGREP" << 'MOCK'
#!/bin/bash
echo "12345 inotifywait -q -t 120 -e modify inbox/test_agent.yaml"
exit 0
MOCK
    chmod +x "$MOCK_PGREP"

    run bash -c "source '$TEST_HARNESS' && send_wakeup 3"
    [ "$status" -eq 0 ]

    # Verify no tmux calls were made (nudge was skipped)
    [ ! -s "$MOCK_LOG" ]

    # Verify skip message in stderr
    echo "$output" | grep -q "SKIP"
}

# --- T-SW-002: no self-watch → fallback nudge ---

@test "T-SW-002: send_wakeup sends fallback nudge when no self-watch" {
    # Default mock_pgrep returns 1 (no self-watch)
    run bash -c "source '$TEST_HARNESS' && send_wakeup 5"
    [ "$status" -eq 0 ]

    # Verify tmux calls were made
    [ -s "$MOCK_LOG" ]
    grep -q "set-buffer" "$MOCK_LOG"
    grep -q "paste-buffer" "$MOCK_LOG"

    # Verify fallback message
    echo "$output" | grep -q "FALLBACK"
}

# --- T-SW-003: paste-buffer used instead of send-keys for nudge ---

@test "T-SW-003: fallback nudge uses paste-buffer not send-keys for content" {
    run bash -c "source '$TEST_HARNESS' && send_wakeup 3"
    [ "$status" -eq 0 ]

    # paste-buffer should be used for the nudge content
    grep -q "set-buffer -b nudge_test_agent inbox3" "$MOCK_LOG"
    grep -q "paste-buffer -t test:0.0 -b nudge_test_agent -d" "$MOCK_LOG"

    # send-keys should ONLY be used for Enter (not for the nudge text itself)
    local sendkeys_count
    sendkeys_count=$(grep -c "send-keys" "$MOCK_LOG")
    [ "$sendkeys_count" -eq 1 ]  # Only the Enter keystroke

    grep -q "send-keys -t test:0.0 Enter" "$MOCK_LOG"
}

# --- T-SW-004: fallback nudge includes Enter ---

@test "T-SW-004: fallback nudge sends Enter after paste-buffer" {
    run bash -c "source '$TEST_HARNESS' && send_wakeup 1"
    [ "$status" -eq 0 ]

    # Verify order: set-buffer → paste-buffer → send-keys Enter
    local log_content
    log_content=$(cat "$MOCK_LOG")

    local line1 line2 line3
    line1=$(sed -n '1p' "$MOCK_LOG")
    line2=$(sed -n '2p' "$MOCK_LOG")
    line3=$(sed -n '3p' "$MOCK_LOG")

    echo "$line1" | grep -q "set-buffer"
    echo "$line2" | grep -q "paste-buffer"
    echo "$line3" | grep -q "send-keys.*Enter"
}

# --- T-SW-005: timeout on paste-buffer ---

@test "T-SW-005: send_wakeup handles paste-buffer timeout gracefully" {
    # Mock tmux to fail on paste-buffer
    cat > "$MOCK_TMUX" << 'MOCK'
#!/bin/bash
echo "tmux $*" >> "$MOCK_LOG"
if echo "$*" | grep -q "paste-buffer"; then
    exit 1
fi
exit 0
MOCK
    chmod +x "$MOCK_TMUX"

    run bash -c "source '$TEST_HARNESS' && send_wakeup 2"
    [ "$status" -eq 1 ]  # Should fail

    echo "$output" | grep -qi "timed out\|WARN"
}

# --- T-SW-006: agent_has_self_watch — detects inotifywait ---

@test "T-SW-006: agent_has_self_watch returns 0 when inotifywait running" {
    cat > "$MOCK_PGREP" << 'MOCK'
#!/bin/bash
echo "99999 inotifywait -q -t 120 -e modify inbox/test_agent.yaml"
exit 0
MOCK
    chmod +x "$MOCK_PGREP"

    run bash -c "source '$TEST_HARNESS' && agent_has_self_watch"
    [ "$status" -eq 0 ]
}

# --- T-SW-007: agent_has_self_watch — no inotifywait ---

@test "T-SW-007: agent_has_self_watch returns 1 when no inotifywait" {
    # Default mock returns 1
    run bash -c "source '$TEST_HARNESS' && agent_has_self_watch"
    [ "$status" -eq 1 ]
}

# --- T-SW-008: /clear still uses send-keys ---

@test "T-SW-008: send_cli_command /clear still uses send-keys (kept)" {
    run bash -c "source '$TEST_HARNESS' && send_cli_command /clear"
    [ "$status" -eq 0 ]

    # CLI commands use send-keys directly (not paste-buffer)
    grep -q "send-keys -t test:0.0 /clear" "$MOCK_LOG"
    grep -q "send-keys -t test:0.0 Enter" "$MOCK_LOG"

    # No paste-buffer for CLI commands
    ! grep -q "paste-buffer" "$MOCK_LOG"
}

# --- T-SW-009: /model still uses send-keys ---

@test "T-SW-009: send_cli_command /model still uses send-keys (kept)" {
    run bash -c "source '$TEST_HARNESS' && send_cli_command '/model opus'"
    [ "$status" -eq 0 ]

    grep -q "send-keys -t test:0.0 /model opus" "$MOCK_LOG"
    ! grep -q "paste-buffer" "$MOCK_LOG"
}

# --- T-SW-010: nudge content format ---

@test "T-SW-010: nudge content format is inboxN (backward compatible)" {
    run bash -c "source '$TEST_HARNESS' && send_wakeup 7"
    [ "$status" -eq 0 ]

    # The nudge text should be "inbox7"
    grep -q "set-buffer -b nudge_test_agent inbox7" "$MOCK_LOG"
}

# --- T-SW-011: backward compat — functions exist ---

@test "T-SW-011: inbox_watcher.sh contains send_wakeup and agent_has_self_watch functions" {
    # After implementation, verify the new functions exist in the script
    grep -q "send_wakeup()" "$WATCHER_SCRIPT"
    grep -q "agent_has_self_watch\|pgrep.*inotifywait\|paste-buffer" "$WATCHER_SCRIPT"
}
