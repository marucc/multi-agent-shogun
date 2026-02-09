#!/usr/bin/env bats
# test_send_wakeup.bats — send_wakeup() unit tests
# tmux send-keys方式: 短いnudge + Enter, timeout 5s
#
# テスト構成:
#   T-SW-001: send_wakeup — active self-watch → skip nudge
#   T-SW-002: send_wakeup — no self-watch → tmux send-keys
#   T-SW-003: send_wakeup — send-keys content is "inboxN" + Enter
#   T-SW-004: send_wakeup — send-keys failure → return 1
#   T-SW-005: send_wakeup — no paste-buffer or set-buffer used
#   T-SW-006: agent_has_self_watch — detects inotifywait process
#   T-SW-007: agent_has_self_watch — no inotifywait → returns 1
#   T-SW-008: send_cli_command — /clear uses send-keys
#   T-SW-009: send_cli_command — /model uses send-keys
#   T-SW-010: nudge content format — inboxN (backward compatible)
#   T-SW-011: inbox_watcher.sh uses send-keys, functions exist
#   T-ESC-001: escalation — no unread → FIRST_UNREAD_SEEN stays 0
#   T-ESC-002: escalation — unread < 2min → standard nudge
#   T-ESC-003: escalation — unread 2-4min → Escape+nudge
#   T-ESC-004: escalation — unread > 4min → /clear sent
#   T-ESC-005: escalation — /clear cooldown → falls back to Escape+nudge
#   T-BUSY-001: agent_is_busy — detects "Working" in pane
#   T-BUSY-002: agent_is_busy — idle pane returns 1
#   T-BUSY-003: send_wakeup — skips when agent is busy
#   T-BUSY-004: send_wakeup_with_escape — skips when agent is busy
#   T-CODEX-001: send_cli_command — codex /clear → /new conversion
#   T-CODEX-002: send_cli_command — codex /model → skip
#   T-CODEX-003: C-u sent when unread=0 and agent is idle
#   T-CODEX-004: C-u NOT sent when agent is busy
#   T-COPILOT-001: send_cli_command — copilot /clear → Ctrl-C + restart
#   T-COPILOT-002: send_cli_command — copilot /model → skip

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

    # Log file for action tracking
    export PTY_LOG="$TEST_TMPDIR/action_log.log"
    > "$PTY_LOG"

    # Create mock tmux that logs all calls
    export MOCK_TMUX="$TEST_TMPDIR/mock_tmux"
    cat > "$MOCK_TMUX" << 'MOCK'
#!/bin/bash
echo "tmux $*" >> "$MOCK_LOG"
# send-keys always succeeds
if echo "$*" | grep -q "send-keys"; then
    exit 0
fi
# display-message returns something
if echo "$*" | grep -q "display-message"; then
    echo "mock_pane"
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
sleep() { :; }  # skip sleeps in tests
export -f tmux timeout pgrep sleep

# agent_has_self_watch
agent_has_self_watch() {
    pgrep -f "inotifywait.*inbox/\${AGENT_ID}.yaml" >/dev/null 2>&1
}

# agent_is_busy — check if CLI is processing (Working/Thinking)
# Uses MOCK_CAPTURE_PANE env var to control test output
agent_is_busy() {
    local pane_content
    if [ -n "\${MOCK_CAPTURE_PANE:-}" ]; then
        pane_content="\$MOCK_CAPTURE_PANE"
    else
        pane_content=\$(timeout 2 tmux capture-pane -t "\$PANE_TARGET" -p 2>/dev/null | tail -15)
    fi
    if echo "\$pane_content" | grep -qiE '(Working|Thinking|Planning|Sending|esc to interrupt)'; then
        return 0
    fi
    return 1
}

