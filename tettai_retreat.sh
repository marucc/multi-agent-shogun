#!/bin/bash
# 🏯 multi-agent-shogun 撤退スクリプト（全終了用）
# Retreat Script - Graceful shutdown of all agents
#
# 使用方法:
#   ./tettai_retreat.sh           # 通常撤退（バックアップあり）
#   ./tettai_retreat.sh -f        # 強制撤退（バックアップなし）
#   ./tettai_retreat.sh -h        # ヘルプ表示

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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
            echo "🏯 multi-agent-shogun 撤退スクリプト"
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
# セッション存在確認
# ═══════════════════════════════════════════════════════════════════════════════
SHOGUN_EXISTS=false
MULTIAGENT_EXISTS=false

if tmux has-session -t shogun 2>/dev/null; then
    SHOGUN_EXISTS=true
fi

if tmux has-session -t multiagent 2>/dev/null; then
    MULTIAGENT_EXISTS=true
fi

if [ "$SHOGUN_EXISTS" = false ] && [ "$MULTIAGENT_EXISTS" = false ]; then
    log_info "陣は既に撤収済みでござる（セッションなし）"
    echo ""
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════════
# バックアップ（強制モードでなければ）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$FORCE_MODE" = false ]; then
    BACKUP_DIR="./logs/backup_$(date '+%Y%m%d_%H%M%S')"
    NEED_BACKUP=false

    if [ -f "./dashboard.md" ]; then
        if grep -q "cmd_" "./dashboard.md" 2>/dev/null; then
            NEED_BACKUP=true
        fi
    fi

    if [ "$NEED_BACKUP" = true ]; then
        log_info "📦 戦況記録をバックアップ中..."
        mkdir -p "$BACKUP_DIR" || true
        cp "./dashboard.md" "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "./queue/reports" "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "./queue/tasks" "$BACKUP_DIR/" 2>/dev/null || true
        cp "./queue/shogun_to_karo.yaml" "$BACKUP_DIR/" 2>/dev/null || true
        log_success "  └─ バックアップ完了: $BACKUP_DIR"
        echo ""
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# セッション終了
# ═══════════════════════════════════════════════════════════════════════════════
log_retreat "🏯 全軍撤退開始..."
echo ""

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
