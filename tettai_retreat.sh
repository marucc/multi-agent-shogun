#!/bin/bash
# 🏯 multi-agent-shogun 撤退スクリプト（全終了用）
# Retreat Script - Graceful shutdown of all agents
# Agent Teams 版
#
# 使用方法:
#   ./tettai_retreat.sh           # 通常撤退（バックアップあり）
#   ./tettai_retreat.sh -f        # 強制撤退（バックアップなし）
#   ./tettai_retreat.sh -h        # ヘルプ表示

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Agent Teams データのパス
TEAM_DIR="$HOME/.claude/teams/shogun-team"
TASK_DIR="$HOME/.claude/tasks/shogun-team"

# 色付きログ関数（戦国風）
log_info() {
    echo -e "\033[1;33m【報】\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m【成】\033[0m $1"
}

log_retreat() {
    echo -e "\033[1;36m【退】\033[0m $1"
}

# ═══════════════════════════════════════════════════════════════════════════════
# オプション解析
# ═══════════════════════════════════════════════════════════════════════════════
FORCE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_MODE=true
            shift
            ;;
        -h|--help)
            echo ""
            echo "🏯 multi-agent-shogun 撤退スクリプト（Agent Teams 版）"
            echo ""
            echo "使用方法: ./tettai_retreat.sh [オプション]"
            echo ""
            echo "オプション:"
            echo "  -f, --force   強制撤退（バックアップなし）"
            echo "  -h, --help    このヘルプを表示"
            echo ""
            echo "例:"
            echo "  ./tettai_retreat.sh      # 通常撤退（バックアップ後に終了）"
            echo "  ./tettai_retreat.sh -f   # 強制撤退（即座に終了）"
            echo ""
            echo "以下を終了・クリーンアップします:"
            echo "  tmux セッション: shogun, multiagent"
            echo "  Agent Teams データ: ~/.claude/teams/shogun-team/"
            echo "                      ~/.claude/tasks/shogun-team/"
            echo ""
            exit 0
            ;;
        *)
            echo "不明なオプション: $1"
            echo "./tettai_retreat.sh -h でヘルプを表示"
            exit 1
            ;;
    esac
done

# ═══════════════════════════════════════════════════════════════════════════════
# 撤退バナー表示
# ═══════════════════════════════════════════════════════════════════════════════
show_retreat_banner() {
    clear
    echo ""
    echo -e "\033[1;36m╔══════════════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;36m║\033[0m \033[1;37m████████╗███████╗████████╗████████╗ █████╗ ██╗\033[0m                                 \033[1;36m║\033[0m"
    echo -e "\033[1;36m║\033[0m \033[1;37m╚══██╔══╝██╔════╝╚══██╔══╝╚══██╔══╝██╔══██╗██║\033[0m                                 \033[1;36m║\033[0m"
    echo -e "\033[1;36m║\033[0m \033[1;37m   ██║   █████╗     ██║      ██║   ███████║██║\033[0m                                 \033[1;36m║\033[0m"
    echo -e "\033[1;36m║\033[0m \033[1;37m   ██║   ██╔══╝     ██║      ██║   ██╔══██║██║\033[0m                                 \033[1;36m║\033[0m"
    echo -e "\033[1;36m║\033[0m \033[1;37m   ██║   ███████╗   ██║      ██║   ██║  ██║██║\033[0m                                 \033[1;36m║\033[0m"
    echo -e "\033[1;36m║\033[0m \033[1;37m   ╚═╝   ╚══════╝   ╚═╝      ╚═╝   ╚═╝  ╚═╝╚═╝\033[0m                                 \033[1;36m║\033[0m"
    echo -e "\033[1;36m╠══════════════════════════════════════════════════════════════════════════════════╣\033[0m"
    echo -e "\033[1;36m║\033[0m       \033[1;37m撤退じゃーーー！！！\033[0m    \033[1;35m⚔\033[0m    \033[1;33m本日の戦、ここまで！\033[0m                    \033[1;36m║\033[0m"
    echo -e "\033[1;36m╚══════════════════════════════════════════════════════════════════════════════════╝\033[0m"
    echo ""
}

# バナー表示
show_retreat_banner

# ═══════════════════════════════════════════════════════════════════════════════
# 存在確認（tmux セッション + Agent Teams データ）
# ═══════════════════════════════════════════════════════════════════════════════
SHOGUN_EXISTS=false
MULTIAGENT_EXISTS=false
TEAM_DATA_EXISTS=false

if tmux has-session -t shogun 2>/dev/null; then
    SHOGUN_EXISTS=true
fi

if tmux has-session -t multiagent 2>/dev/null; then
    MULTIAGENT_EXISTS=true
fi

if [ -d "$TEAM_DIR" ] || [ -d "$TASK_DIR" ]; then
    TEAM_DATA_EXISTS=true
fi

if [ "$SHOGUN_EXISTS" = false ] && [ "$MULTIAGENT_EXISTS" = false ] && [ "$TEAM_DATA_EXISTS" = false ]; then
    log_info "陣は既に撤収済みでござる（セッション・チームデータなし）"
    echo ""
    exit 0
fi

