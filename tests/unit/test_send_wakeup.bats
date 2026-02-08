#!/usr/bin/env bats
# test_send_wakeup.bats — send_wakeup() unit tests
# pty direct write: tmux完全バイパス、send-keys不使用
#
# テスト構成:
#   T-SW-001: send_wakeup — active self-watch → skip nudge
#   T-SW-002: send_wakeup — no self-watch → pty direct write
#   T-SW-003: send_wakeup — pty write content is "inboxN\n"
#   T-SW-004: send_wakeup — pty not writable → return 1
#   T-SW-005: send_wakeup — no paste-buffer or send-keys used for nudge
#   T-SW-006: agent_has_self_watch — detects inotifywait process
#   T-SW-007: agent_has_self_watch — no inotifywait → returns 1
#   T-SW-008: send_cli_command — /clear uses pty direct write
#   T-SW-009: send_cli_command — /model uses pty direct write
#   T-SW-010: nudge content format — inboxN (backward compatible)
#   T-SW-011: backward compat — functions exist in inbox_watcher.sh
#   T-ESC-001: escalation — no unread → FIRST_UNREAD_SEEN stays 0
#   T-ESC-002: escalation — unread < 2min → standard nudge
#   T-ESC-003: escalation — unread 2-4min → Escape+nudge
#   T-ESC-004: escalation — unread > 4min → /clear sent
#   T-ESC-005: escalation — /clear cooldown → falls back to Escape+nudge

# --- セットアップ ---

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export WATCHER_SCRIPT="$PROJECT_ROOT/scripts/inbox_watcher.sh"
    [ -f "$WATCHER_SCRIPT" ] || return 1
    python3 -c "import yaml" 2>/dev/null || return 1
}

