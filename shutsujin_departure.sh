#!/bin/bash
# 🏯 multi-agent-shogun 出陣スクリプト（毎日の起動用）
# Daily Deployment Script for Multi-Agent Orchestration System
# Agent Teams 版
#
# 使用方法:
#   ./shutsujin_departure.sh           # 将軍起動（Agent Teams がチームを構成）
#   ./shutsujin_departure.sh -h        # ヘルプ表示

set -e

# 実行時のカレントディレクトリを作業ディレクトリとして保存
WORK_DIR="$(pwd)"

# shogun システムのルートディレクトリ（このスクリプトの場所）
SHOGUN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# プロジェクト共通変数を読み込み
source "${SHOGUN_ROOT}/scripts/project-env.sh"

# 言語設定を読み取り（デフォルト: ja）
LANG_SETTING="ja"
if [ -f "${SHOGUN_ROOT}/config/settings.yaml" ]; then
    LANG_SETTING=$(grep "^language:" "${SHOGUN_ROOT}/config/settings.yaml" 2>/dev/null | awk '{print $2}' || echo "ja")
fi

# 足軽数を読み取り（デフォルト: 3）
ASHIGARU_COUNT=3
if [ -f "${SHOGUN_ROOT}/config/settings.yaml" ]; then
    ASHIGARU_COUNT=$(grep "^ashigaru_count:" "${SHOGUN_ROOT}/config/settings.yaml" 2>/dev/null | awk '{print $2}' || echo "3")
    ASHIGARU_COUNT=${ASHIGARU_COUNT:-3}
fi

# 色付きログ関数（戦国風）
log_info() {
    echo -e "\033[1;33m【報】\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m【成】\033[0m $1"
}

log_war() {
    echo -e "\033[1;31m【戦】\033[0m $1"
}

# ═══════════════════════════════════════════════════════════════════════════════
# オプション解析
# ═══════════════════════════════════════════════════════════════════════════════
RESUME_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--resume)
            RESUME_MODE=true
            shift
            ;;
        -h|--help)
            echo ""
            echo "🏯 multi-agent-shogun 出陣スクリプト（Agent Teams 版）"
            echo ""
            echo "使用方法: ./shutsujin_departure.sh [オプション]"
            echo ""
            echo "オプション:"
            echo "  -r, --resume      前回セッションを引き継いで再出陣（将軍 --continue）"
            echo "  -h, --help        このヘルプを表示"
            echo ""
            echo "例:"
            echo "  ./shutsujin_departure.sh      # 新規出陣（tmux セッション構築 + 将軍起動）"
            echo "  ./shutsujin_departure.sh -r   # 再出陣（前回の将軍セッションを引き継ぎ）"
            echo "  .shogun/bin/shogun.sh          # 将軍にアタッチ"
            echo "  .shogun/bin/multiagent.sh      # 配下にアタッチ"
            echo ""
            echo "2つの tmux セッションを構築します:"
            echo "  ${TMUX_SHOGUN}     - 将軍（Claude Code）"
            echo "  ${TMUX_MULTIAGENT} - 家老・目付・足軽（Agent Teams が自動配備）"
            echo ""
            exit 0
            ;;
        *)
            echo "不明なオプション: $1"
            echo "./shutsujin_departure.sh -h でヘルプを表示"
            exit 1
            ;;
    esac
done