# send_wakeup — tmux send-keys (短いnudge + Enter, timeout 5s)
send_wakeup() {
    local unread_count="\$1"
    local nudge="inbox\${unread_count}"

    if agent_has_self_watch; then
        echo "[SKIP] Agent \$AGENT_ID has active self-watch" >&2
        return 0
    fi

    if agent_is_busy; then
        echo "[SKIP] Agent \$AGENT_ID is busy (Working), deferring nudge" >&2
        return 0
    fi

    echo "[SEND-KEYS] Sending nudge to \$PANE_TARGET for \$AGENT_ID" >&2
    if timeout 5 tmux send-keys -t "\$PANE_TARGET" "\$nudge" Enter 2>/dev/null; then
        echo "SENDKEYS_NUDGE:\$nudge" >> "$PTY_LOG"
        echo "[OK] Wake-up sent to \$AGENT_ID (\${unread_count} unread)" >&2
        return 0
    fi

    echo "[WARN] send-keys failed" >&2
    return 1
}

# send_cli_command — CLI_TYPE別分岐あり
send_cli_command() {
    local cmd="\$1"
    local actual_cmd="\$cmd"

    case "\$CLI_TYPE" in
        codex)
            if [[ "\$cmd" == "/clear" ]]; then
                echo "SENDKEYS_CLI:/new" >> "$PTY_LOG"
                echo "[SEND-KEYS] Codex /clear→/new" >&2
                timeout 5 tmux send-keys -t "\$PANE_TARGET" "/new" Enter 2>/dev/null
                return 0
            fi
            if [[ "\$cmd" == /model* ]]; then
                echo "SKIP_MODEL:\$cmd" >> "$PTY_LOG"
                echo "[SKIP] \$cmd not supported on codex" >&2
                return 0
            fi
            ;;
        copilot)
            if [[ "\$cmd" == "/clear" ]]; then
                echo "COPILOT_RESTART" >> "$PTY_LOG"
                echo "[SEND-KEYS] Copilot /clear: Ctrl-C + restart" >&2
                timeout 5 tmux send-keys -t "\$PANE_TARGET" C-c 2>/dev/null
                timeout 5 tmux send-keys -t "\$PANE_TARGET" "copilot --yolo" Enter 2>/dev/null
                return 0
            fi
            if [[ "\$cmd" == /model* ]]; then
                echo "SKIP_MODEL:\$cmd" >> "$PTY_LOG"
                echo "[SKIP] \$cmd not supported on copilot" >&2
                return 0
            fi
            ;;
    esac

    echo "[SEND-KEYS] Sending CLI command: \$actual_cmd" >&2
    timeout 5 tmux send-keys -t "\$PANE_TARGET" C-c 2>/dev/null
    timeout 5 tmux send-keys -t "\$PANE_TARGET" "\$actual_cmd" Enter 2>/dev/null
    echo "SENDKEYS_CLI:\$actual_cmd" >> "$PTY_LOG"
    return 0
}

# Escalation state variables
FIRST_UNREAD_SEEN=0
LAST_CLEAR_TS=0
ESCALATE_PHASE1=120
ESCALATE_PHASE2=240
ESCALATE_COOLDOWN=300

# send_wakeup_with_escape — Escape×2 + C-c + nudge
send_wakeup_with_escape() {
    local unread_count="\$1"
    local nudge="inbox\${unread_count}"

    if agent_has_self_watch; then
        return 0
    fi

    if agent_is_busy; then
        echo "[SKIP] Agent \$AGENT_ID is busy (Working), deferring Phase 2 nudge" >&2
        return 0
    fi

    timeout 5 tmux send-keys -t "\$PANE_TARGET" Escape Escape 2>/dev/null
    timeout 5 tmux send-keys -t "\$PANE_TARGET" C-c 2>/dev/null
    if timeout 5 tmux send-keys -t "\$PANE_TARGET" "\$nudge" Enter 2>/dev/null; then
        echo "SENDKEYS_ESC_NUDGE:\$nudge" >> "$PTY_LOG"
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

    # No send-keys should have occurred
    [ ! -s "$PTY_LOG" ]

    echo "$output" | grep -q "SKIP"
}