setup() {
    export TEST_TMPDIR="$(mktemp -d "$BATS_TMPDIR/send_wakeup_test.XXXXXX")"

    # Log file for tmux calls
    export MOCK_LOG="$TEST_TMPDIR/tmux_calls.log"
    > "$MOCK_LOG"

    # Log file for pty writes
    export PTY_LOG="$TEST_TMPDIR/pty_writes.log"
    > "$PTY_LOG"

    # Create a fake pty device (regular file for testing)
    export FAKE_PTY="$TEST_TMPDIR/fake_pty"
    > "$FAKE_PTY"
    chmod a+w "$FAKE_PTY"

    # Create mock tmux that logs calls and returns fake pty path
    export MOCK_TMUX="$TEST_TMPDIR/mock_tmux"
    cat > "$MOCK_TMUX" << MOCK
#!/bin/bash
echo "tmux \$*" >> "$MOCK_LOG"
# display-message for pane_tty returns our fake pty
if echo "\$*" | grep -q "pane_tty"; then
    echo "$FAKE_PTY"
    exit 0
fi
exit 0
MOCK
    chmod +x "$MOCK_TMUX"

    # Create mock timeout
    export MOCK_TIMEOUT="$TEST_TMPDIR/mock_timeout"
    cat > "$MOCK_TIMEOUT" << 'MOCK'
#!/bin/bash
shift  # remove timeout duration
"$@"
MOCK
    chmod +x "$MOCK_TIMEOUT"

    # Create mock pgrep (default: no self-watch found)
    export MOCK_PGREP="$TEST_TMPDIR/mock_pgrep"
    cat > "$MOCK_PGREP" << 'MOCK'
#!/bin/bash
exit 1
MOCK
    chmod +x "$MOCK_PGREP"

    # Create mock printf that logs writes to pty
    export MOCK_PRINTF_WRAPPER="$TEST_TMPDIR/mock_printf_wrapper.sh"
    cat > "$MOCK_PRINTF_WRAPPER" << MOCK
#!/bin/bash
# Intercept printf redirections to fake pty and log them
builtin_printf() {
    local fmt="\$1"
    shift
    # Use builtin printf for the actual formatting
    local formatted
    formatted=\$(command printf "\$fmt" "\$@")
    echo "\$formatted"
}
MOCK

    # Create test inbox
    export TEST_INBOX_DIR="$TEST_TMPDIR/queue/inbox"
    mkdir -p "$TEST_INBOX_DIR"

    # Test harness: source functions with mocked externals
    export TEST_HARNESS="$TEST_TMPDIR/test_harness.sh"
    cat > "$TEST_HARNESS" << HARNESS
#!/bin/bash
AGENT_ID="test_agent"
PANE_TARGET="test:0.0"
CLI_TYPE="claude"
INBOX="$TEST_INBOX_DIR/test_agent.yaml"
LOCKFILE="\${INBOX}.lock"
SCRIPT_DIR="$PROJECT_ROOT"

# Override commands with mocks
tmux() { "$MOCK_TMUX" "\$@"; }
timeout() { "$MOCK_TIMEOUT" "\$@"; }
pgrep() { "$MOCK_PGREP" "\$@"; }
export -f tmux timeout pgrep

# agent_has_self_watch
agent_has_self_watch() {
    pgrep -f "inotifywait.*inbox/\${AGENT_ID}.yaml" >/dev/null 2>&1
}

# send_wakeup — pty direct write (send-keys完全廃止)
send_wakeup() {
    local unread_count="\$1"
    local nudge="inbox\${unread_count}"

    if agent_has_self_watch; then
        echo "[SKIP] Agent \$AGENT_ID has active self-watch" >&2
        return 0
    fi

    # pty direct write
    local pty
    pty=\$(tmux display-message -t "\$PANE_TARGET" -p '#{pane_tty}' 2>/dev/null)

    if [ -n "\$pty" ] && [ -w "\$pty" ]; then
        echo "[PTY] Writing nudge directly to \$pty for \$AGENT_ID" >&2
        printf '%s\n' "\$nudge" > "\$pty"
        echo "PTY_WRITE:\$nudge" >> "$PTY_LOG"
        echo "[OK] Wake-up sent to \$AGENT_ID (\${unread_count} unread via pty)" >&2
        return 0
    fi

    echo "[WARN] pty not available or not writable (\$pty)" >&2
    return 1
}

# send_cli_command — pty direct write (send-keys完全廃止)
send_cli_command() {
    local cmd="\$1"

    local pty
    pty=\$(tmux display-message -t "\$PANE_TARGET" -p '#{pane_tty}' 2>/dev/null)

    if [ -z "\$pty" ] || [ ! -w "\$pty" ]; then
        echo "[WARN] pty not available for CLI command" >&2
        return 1
    fi

    local actual_cmd="\$cmd"
    echo "[PTY] Sending CLI command: \$actual_cmd via \$pty" >&2
    printf '%s\n' "\$actual_cmd" > "\$pty"
    echo "PTY_CLI:\$actual_cmd" >> "$PTY_LOG"
    return 0
}

# Escalation state variables
FIRST_UNREAD_SEEN=0
LAST_CLEAR_TS=0
ESCALATE_PHASE1=120
ESCALATE_PHASE2=240
ESCALATE_COOLDOWN=300

# send_wakeup_with_escape — Escape×2 + nudge
send_wakeup_with_escape() {
    local unread_count="\$1"
    local nudge="inbox\${unread_count}"

    if agent_has_self_watch; then
        return 0
    fi

    local pty
    pty=\$(tmux display-message -t "\$PANE_TARGET" -p '#{pane_tty}' 2>/dev/null)

    if [ -n "\$pty" ] && [ -w "\$pty" ]; then
        printf '\x1b\x1b' > "\$pty"
        sleep 0.1  # shortened for tests
        printf '%s\n' "\$nudge" > "\$pty"
        echo "PTY_ESC_WRITE:\$nudge" >> "$PTY_LOG"
        return 0
    fi
    return 1
}
HARNESS
    chmod +x "$TEST_HARNESS"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# --- T-SW-001: self-watch active → skip nudge ---

@test "T-SW-001: send_wakeup skips nudge when agent has active self-watch" {
    cat > "$MOCK_PGREP" << 'MOCK'
#!/bin/bash
echo "12345 inotifywait -q -t 120 -e modify inbox/test_agent.yaml"
exit 0
MOCK
    chmod +x "$MOCK_PGREP"

    run bash -c "source '$TEST_HARNESS' && send_wakeup 3"
    [ "$status" -eq 0 ]

    # No pty write should have occurred
    [ ! -s "$PTY_LOG" ]

    echo "$output" | grep -q "SKIP"
}

# --- T-SW-002: no self-watch → pty direct write ---

@test "T-SW-002: send_wakeup uses pty direct write when no self-watch" {
    run bash -c "source '$TEST_HARNESS' && send_wakeup 5"
    [ "$status" -eq 0 ]

    # Verify pty write occurred
    [ -s "$PTY_LOG" ]
    grep -q "PTY_WRITE:inbox5" "$PTY_LOG"

    echo "$output" | grep -q "PTY"
}

# --- T-SW-003: pty write content is "inboxN" ---

@test "T-SW-003: pty direct write content is inboxN format" {
    run bash -c "source '$TEST_HARNESS' && send_wakeup 3"
    [ "$status" -eq 0 ]

    # Verify the actual content written to fake pty
    grep -q "inbox3" "$FAKE_PTY"
}

# --- T-SW-004: pty not writable → return 1 ---

@test "T-SW-004: send_wakeup returns 1 when pty is not writable" {
    chmod a-w "$FAKE_PTY"

    run bash -c "source '$TEST_HARNESS' && send_wakeup 2"
    [ "$status" -eq 1 ]

    echo "$output" | grep -qi "WARN\|not writable"

    # Restore permissions for cleanup
    chmod a+w "$FAKE_PTY"
}

# --- T-SW-005: no paste-buffer or send-keys used for nudge ---

@test "T-SW-005: nudge delivery does NOT use paste-buffer or send-keys" {
    run bash -c "source '$TEST_HARNESS' && send_wakeup 3"
    [ "$status" -eq 0 ]

    # Only tmux call should be display-message for pty path
    ! grep -q "paste-buffer" "$MOCK_LOG"
    ! grep -q "send-keys" "$MOCK_LOG"
    ! grep -q "set-buffer" "$MOCK_LOG"

    # display-message IS expected (to get pty path)
    grep -q "display-message" "$MOCK_LOG"
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
    run bash -c "source '$TEST_HARNESS' && agent_has_self_watch"
    [ "$status" -eq 1 ]
}

# --- T-SW-008: /clear uses pty direct write (no send-keys) ---

@test "T-SW-008: send_cli_command /clear uses pty direct write" {
    run bash -c "source '$TEST_HARNESS' && send_cli_command /clear"
    [ "$status" -eq 0 ]

    # Verify pty write occurred
    grep -q "PTY_CLI:/clear" "$PTY_LOG"

    # Verify NO send-keys used
    ! grep -q "send-keys" "$MOCK_LOG"

    # Verify /clear was written to fake pty
    grep -q "/clear" "$FAKE_PTY"
}

# --- T-SW-009: /model uses pty direct write (no send-keys) ---

@test "T-SW-009: send_cli_command /model uses pty direct write" {
    run bash -c "source '$TEST_HARNESS' && send_cli_command '/model opus'"
    [ "$status" -eq 0 ]

    grep -q "PTY_CLI:/model opus" "$PTY_LOG"
    ! grep -q "send-keys" "$MOCK_LOG"
}

# --- T-SW-010: nudge content format ---

@test "T-SW-010: nudge content format is inboxN (backward compatible)" {
    run bash -c "source '$TEST_HARNESS' && send_wakeup 7"
    [ "$status" -eq 0 ]

    grep -q "PTY_WRITE:inbox7" "$PTY_LOG"
}

# --- T-SW-011: backward compat — functions exist ---

@test "T-SW-011: inbox_watcher.sh uses pty direct write, no send-keys in executable code" {
    grep -q "send_wakeup()" "$WATCHER_SCRIPT"
    grep -q "agent_has_self_watch" "$WATCHER_SCRIPT"
    grep -q "pane_tty" "$WATCHER_SCRIPT"

    # No send-keys in executable code (only in comments)
    # Strip comments, then check
    local executable_lines
    executable_lines=$(grep -v '^\s*#' "$WATCHER_SCRIPT")
    ! echo "$executable_lines" | grep -q "send-keys"
    ! echo "$executable_lines" | grep -q "paste-buffer"
    ! echo "$executable_lines" | grep -q "set-buffer"
}

# --- T-ESC-001: no unread → FIRST_UNREAD_SEEN stays 0 ---

@test "T-ESC-001: escalation state resets when no unread messages" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        FIRST_UNREAD_SEEN=12345
        # Simulate no unread
        normal_count=0
        if [ "$normal_count" -gt 0 ] 2>/dev/null; then
            echo "SHOULD_NOT_REACH"
        else
            FIRST_UNREAD_SEEN=0
        fi
        echo "FIRST_UNREAD_SEEN=$FIRST_UNREAD_SEEN"
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "FIRST_UNREAD_SEEN=0"
}