# ═══════════════════════════════════════════════════════════════════════════════
# 出陣バナー表示（CC0ライセンスASCIIアート使用）
# ───────────────────────────────────────────────────────────────────────────────
# 【著作権・ライセンス表示】
# 忍者ASCIIアート: syntax-samurai/ryu - CC0 1.0 Universal (Public Domain)
# 出典: https://github.com/syntax-samurai/ryu
# "all files and scripts in this repo are released CC0 / kopimi!"
# ═══════════════════════════════════════════════════════════════════════════════
show_battle_cry() {
    clear

    # タイトルバナー（色付き）
    echo ""
    echo -e "\033[1;31m╔══════════════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m███████╗██╗  ██╗██╗   ██╗████████╗███████╗██╗   ██╗     ██╗██╗███╗   ██╗\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m██╔════╝██║  ██║██║   ██║╚══██╔══╝██╔════╝██║   ██║     ██║██║████╗  ██║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m███████╗███████║██║   ██║   ██║   ███████╗██║   ██║     ██║██║██╔██╗ ██║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m╚════██║██╔══██║██║   ██║   ██║   ╚════██║██║   ██║██   ██║██║██║╚██╗██║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m███████║██║  ██║╚██████╔╝   ██║   ███████║╚██████╔╝╚█████╔╝██║██║ ╚████║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m╚══════╝╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚══════╝ ╚═════╝  ╚════╝ ╚═╝╚═╝  ╚═══╝\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m╠══════════════════════════════════════════════════════════════════════════════════╣\033[0m"
    echo -e "\033[1;31m║\033[0m       \033[1;37m出陣じゃーーー！！！\033[0m    \033[1;36m⚔\033[0m    \033[1;35m天下布武！\033[0m                          \033[1;31m║\033[0m"
    echo -e "\033[1;31m╚══════════════════════════════════════════════════════════════════════════════════╝\033[0m"
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    # 足軽隊列（動的生成）
    # ═══════════════════════════════════════════════════════════════════════════
    # 足軽数に応じた漢数字（bash 3.x 互換）
    case $ASHIGARU_COUNT in
        1) KANJI_COUNT="一" ;;
        2) KANJI_COUNT="二" ;;
        3) KANJI_COUNT="三" ;;
        4) KANJI_COUNT="四" ;;
        5) KANJI_COUNT="五" ;;
        6) KANJI_COUNT="六" ;;
        7) KANJI_COUNT="七" ;;
        8) KANJI_COUNT="八" ;;
        *) KANJI_COUNT="$ASHIGARU_COUNT" ;;
    esac

    echo -e "\033[1;34m  ╔═════════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;34m  ║\033[0m                    \033[1;37m【 足 軽 隊 列 ・ ${KANJI_COUNT} 名 配 備 】\033[0m                      \033[1;34m║\033[0m"
    echo -e "\033[1;34m  ╚═════════════════════════════════════════════════════════════════════════════╝\033[0m"

    # 足軽ASCIIアートを動的に生成
    echo ""
    LINE1="      "
    LINE2="      "
    LINE3="     "
    LINE4="       "
    LINE5="      "
    LINE6="      "
    LINE7="     "
    for i in $(seq 1 $ASHIGARU_COUNT); do
        LINE1+="/\\      "
        LINE2+="/||\\    "
        LINE3+="/_||\\   "
        LINE4+="||      "
        LINE5+="/||\\    "
        LINE6+="/  \\    "
        LINE7+="[足$i]   "
    done
    echo "$LINE1"
    echo "$LINE2"
    echo "$LINE3"
    echo "$LINE4"
    echo "$LINE5"
    echo "$LINE6"
    echo "$LINE7"
    echo ""

    echo -e "                    \033[1;36m「「「 はっ！！ 出陣いたす！！ 」」」\033[0m"
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    # システム情報
    # ═══════════════════════════════════════════════════════════════════════════
    echo -e "\033[1;33m  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\033[0m"
    echo -e "\033[1;33m  ┃\033[0m  \033[1;37m🏯 multi-agent-shogun\033[0m  〜 \033[1;36mAgent Teams 戦国マルチエージェント\033[0m 〜           \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m                                                                           \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m    \033[1;35m将軍\033[0m: 統括  \033[1;31m家老\033[0m: 管理  \033[1;32m目付\033[0m: 品質保証  \033[1;34m足軽\033[0m×$ASHIGARU_COUNT: 実働      \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"
    echo ""
}

# バナー表示実行
show_battle_cry

if [ "$RESUME_MODE" = true ]; then
    echo -e "  \033[1;33m再出陣！前回の陣を引き継ぐぞ\033[0m"
else
    echo -e "  \033[1;33m天下布武！出陣準備を開始いたす\033[0m"