# --- T-SW-002: no self-watch → tmux send-keys ---

@test "T-SW-002: send_wakeup uses tmux send-keys when no self-watch" {
    run bash -c "source '$TEST_HARNESS' && send_wakeup 5"
    [ "$status" -eq 0 ]

    # Verify send-keys occurred
    [ -s "$PTY_LOG" ]
    grep -q "SENDKEYS_NUDGE:inbox5" "$PTY_LOG"

    # Verify tmux send-keys was called
    grep -q "send-keys" "$MOCK_LOG"
}

# --- T-SW-003: send-keys content is "inboxN" + Enter ---

@test "T-SW-003: send-keys content is inboxN format with Enter" {
    run bash -c "source '$TEST_HARNESS' && send_wakeup 3"
    [ "$status" -eq 0 ]

    # Verify the send-keys call includes inbox3 and Enter
    grep -q "send-keys.*inbox3.*Enter" "$MOCK_LOG"
}

# --- T-SW-004: send-keys failure → return 1 ---

@test "T-SW-004: send_wakeup returns 1 when send-keys fails" {
    # Make mock tmux fail for send-keys
    cat > "$MOCK_TMUX" << 'MOCK'
#!/bin/bash
echo "tmux $*" >> "$MOCK_LOG"
if echo "$*" | grep -q "send-keys"; then
    exit 1
fi
exit 0
MOCK
    chmod +x "$MOCK_TMUX"

    run bash -c "source '$TEST_HARNESS' && send_wakeup 2"
    [ "$status" -eq 1 ]

    echo "$output" | grep -qi "WARN\|failed"
}

# --- T-SW-005: no paste-buffer or set-buffer used ---

@test "T-SW-005: nudge delivery does NOT use paste-buffer or set-buffer" {
    run bash -c "source '$TEST_HARNESS' && send_wakeup 3"
    [ "$status" -eq 0 ]

    # These should never be used
    ! grep -q "paste-buffer" "$MOCK_LOG"
    ! grep -q "set-buffer" "$MOCK_LOG"

    # send-keys IS expected
    grep -q "send-keys" "$MOCK_LOG"
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

# --- T-SW-008: /clear uses send-keys ---

@test "T-SW-008: send_cli_command /clear uses tmux send-keys" {
    run bash -c "source '$TEST_HARNESS' && send_cli_command /clear"
    [ "$status" -eq 0 ]

    # Verify send-keys was used
    grep -q "SENDKEYS_CLI:/clear" "$PTY_LOG"
    grep -q "send-keys" "$MOCK_LOG"

    # Verify /clear was in the send-keys call
    grep -q "send-keys.*/clear.*Enter" "$MOCK_LOG"
}

# --- T-SW-009: /model uses send-keys ---

@test "T-SW-009: send_cli_command /model uses tmux send-keys" {
    run bash -c "source '$TEST_HARNESS' && send_cli_command '/model opus'"
    [ "$status" -eq 0 ]

    grep -q "SENDKEYS_CLI:/model opus" "$PTY_LOG"
    grep -q "send-keys" "$MOCK_LOG"
}

# --- T-SW-010: nudge content format ---

@test "T-SW-010: nudge content format is inboxN (backward compatible)" {
    run bash -c "source '$TEST_HARNESS' && send_wakeup 7"
    [ "$status" -eq 0 ]

    grep -q "SENDKEYS_NUDGE:inbox7" "$PTY_LOG"
}

# --- T-SW-011: functions exist in inbox_watcher.sh ---

@test "T-SW-011: inbox_watcher.sh uses send-keys with required functions" {
    grep -q "send_wakeup()" "$WATCHER_SCRIPT"
    grep -q "agent_has_self_watch" "$WATCHER_SCRIPT"
    grep -q "send_wakeup_with_escape()" "$WATCHER_SCRIPT"
    grep -q "send_cli_command()" "$WATCHER_SCRIPT"

    # send-keys IS used in executable code
    local executable_lines
    executable_lines=$(grep -v '^\s*#' "$WATCHER_SCRIPT")
    echo "$executable_lines" | grep -q "send-keys"

    # paste-buffer and set-buffer are NOT used
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
    grep -q "SENDKEYS_NUDGE:inbox2" "$PTY_LOG"
    ! grep -q "SENDKEYS_ESC_NUDGE" "$PTY_LOG"
    ! grep -q "SENDKEYS_CLI" "$PTY_LOG"
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
    grep -q "SENDKEYS_ESC_NUDGE:inbox3" "$PTY_LOG"
    ! grep -q "SENDKEYS_CLI" "$PTY_LOG"
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
    grep -q "SENDKEYS_CLI:/clear" "$PTY_LOG"
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
    grep -q "SENDKEYS_ESC_NUDGE:inbox4" "$PTY_LOG"
    ! grep -q "SENDKEYS_CLI" "$PTY_LOG"
}

# --- T-BUSY-001: agent_is_busy detects "Working" ---

@test "T-BUSY-001: agent_is_busy returns 0 when pane shows Working" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        MOCK_CAPTURE_PANE="◦ Working on task (12s • esc to interrupt)"
        agent_is_busy
    '
    [ "$status" -eq 0 ]
}