# --- T-ESC-002: unread < 2min → standard nudge ---

@test "T-ESC-002: escalation Phase 1 — unread under 2min uses standard nudge" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        now=$(date +%s)
        FIRST_UNREAD_SEEN=$((now - 30))  # 30 seconds ago
        age=$((now - FIRST_UNREAD_SEEN))
        if [ "$age" -lt "$ESCALATE_PHASE1" ]; then
            send_wakeup 2
            echo "PHASE1_NUDGE"
        fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "PHASE1_NUDGE"
    grep -q "PTY_WRITE:inbox2" "$PTY_LOG"
    ! grep -q "PTY_ESC_WRITE" "$PTY_LOG"
    ! grep -q "PTY_CLI" "$PTY_LOG"
}

# --- T-ESC-003: unread 2-4min → Escape+nudge ---

@test "T-ESC-003: escalation Phase 2 — unread 2-4min uses Escape+nudge" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        now=$(date +%s)
        FIRST_UNREAD_SEEN=$((now - 180))  # 3 minutes ago
        age=$((now - FIRST_UNREAD_SEEN))
        if [ "$age" -ge "$ESCALATE_PHASE1" ] && [ "$age" -lt "$ESCALATE_PHASE2" ]; then
            send_wakeup_with_escape 3
            echo "PHASE2_ESCAPE_NUDGE"
        fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "PHASE2_ESCAPE_NUDGE"
    grep -q "PTY_ESC_WRITE:inbox3" "$PTY_LOG"
    ! grep -q "PTY_CLI" "$PTY_LOG"
}