# 現在の状態を表示
log_info "現在の陣容:"
[ "$SHOGUN_EXISTS" = true ] && log_info "  ├─ tmux: shogun セッション ... 稼働中"
[ "$MULTIAGENT_EXISTS" = true ] && log_info "  ├─ tmux: multiagent セッション ... 稼働中"
[ "$TEAM_DATA_EXISTS" = true ] && log_info "  ├─ Agent Teams: チームデータ ... 存在"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# バックアップ（強制モードでなければ）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$FORCE_MODE" = false ]; then
    BACKUP_DIR="./logs/backup_$(date '+%Y%m%d_%H%M%S')"
    NEED_BACKUP=false

    # dashboard.md のバックアップ判定
    if [ -f "./dashboard.md" ]; then
        if grep -q "cmd_" "./dashboard.md" 2>/dev/null; then
            NEED_BACKUP=true
        fi
    fi

    # Agent Teams タスクデータの存在確認
    if [ -d "$TASK_DIR" ]; then
        NEED_BACKUP=true
    fi

    if [ "$NEED_BACKUP" = true ]; then
        log_info "📦 戦況記録をバックアップ中..."
        mkdir -p "$BACKUP_DIR" || true

        # dashboard.md のバックアップ
        if [ -f "./dashboard.md" ]; then
            cp "./dashboard.md" "$BACKUP_DIR/" 2>/dev/null || true
            log_success "  ├─ dashboard.md バックアップ完了"
        fi

        # Agent Teams タスクデータのバックアップ
        if [ -d "$TASK_DIR" ]; then
            cp -r "$TASK_DIR" "$BACKUP_DIR/tasks-shogun-team" 2>/dev/null || true
            log_success "  ├─ Agent Teams タスクデータ バックアップ完了"
        fi

        log_success "  └─ バックアップ先: $BACKUP_DIR"
        echo ""
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 未完了タスク保存（-f モードでも実行）
# ═══════════════════════════════════════════════════════════════════════════════
if [ -d "$TASK_DIR" ]; then
    PENDING_YAML="./status/pending_tasks.yaml"
    PENDING_COUNT=0
    PENDING_ENTRIES=""

    for task_file in "$TASK_DIR"/*.json; do
        [ -f "$task_file" ] || continue

        task_status=$(jq -r '.status // empty' "$task_file" 2>/dev/null) || continue
        [ "$task_status" = "completed" ] && continue

        task_id=$(jq -r '.id // empty' "$task_file" 2>/dev/null) || true
        task_subject=$(jq -r '.subject // empty' "$task_file" 2>/dev/null) || true
        task_description=$(jq -r '.description // empty' "$task_file" 2>/dev/null) || true
        task_owner=$(jq -r '.owner // empty' "$task_file" 2>/dev/null) || true
        task_blocked_by=$(jq -r '(.blockedBy // []) | map(tostring) | join(", ")' "$task_file" 2>/dev/null) || true

        # ダブルクォートをエスケープ
        task_id="${task_id//\"/\\\"}"
        task_subject="${task_subject//\"/\\\"}"
        task_owner="${task_owner//\"/\\\"}"
        task_status="${task_status//\"/\\\"}"

        # YAML エントリを構築（description はリテラルブロックで出力）
        PENDING_ENTRIES="${PENDING_ENTRIES}  - id: \"${task_id}\"
    subject: \"${task_subject}\"
    description: |
$(echo "$task_description" | sed 's/^/      /')
    owner: \"${task_owner}\"
    status: \"${task_status}\"
    blockedBy: [${task_blocked_by}]
"
        PENDING_COUNT=$((PENDING_COUNT + 1))
    done

    if [ "$PENDING_COUNT" -gt 0 ]; then
        mkdir -p ./status
        SAVED_AT=$(date "+%Y-%m-%d %H:%M")
        {
            echo "# 未完了タスク一覧（撤退時自動保存）"
            echo "# 再出陣時に将軍が読み込み、家老にタスクを再割り当てする"
            echo "saved_at: \"${SAVED_AT}\""
            echo "tasks:"
            printf '%s' "$PENDING_ENTRIES"
        } > "$PENDING_YAML"
        log_info "📜 未完了の陣立て ${PENDING_COUNT} 件を保存いたした"
        log_success "  └─ 保存先: ${PENDING_YAML}"
        echo ""
    else
        log_info "📜 未完了の陣立てなし（全任務完了済み）"
        echo ""
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 撤退処理
# ═══════════════════════════════════════════════════════════════════════════════
log_retreat "🏯 全軍撤退開始..."
echo ""

# STEP 1: tmux セッション終了（Claude Code プロセスも終了する）
if [ "$MULTIAGENT_EXISTS" = true ]; then
    log_retreat "  └─ 家老・目付・足軽の陣を撤収中..."
    tmux kill-session -t multiagent 2>/dev/null
    log_success "     └─ multiagent陣、撤収完了"
fi

if [ "$SHOGUN_EXISTS" = true ]; then
    log_retreat "  └─ 将軍の本陣を撤収中..."
    tmux kill-session -t shogun 2>/dev/null
    log_success "     └─ shogun本陣、撤収完了"
fi

# STEP 2: Agent Teams チームデータのクリーンアップ
if [ "$TEAM_DATA_EXISTS" = true ]; then
    log_retreat "  └─ Agent Teams チームデータを撤収中..."

    if [ -d "$TEAM_DIR" ]; then
        trash "$TEAM_DIR" 2>/dev/null || true
        log_success "     └─ チーム設定（teams/shogun-team）撤収完了"
    fi

    if [ -d "$TASK_DIR" ]; then
        trash "$TASK_DIR" 2>/dev/null || true
        log_success "     └─ タスクデータ（tasks/shogun-team）撤収完了"
    fi
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# 完了メッセージ
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "\033[1;36m  ╔══════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;36m  ║\033[0m  \033[1;37m🏯 撤退完了！本日の戦、お疲れ様でござった！\033[0m              \033[1;36m║\033[0m"
echo -e "\033[1;36m  ╚══════════════════════════════════════════════════════════╝\033[0m"
echo ""
echo "  次回出陣するには:"
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  ./shutsujin_departure.sh                                │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
echo "  ════════════════════════════════════════════════════════════"
echo "   また明日も勝利を掴もうぞ！ (Let's seize victory again!)"
echo "  ════════════════════════════════════════════════════════════"
echo ""