fi
echo ""
log_info "作業ディレクトリ: ${WORK_DIR}"
log_info "プロジェクト名: ${PROJECT_NAME_SAFE}"

# resume モード時のセッションID確認
SESSION_ID_FILE="${STATUS_DIR}/shogun_session_id"
SAVED_SESSION_ID=""
if [ "$RESUME_MODE" = true ]; then
    if [ -f "$SESSION_ID_FILE" ]; then
        SAVED_SESSION_ID=$(cat "$SESSION_ID_FILE")
        log_info "前回セッションID: ${SAVED_SESSION_ID:0:8}..."
    else
        log_info "⚠️  保存済みセッションIDなし（--continue で最新セッションを使用）"
    fi
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: .shogun/ ディレクトリ構造を作成
# ═══════════════════════════════════════════════════════════════════════════════
log_info "📁 .shogun/ ディレクトリ構造を構築中..."

mkdir -p "${BIN_DIR}"
mkdir -p "${STATUS_DIR}"
mkdir -p "${LOGS_DIR}"

log_success "  └─ ${SHOGUN_DATA_DIR}/ 構築完了"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: project.env 生成
# ═══════════════════════════════════════════════════════════════════════════════
cat > "${SHOGUN_DATA_DIR}/project.env" << EOF
# multi-agent-shogun プロジェクトメタデータ
# Generated: $(date "+%Y-%m-%d %H:%M:%S")
WORK_DIR="${WORK_DIR}"
SHOGUN_ROOT="${SHOGUN_ROOT}"
PROJECT_NAME_SAFE="${PROJECT_NAME_SAFE}"
TMUX_SHOGUN="${TMUX_SHOGUN}"
TMUX_MULTIAGENT="${TMUX_MULTIAGENT}"
TEAM_NAME="${TEAM_NAME}"
EOF

log_success "  └─ project.env 生成完了"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: bin/ ラッパースクリプト生成
# ═══════════════════════════════════════════════════════════════════════════════
cat > "${BIN_DIR}/shutsujin.sh" << 'WRAPPER_EOF'
#!/bin/sh
# 再出陣ラッパー（引数をパススルー）
# 使い方:
#   .shogun/bin/shutsujin.sh           # 新規出陣
#   .shogun/bin/shutsujin.sh --resume  # 前回セッション引き継ぎ
WRAPPER_EOF
# 変数展開が必要な部分を追記
echo "cd \"${WORK_DIR}\" && \"${SHOGUN_ROOT}/shutsujin_departure.sh\" \"\$@\"" >> "${BIN_DIR}/shutsujin.sh"

cat > "${BIN_DIR}/tettai.sh" << EOF
#!/bin/sh
# 撤退ラッパー
cd "${WORK_DIR}" && "${SHOGUN_ROOT}/tettai_retreat.sh"
EOF

cat > "${BIN_DIR}/shogun.sh" << EOF
#!/bin/sh
# 将軍セッションにアタッチ
tmux attach-session -t "${TMUX_SHOGUN}"
EOF

cat > "${BIN_DIR}/multiagent.sh" << EOF
#!/bin/sh
# 配下セッションにアタッチ
tmux attach-session -t "${TMUX_MULTIAGENT}"
EOF