# --- T-BUSY-002: agent_is_busy returns 1 when idle ---

@test "T-BUSY-002: agent_is_busy returns 1 when pane is idle" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        MOCK_CAPTURE_PANE="› Summarize recent commits
  ? for shortcuts                100% context left"
        agent_is_busy
    '
    [ "$status" -eq 1 ]
}

# --- T-BUSY-003: send_wakeup skips when agent is busy ---

@test "T-BUSY-003: send_wakeup skips nudge when agent is busy" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        MOCK_CAPTURE_PANE="◦ Thinking about approach (5s • esc to interrupt)"
        send_wakeup 3
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "SKIP.*busy"

    # No nudge should have been sent
    [ ! -s "$PTY_LOG" ]
}

# --- T-BUSY-004: send_wakeup_with_escape skips when agent is busy ---

@test "T-BUSY-004: send_wakeup_with_escape skips when agent is busy" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        MOCK_CAPTURE_PANE="◦ Sending request (2s • esc to interrupt)"
        send_wakeup_with_escape 2
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "SKIP.*busy"

    # No nudge should have been sent
    [ ! -s "$PTY_LOG" ]
}

# --- T-CODEX-001: codex /clear → /new conversion ---

@test "T-CODEX-001: send_cli_command converts /clear to /new for codex" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="codex"
        send_cli_command "/clear"
    '
    [ "$status" -eq 0 ]

    # Should send /new, NOT /clear
    grep -q "SENDKEYS_CLI:/new" "$PTY_LOG"
    ! grep -q "SENDKEYS_CLI:/clear" "$PTY_LOG"

    # Verify /new was in tmux send-keys call
    grep -q "send-keys.*/new" "$MOCK_LOG"
}

# --- T-CODEX-002: codex /model → skip ---

@test "T-CODEX-002: send_cli_command skips /model for codex" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="codex"
        send_cli_command "/model opus"
    '
    [ "$status" -eq 0 ]

    # Should log skip, NOT send /model
    grep -q "SKIP_MODEL:/model opus" "$PTY_LOG"
    ! grep -q "SENDKEYS_CLI:/model" "$PTY_LOG"
}

# --- T-CODEX-003: C-u sent when unread=0 and agent is idle ---