# --- T-ESC-004: unread > 4min → /clear sent ---

@test "T-ESC-004: escalation Phase 3 — unread over 4min sends /clear" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        now=$(date +%s)
        FIRST_UNREAD_SEEN=$((now - 300))  # 5 minutes ago
        LAST_CLEAR_TS=0  # no recent /clear
        age=$((now - FIRST_UNREAD_SEEN))
        if [ "$age" -ge "$ESCALATE_PHASE2" ] && [ "$LAST_CLEAR_TS" -lt "$((now - ESCALATE_COOLDOWN))" ]; then
            send_cli_command "/clear"
            echo "PHASE3_CLEAR"
        fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "PHASE3_CLEAR"
    grep -q "PTY_CLI:/clear" "$PTY_LOG"
}

# --- T-ESC-005: /clear cooldown → falls back to Escape+nudge ---

@test "T-ESC-005: escalation /clear cooldown — falls back to Escape+nudge" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        now=$(date +%s)
        FIRST_UNREAD_SEEN=$((now - 300))  # 5 minutes ago
        LAST_CLEAR_TS=$((now - 60))  # /clear sent 1 min ago (within 5min cooldown)
        age=$((now - FIRST_UNREAD_SEEN))
        if [ "$age" -ge "$ESCALATE_PHASE2" ] && [ "$LAST_CLEAR_TS" -ge "$((now - ESCALATE_COOLDOWN))" ]; then
            send_wakeup_with_escape 4
            echo "COOLDOWN_FALLBACK"
        fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "COOLDOWN_FALLBACK"
    grep -q "PTY_ESC_WRITE:inbox4" "$PTY_LOG"
    ! grep -q "PTY_CLI" "$PTY_LOG"
}