chmod +x "${BIN_DIR}"/*.sh
log_success "  └─ bin/ ラッパースクリプト生成完了"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3b: spawn 制限フック設定（~/.claude/ 配下）
# ═══════════════════════════════════════════════════════════════════════════════
# 家老・足軽がチームメンバーを追加するのを物理的に防ぐフック。
# - シンボリックリンク: ~/.claude/hooks/check-team-spawn.sh → SHOGUN_ROOT/scripts/
# - フック設定: ~/.claude/settings.json の hooks.PreToolUse に追加
log_info "🔒 spawn 制限フックを確認中..."

HOOK_SCRIPT="${SHOGUN_ROOT}/scripts/check-team-spawn.sh"
HOOK_LINK="$HOME/.claude/hooks/check-team-spawn.sh"

# シンボリックリンクの作成/更新
mkdir -p "$HOME/.claude/hooks"
if [ ! -L "$HOOK_LINK" ] || [ "$(readlink "$HOOK_LINK")" != "$HOOK_SCRIPT" ]; then
    ln -sf "$HOOK_SCRIPT" "$HOOK_LINK"
    log_success "  └─ シンボリックリンク更新: ~/.claude/hooks/check-team-spawn.sh"
else
    log_info "  └─ シンボリックリンク確認済み"
fi

# ~/.claude/settings.json にフック設定を追加（jq が必要）
SETTINGS_FILE="$HOME/.claude/settings.json"
if command -v jq &> /dev/null; then
    if [ -f "$SETTINGS_FILE" ]; then
        # check-team-spawn フックが既に設定されているか確認
        if ! jq -e '.hooks.PreToolUse[]? | select(.hooks[]?.command | test("check-team-spawn"))' "$SETTINGS_FILE" > /dev/null 2>&1; then
            HOOK_ENTRY='{"matcher":"Task|TeamCreate","hooks":[{"type":"command","command":"~/.claude/hooks/check-team-spawn.sh"}]}'
            jq --argjson entry "$HOOK_ENTRY" '
                .hooks = (.hooks // {}) |
                .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [$entry])
            ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
            log_success "  └─ settings.json にフック設定を追加"
        else
            log_info "  └─ settings.json のフック設定確認済み"
        fi
    else
        # settings.json が存在しない場合は新規作成
        cat > "$SETTINGS_FILE" << 'SETTINGS_EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Task|TeamCreate",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/check-team-spawn.sh"
          }
        ]
      }
    ]
  }
}
SETTINGS_EOF
        log_success "  └─ settings.json を新規作成（フック設定付き）"
    fi
else
    log_info "  ⚠️  jq 未インストール: settings.json の自動設定をスキップ"
    log_info "     手動で ~/.claude/settings.json に PreToolUse フックを追加してください"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3c: commands/ のコピー（スラッシュコマンド配備）
# ═══════════════════════════════════════════════════════════════════════════════
log_info "📋 スラッシュコマンドを配備中..."

COMMANDS_SRC="${SHOGUN_ROOT}/commands"
COMMANDS_DST="${WORK_DIR}/.claude/commands"

if [ -d "$COMMANDS_SRC" ]; then
    mkdir -p "$COMMANDS_DST"
    for cmd_file in "$COMMANDS_SRC"/*.md; do
        if [ -f "$cmd_file" ]; then
            cp "$cmd_file" "$COMMANDS_DST/"
            log_success "  └─ $(basename "$cmd_file") 配備完了"
        fi
    done
else
    log_info "  └─ ${COMMANDS_SRC} なし、スキップ"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: 前回記録のバックアップ（内容がある場合のみ）
# ═══════════════════════════════════════════════════════════════════════════════
BACKUP_DIR="${LOGS_DIR}/backup_$(date '+%Y%m%d_%H%M%S')"
NEED_BACKUP=false

if [ -f "${DASHBOARD_PATH}" ]; then
    if grep -q "cmd_" "${DASHBOARD_PATH}" 2>/dev/null; then
        NEED_BACKUP=true
    fi
fi

if [ "$NEED_BACKUP" = true ]; then
    mkdir -p "$BACKUP_DIR" || true
    cp "${DASHBOARD_PATH}" "$BACKUP_DIR/" 2>/dev/null || true
    log_info "📦 前回の記録をバックアップ: $BACKUP_DIR"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: ダッシュボード初期化（resume 時はスキップ）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$RESUME_MODE" = true ] && [ -f "${DASHBOARD_PATH}" ]; then
    log_info "📊 戦況報告板は前回のものを引き継ぎ"
    echo ""
else
    log_info "📊 戦況報告板を初期化中..."
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M")

    if [ "$LANG_SETTING" = "ja" ]; then
        cat > "${DASHBOARD_PATH}" << EOF
# 📊 戦況報告
最終更新: ${TIMESTAMP}

## 🚨 要対応 - 殿のご判断をお待ちしております
なし

## 🔄 進行中 - 只今、戦闘中でござる
なし

## ✅ 本日の戦果
| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|

## 🎯 スキル化候補 - 承認待ち
なし

## 🛠️ 生成されたスキル
なし

## ⏸️ 待機中
なし

## ❓ 伺い事項
なし
EOF
    else
        cat > "${DASHBOARD_PATH}" << EOF
# 📊 戦況報告 (Battle Status Report)
最終更新 (Last Updated): ${TIMESTAMP}

## 🚨 要対応 - 殿のご判断をお待ちしております (Action Required - Awaiting Lord's Decision)
なし (None)

## 🔄 進行中 - 只今、戦闘中でござる (In Progress - Currently in Battle)
なし (None)

## ✅ 本日の戦果 (Today's Achievements)
| 時刻 (Time) | 戦場 (Battlefield) | 任務 (Mission) | 結果 (Result) |
|------|------|------|------|

## 🎯 スキル化候補 - 承認待ち (Skill Candidates - Pending Approval)
なし (None)

## 🛠️ 生成されたスキル (Generated Skills)
なし (None)

## ⏸️ 待機中 (On Standby)
なし (None)

## ❓ 伺い事項 (Questions for Lord)
なし (None)
EOF
    fi

    log_success "  └─ ダッシュボード初期化完了 (言語: $LANG_SETTING)"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: 前提コマンド確認
# ═══════════════════════════════════════════════════════════════════════════════

# tmux の存在確認（Agent Teams の teammateMode: tmux に必要）
if ! command -v tmux &> /dev/null; then
    echo ""
    echo "  ╔════════════════════════════════════════════════════════╗"
    echo "  ║  [ERROR] tmux not found!                              ║"
    echo "  ║  Agent Teams の tmux モードには tmux が必要です       ║"
    echo "  ╚════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 7: tmux セッション構築
# ═══════════════════════════════════════════════════════════════════════════════
# Agent Teams (teammateMode: tmux) は tmux 内で Claude を実行する必要がある。
# 将軍 → ${TMUX_SHOGUN} セッション（単独）
# 家老・目付・足軽 → ${TMUX_MULTIAGENT} セッション（自動移動）
#
# tmux hook (after-split-window) により、Agent Teams が shogun 内に spawn した
# チームメイトの pane を自動的に multiagent セッションに移動する。

log_war "👑 将軍の本陣を構築中..."

# 既存セッションをクリーンアップ
tmux kill-session -t "${TMUX_SHOGUN}" 2>/dev/null && log_info "  └─ 既存の ${TMUX_SHOGUN} セッション撤収" || true
tmux kill-session -t "${TMUX_MULTIAGENT}" 2>/dev/null && log_info "  └─ 既存の ${TMUX_MULTIAGENT} セッション撤収" || true

# 将軍用 tmux セッション（Claude Code を起動）
# resume モードでは保存済みセッションIDで復元、なければ --continue にフォールバック
CLAUDE_EXTRA_ARGS=""
if [ "$RESUME_MODE" = true ]; then
    if [ -n "$SAVED_SESSION_ID" ]; then
        CLAUDE_EXTRA_ARGS="--resume ${SAVED_SESSION_ID}"
        log_info "  └─ セッションID指定で復元（--resume ${SAVED_SESSION_ID:0:8}...）"
    else
        CLAUDE_EXTRA_ARGS="--continue"
        log_info "  └─ セッションIDなし、最新セッションで再開（--continue）"
    fi
fi
tmux new-session -d -s "${TMUX_SHOGUN}" -n "shogun" \
    "cd '${WORK_DIR}' && WORK_DIR='${WORK_DIR}' SHOGUN_DATA_DIR='${SHOGUN_DATA_DIR}' '${SHOGUN_ROOT}/scripts/claude-shogun' --dangerously-skip-permissions ${CLAUDE_EXTRA_ARGS}"
tmux set-option -t "${TMUX_SHOGUN}" pane-base-index 0

# チームメイト用 tmux セッション（配下の陣）
tmux new-session -d -s "${TMUX_MULTIAGENT}" -n "agents"
tmux set-option -t "${TMUX_MULTIAGENT}" pane-base-index 0
INITIAL_PANE=$(tmux display-message -t "${TMUX_MULTIAGENT}:agents" -p '#{pane_id}')

# tmux フック: shogun で pane が split されたら multiagent に自動移動
# Agent Teams が teammateMode: tmux で pane を作るたび発火する
# 初回移動時に空の初期 pane を削除する（2回目以降は既に消えているので無視）
tmux set-hook -t "${TMUX_SHOGUN}" after-split-window \
    "move-pane -t ${TMUX_MULTIAGENT}:agents ; run-shell -b '${SHOGUN_ROOT}/scripts/tmux-grid-layout.sh \"${TMUX_MULTIAGENT}:agents\" ; tmux kill-pane -t ${INITIAL_PANE} 2>/dev/null || true'"

log_success "  └─ 将軍の本陣（${TMUX_SHOGUN}）構築完了"
log_success "  └─ 配下の陣（${TMUX_MULTIAGENT}）構築完了"
log_success "  └─ 自動配備フック設定完了"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 8: 将軍にチーム構成の初期指示を送信
# ═══════════════════════════════════════════════════════════════════════════════
# Claude Code が起動完了するまで待機し、チーム構成指示を自動送信する。
# これにより、旧システムと同様に起動時に全エージェントが配備される。

log_war "⏳ 将軍の起動を待機中..."

# Claude Code の起動完了を待つ（プロンプト表示を検知）
READY=false
for i in $(seq 1 30); do
    if tmux capture-pane -t "${TMUX_SHOGUN}:shogun" -p 2>/dev/null | grep -qE '❯|>.*$'; then
        READY=true
        break
    fi
    sleep 1
done

if [ "$READY" = true ]; then
    log_success "  └─ 将軍、起動完了"

    # 足軽 spawn 指示を動的に構成
    ASHIGARU_SPAWN=""
    for i in $(seq 1 "$ASHIGARU_COUNT"); do
        ASHIGARU_SPAWN="${ASHIGARU_SPAWN}
- 足軽${i}号（ashigaru${i}）: ${SHOGUN_ROOT}/instructions/ashigaru.md を読ませよ"
    done

    if [ "$RESUME_MODE" = true ]; then
        # ═══════════════════════════════════════════════════════════════════
        # resume モード: 前回セッションを引き継ぎ、チームだけ再構成
        # ═══════════════════════════════════════════════════════════════════
        # 未完了タスクファイルの参照を構成
        PENDING_TASKS_REF=""
        if [ -f "${STATUS_DIR}/pending_tasks.yaml" ]; then
            PENDING_TASKS_REF="
前回の未完了タスクが ${STATUS_DIR}/pending_tasks.yaml に保存されている。読み込んで TaskCreate で再登録せよ。"
        fi

        INIT_PROMPT="前回セッションから再開する。${SHOGUN_ROOT}/instructions/shogun.md と ${SHOGUN_ROOT}/CLAUDE.md を再読せよ。${SHOGUN_ROOT}/config/settings.yaml で言語設定を確認せよ。

環境変数 SHOGUN_ROOT=${SHOGUN_ROOT} が設定済みである。
ダッシュボードのパスは ${DASHBOARD_PATH} である（前回の内容を引き継ぎ済み）。
プロジェクトデータディレクトリは ${SHOGUN_DATA_DIR} である。

TeamCreate でチーム ${TEAM_NAME} を作成し、以下のチームメイトを Task で spawn せよ:
- 家老（karo）: ${SHOGUN_ROOT}/instructions/karo.md を読ませよ。mode は delegate にせよ。
- 目付（metsuke）: ${SHOGUN_ROOT}/instructions/metsuke.md を読ませよ。${ASHIGARU_SPAWN}
${PENDING_TASKS_REF}
全員が起動したら、殿の指示を待て。"

    else
        # ═══════════════════════════════════════════════════════════════════
        # 通常モード: 新規セッション
        # ═══════════════════════════════════════════════════════════════════
        INIT_PROMPT="${SHOGUN_ROOT}/instructions/shogun.md を読んで将軍として起動せよ。${SHOGUN_ROOT}/CLAUDE.md も読め。${SHOGUN_ROOT}/config/settings.yaml で言語設定を確認せよ。

環境変数 SHOGUN_ROOT=${SHOGUN_ROOT} が設定済みである。shogun システムのファイルは全て \$SHOGUN_ROOT 配下にある。
ダッシュボードのパスは ${DASHBOARD_PATH} である。
プロジェクトデータディレクトリは ${SHOGUN_DATA_DIR} である。

TeamCreate でチーム ${TEAM_NAME} を作成し、以下のチームメイトを Task で spawn せよ:
- 家老（karo）: ${SHOGUN_ROOT}/instructions/karo.md を読ませよ。mode は delegate にせよ。
- 目付（metsuke）: ${SHOGUN_ROOT}/instructions/metsuke.md を読ませよ。${ASHIGARU_SPAWN}

次のファイルを読み込んでプロジェクト概要を把握せよ。
CLAUDE.md
${DASHBOARD_PATH}/project_context.md

全員が起動したら、殿の指示を待て。"

    fi

    tmux send-keys -t "${TMUX_SHOGUN}:shogun" "$INIT_PROMPT"
    sleep 2
    tmux send-keys -t "${TMUX_SHOGUN}:shogun" Enter
    if [ "$RESUME_MODE" = true ]; then
        log_success "  └─ 再開指示を送信（前回セッション引き継ぎ）"
    else
        log_success "  └─ チーム構成指示を送信"
    fi
else
    log_info "⚠️  将軍の起動に時間がかかっています"
    log_info "  アタッチ後に手動でチーム構成を指示してください"
fi

echo ""

echo ""
if [ "$RESUME_MODE" = true ]; then
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║  🏯 再出陣完了！前回の陣を引き継ぐ！                     ║"
    echo "  ╚══════════════════════════════════════════════════════════╝"
else
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║  🏯 出陣準備完了！天下布武！                              ║"
    echo "  ╚══════════════════════════════════════════════════════════╝"
fi
echo ""

echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  Agent Teams 方式（tmux モード）                         │"
echo "  │                                                          │"
echo "  │  将軍（${TMUX_SHOGUN}）と配下（${TMUX_MULTIAGENT}）の2陣を構築。"
echo "  │  チーム構成指示を自動送信済み。                          │"
echo "  │  Agent Teams がチームメイトを multiagent に自動配備。    │"
echo "  │                                                          │"
echo "  │  ── 操作方法 ──                                          │"
echo "  │                                                          │"
echo "  │  将軍にアタッチ（指示を出す）:                            │"
echo "  │    .shogun/bin/shogun.sh                                 │"
echo "  │    tmux attach -t ${TMUX_SHOGUN}                        │"
echo "  │                                                          │"
echo "  │  配下にアタッチ（チームメイトを観察）:                    │"
echo "  │    .shogun/bin/multiagent.sh                             │"
echo "  │    tmux attach -t ${TMUX_MULTIAGENT}                    │"
echo "  │                                                          │"
echo "  │  セッション一覧:                                          │"
echo "  │    tmux ls                                               │"
echo "  │  ペイン切替:                                              │"
echo "  │    Ctrl+b → 矢印キー                                    │"
echo "  │  デタッチ（セッションから離脱）:                          │"
echo "  │    Ctrl+b → d                                            │"
echo "  │                                                          │"
echo "  │  撤退:                                                    │"
echo "  │    .shogun/bin/tettai.sh                                 │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
echo "  ════════════════════════════════════════════════════════════"
echo "   天下布武！勝利を掴め！ (Tenka Fubu! Seize victory!)"
echo "  ════════════════════════════════════════════════════════════"
echo ""