@test "T-CODEX-003: C-u cleanup sent when no unread and agent is idle" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        MOCK_CAPTURE_PANE="› Summarize recent commits
  ? for shortcuts                100% context left"
        # Simulate no unread
        FIRST_UNREAD_SEEN=12345
        normal_count=0
        if [ "$normal_count" -gt 0 ] 2>/dev/null; then
            echo "SHOULD_NOT_REACH"
        else
            FIRST_UNREAD_SEEN=0
            if ! agent_is_busy; then
                timeout 2 tmux send-keys -t "$PANE_TARGET" C-u 2>/dev/null
                echo "C_U_SENT"
            fi
        fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "C_U_SENT"
    grep -q "send-keys.*C-u" "$MOCK_LOG"
}

# --- T-CODEX-004: C-u NOT sent when agent is busy ---

@test "T-CODEX-004: C-u cleanup NOT sent when agent is busy" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        MOCK_CAPTURE_PANE="◦ Working on request (10s • esc to interrupt)"
        FIRST_UNREAD_SEEN=12345
        normal_count=0
        if [ "$normal_count" -gt 0 ] 2>/dev/null; then
            echo "SHOULD_NOT_REACH"
        else
            FIRST_UNREAD_SEEN=0
            if ! agent_is_busy; then
                timeout 2 tmux send-keys -t "$PANE_TARGET" C-u 2>/dev/null
                echo "C_U_SENT"
            else
                echo "C_U_SKIPPED"
            fi
        fi
    '
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "C_U_SKIPPED"
    ! grep -q "C-u" "$MOCK_LOG"
}

# --- T-CODEX-005: claude /clear passes through as-is ---

@test "T-CODEX-005: send_cli_command sends /clear as-is for claude" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="claude"
        send_cli_command "/clear"
    '
    [ "$status" -eq 0 ]

    # Should send /clear directly (not /new)
    grep -q "SENDKEYS_CLI:/clear" "$PTY_LOG"
    ! grep -q "/new" "$PTY_LOG"
}

# --- T-CODEX-006: inbox_watcher.sh has agent_is_busy function ---

@test "T-CODEX-006: inbox_watcher.sh contains agent_is_busy and Codex handlers" {
    grep -q "agent_is_busy()" "$WATCHER_SCRIPT"
    grep -q 'Working|Thinking|Planning|Sending' "$WATCHER_SCRIPT"

    # Codex /clear → /new conversion exists
    grep -q '/new' "$WATCHER_SCRIPT"

    # Codex /model skip exists
    grep -q 'not supported on codex' "$WATCHER_SCRIPT"

    # C-u cleanup exists
    grep -q 'C-u' "$WATCHER_SCRIPT"

    # Copilot handler exists
    grep -q 'copilot --yolo' "$WATCHER_SCRIPT"
    grep -q 'not supported on copilot' "$WATCHER_SCRIPT"
}

# --- T-COPILOT-001: copilot /clear → Ctrl-C + restart ---

@test "T-COPILOT-001: send_cli_command sends Ctrl-C + copilot restart for copilot /clear" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="copilot"
        send_cli_command "/clear"
    '
    [ "$status" -eq 0 ]

    # Should trigger copilot restart, NOT /clear or /new
    grep -q "COPILOT_RESTART" "$PTY_LOG"
    ! grep -q "SENDKEYS_CLI:/clear" "$PTY_LOG"
    ! grep -q "SENDKEYS_CLI:/new" "$PTY_LOG"

    # Verify Ctrl-C and copilot --yolo were sent
    grep -q "send-keys.*C-c" "$MOCK_LOG"
    grep -q "send-keys.*copilot --yolo" "$MOCK_LOG"
}

# --- T-COPILOT-002: copilot /model → skip ---

@test "T-COPILOT-002: send_cli_command skips /model for copilot" {
    run bash -c '
        source "'"$TEST_HARNESS"'"
        CLI_TYPE="copilot"
        send_cli_command "/model opus"
    '
    [ "$status" -eq 0 ]

    # Should log skip
    grep -q "SKIP_MODEL:/model opus" "$PTY_LOG"
    ! grep -q "SENDKEYS_CLI:/model" "$PTY_LOG"
}
