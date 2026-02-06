#!/bin/bash
# 🏯 multi-agent-shogun 出陣スクリプト（毎日の起動用）
# Daily Deployment Script for Multi-Agent Orchestration System
#
# 使用方法:
#   ./shutsujin_departure.sh           # 全エージェント起動（通常）
#   ./shutsujin_departure.sh -s        # セットアップのみ（Claude起動なし）
#   ./shutsujin_departure.sh -h        # ヘルプ表示

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 言語設定を読み取り（デフォルト: ja）
LANG_SETTING="ja"
if [ -f "./config/settings.yaml" ]; then
    LANG_SETTING=$(grep "^language:" ./config/settings.yaml 2>/dev/null | awk '{print $2}' || echo "ja")
fi

# 足軽数を読み取り（デフォルト: 3）
ASHIGARU_COUNT=3
if [ -f "./config/settings.yaml" ]; then
    ASHIGARU_COUNT=$(grep "^ashigaru_count:" ./config/settings.yaml 2>/dev/null | awk '{print $2}' || echo "3")
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
SETUP_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--setup-only)
            SETUP_ONLY=true
            shift
            ;;
        -h|--help)
            echo ""
            echo "🏯 multi-agent-shogun 出陣スクリプト"
            echo ""
            echo "使用方法: ./shutsujin_departure.sh [オプション]"
            echo ""
            echo "オプション:"
            echo "  -s, --setup-only  tmuxセッションのセットアップのみ（Claude起動なし）"
            echo "  -t, --terminal    Windows Terminal で新しいタブを開く"
            echo "  -h, --help        このヘルプを表示"
            echo ""
            echo "例:"
            echo "  ./shutsujin_departure.sh      # 全エージェント起動（通常の出陣）"
            echo "  ./shutsujin_departure.sh -s   # セットアップのみ（手動でClaude起動）"
            echo "  ./shutsujin_departure.sh -t   # 全エージェント起動 + ターミナルタブ展開"
            echo ""
            echo "エイリアス:"
            echo "  csst  → cd /mnt/c/tools/multi-agent-shogun && ./shutsujin_departure.sh"
            echo "  css   → tmux attach-session -t shogun"
            echo "  csm   → tmux attach-session -t multiagent"
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
    echo -e "\033[1;33m  ┃\033[0m  \033[1;37m🏯 multi-agent-shogun\033[0m  〜 \033[1;36m戦国マルチエージェント統率システム\033[0m 〜           \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m                                                                           \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m    \033[1;35m将軍\033[0m: 統括  \033[1;31m家老\033[0m: 管理  \033[1;32m目付\033[0m: 品質保証  \033[1;34m足軽\033[0m×$ASHIGARU_COUNT: 実働      \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"
    echo ""
}

# バナー表示実行
show_battle_cry

echo -e "  \033[1;33m天下布武！陣立てを開始いたす\033[0m (Setting up the battlefield)"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: 既存セッションクリーンアップ
# ═══════════════════════════════════════════════════════════════════════════════
log_info "🧹 既存の陣を撤収中..."
tmux kill-session -t multiagent 2>/dev/null && log_info "  └─ multiagent陣、撤収完了" || log_info "  └─ multiagent陣は存在せず"
tmux kill-session -t shogun 2>/dev/null && log_info "  └─ shogun本陣、撤収完了" || log_info "  └─ shogun本陣は存在せず"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1.5: 前回記録のバックアップ（内容がある場合のみ）
# ═══════════════════════════════════════════════════════════════════════════════
BACKUP_DIR="./logs/backup_$(date '+%Y%m%d_%H%M%S')"
NEED_BACKUP=false

if [ -f "./dashboard.md" ]; then
    if grep -q "cmd_" "./dashboard.md" 2>/dev/null; then
        NEED_BACKUP=true
    fi
fi

if [ "$NEED_BACKUP" = true ]; then
    mkdir -p "$BACKUP_DIR" || true
    cp "./dashboard.md" "$BACKUP_DIR/" 2>/dev/null || true
    cp -r "./queue/reports" "$BACKUP_DIR/" 2>/dev/null || true
    cp -r "./queue/tasks" "$BACKUP_DIR/" 2>/dev/null || true
    cp "./queue/shogun_to_karo.yaml" "$BACKUP_DIR/" 2>/dev/null || true
    log_info "📦 前回の記録をバックアップ: $BACKUP_DIR"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: 報告ファイルリセット
# ═══════════════════════════════════════════════════════════════════════════════
log_info "📜 前回の軍議記録を破棄中..."

# queue ディレクトリが存在しない場合は作成
[ -d ./queue/reports ] || mkdir -p ./queue/reports
[ -d ./queue/tasks ] || mkdir -p ./queue/tasks

# 足軽タスクファイルリセット
for i in $(seq 1 $ASHIGARU_COUNT); do
    cat > ./queue/tasks/ashigaru${i}.yaml << EOF
# 足軽${i}専用タスクファイル
task:
  task_id: null
  parent_cmd: null
  description: null
  target_path: null
  status: idle
  timestamp: ""
EOF
done

# 足軽レポートファイルリセット
for i in $(seq 1 $ASHIGARU_COUNT); do
    cat > ./queue/reports/ashigaru${i}_report.yaml << EOF
worker_id: ashigaru${i}
task_id: null
timestamp: ""
status: idle
result: null
EOF
done

# 目付タスクファイルリセット
cat > ./queue/tasks/metsuke.yaml << 'EOF'
# 目付専用タスクファイル
# 家老（karo）が目付（metsuke）に検証を依頼する際に使用

task:
  task_id: null
  parent_cmd: null
  description: null
  check_targets: []  # チェック対象のashigaru報告ファイルリスト（例: ["queue/reports/ashigaru1_report.yaml"]）
  status: idle  # idle | assigned | checking | done
  timestamp: ""
EOF

# 目付レポートファイルリセット
cat > ./queue/reports/metsuke_report.yaml << 'EOF'
# 目付の報告ファイル
# 目付（metsuke）が家老（karo）に検証結果を報告する際に使用

worker_id: metsuke
task_id: null
timestamp: ""
status: idle  # idle | checking | done
result:
  summary: null
  check_results: []  # 4項目のチェック結果（code_quality, instruction_consistency, asset_consistency, completeness）
  issues: []  # 発見した問題のリスト
  action: null  # approved | needs_rework | needs_clarification
EOF

# キューファイルリセット
cat > ./queue/shogun_to_karo.yaml << 'EOF'
queue: []
EOF

# karo_to_ashigaru.yaml を動的生成
{
    echo "assignments:"
    for i in $(seq 1 $ASHIGARU_COUNT); do
        cat << EOF
  ashigaru${i}:
    task_id: null
    description: null
    target_path: null
    status: idle
EOF
    done
} > ./queue/karo_to_ashigaru.yaml

log_success "✅ 陣払い完了"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: ダッシュボード初期化
# ═══════════════════════════════════════════════════════════════════════════════
log_info "📊 戦況報告板を初期化中..."
TIMESTAMP=$(date "+%Y-%m-%d %H:%M")

if [ "$LANG_SETTING" = "ja" ]; then
    # 日本語のみ
    cat > ./dashboard.md << EOF
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
    # 日本語 + 翻訳併記
    cat > ./dashboard.md << EOF
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

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: multiagentセッション作成（9ペイン：karo + ashigaru1-8）
# ═══════════════════════════════════════════════════════════════════════════════
# tmux の存在確認
if ! command -v tmux &> /dev/null; then
    echo ""
    echo "  ╔════════════════════════════════════════════════════════╗"
    echo "  ║  [ERROR] tmux not found!                              ║"
    echo "  ║  tmux が見つかりません                                 ║"
    echo "  ╠════════════════════════════════════════════════════════╣"
    echo "  ║  Run first_setup.sh first:                            ║"
    echo "  ║  まず first_setup.sh を実行してください:               ║"
    echo "  ║     ./first_setup.sh                                  ║"
    echo "  ╚════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

log_war "⚔️ 家老・目付・足軽の陣を構築中（$((ASHIGARU_COUNT + 2))名配備）..."

# 最初のペイン作成
if ! tmux new-session -d -s multiagent -n "agents" 2>/dev/null; then
    echo ""
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║  [ERROR] Failed to create tmux session 'multiagent'      ║"
    echo "  ║  tmux セッション 'multiagent' の作成に失敗しました       ║"
    echo "  ╠════════════════════════════════════════════════════════════╣"
    echo "  ║  An existing session may be running.                     ║"
    echo "  ║  既存セッションが残っている可能性があります              ║"
    echo "  ║                                                          ║"
    echo "  ║  Check: tmux ls                                          ║"
    echo "  ║  Kill:  tmux kill-session -t multiagent                  ║"
    echo "  ╚════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

# 動的ペイン作成（karo + metsuke + 足軽N名 = N+2 ペイン）
TOTAL_PANES=$((ASHIGARU_COUNT + 2))

# 必要な数だけペインを分割
for i in $(seq 2 $TOTAL_PANES); do
    tmux split-window -t "multiagent:0"
    tmux select-layout -t "multiagent:0" tiled  # 自動的に均等配置
done

# ペインタイトルと色を動的に設定（notify.sh でコマンド送信）
# Pane 0: karo（赤）, Pane 1: metsuke（緑）, Pane 2以降: ashigaru（青）
tmux select-pane -t "multiagent:0.0" -T "karo"
./scripts/notify.sh "multiagent:0.0" "cd \"$(pwd)\" && export PS1='(\[\033[1;31m\]karo\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ ' && clear"

tmux select-pane -t "multiagent:0.1" -T "metsuke"
./scripts/notify.sh "multiagent:0.1" "cd \"$(pwd)\" && export PS1='(\[\033[1;32m\]metsuke\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ ' && clear"

for i in $(seq 1 $ASHIGARU_COUNT); do
    PANE_INDEX=$((i + 1))  # metsukeが0.1なので、ashigaru1は0.2から
    PANE_TITLE="ashigaru$i"
    tmux select-pane -t "multiagent:0.$PANE_INDEX" -T "$PANE_TITLE"
    ./scripts/notify.sh "multiagent:0.$PANE_INDEX" "cd \"$(pwd)\" && export PS1='(\[\033[1;34m\]$PANE_TITLE\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ ' && clear"
done

log_success "  └─ 家老・目付・足軽の陣、構築完了"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: shogunセッション作成（1ペイン）
# ═══════════════════════════════════════════════════════════════════════════════
log_war "👑 将軍の本陣を構築中..."
if ! tmux new-session -d -s shogun 2>/dev/null; then
    echo ""
    echo "  ╔════════════════════════════════════════════════════════════╗"
    echo "  ║  [ERROR] Failed to create tmux session 'shogun'          ║"
    echo "  ║  tmux セッション 'shogun' の作成に失敗しました           ║"
    echo "  ╠════════════════════════════════════════════════════════════╣"
    echo "  ║  An existing session may be running.                     ║"
    echo "  ║  既存セッションが残っている可能性があります              ║"
    echo "  ║                                                          ║"
    echo "  ║  Check: tmux ls                                          ║"
    echo "  ║  Kill:  tmux kill-session -t shogun                      ║"
    echo "  ╚════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi
./scripts/notify.sh "shogun" "cd \"$(pwd)\" && export PS1='(\[\033[1;35m\]将軍\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ ' && clear"

log_success "  └─ 将軍の本陣、構築完了"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: Claude Code 起動（--setup-only でスキップ）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$SETUP_ONLY" = false ]; then
    # Claude Code CLI の存在チェック
    if ! command -v claude &> /dev/null; then
        log_info "⚠️  claude コマンドが見つかりません"
        echo "  first_setup.sh を再実行してください:"
        echo "    ./first_setup.sh"
        exit 1
    fi

    log_war "👑 全軍に Claude Code を召喚中..."

    # 将軍（notify.sh でコマンド送信 + Enter自動付与）
    ./scripts/notify.sh "shogun" "MAX_THINKING_TOKENS=0 ./scripts/claude-shogun --model opus --dangerously-skip-permissions"
    log_info "  └─ 将軍、召喚完了"

    # 少し待機（安定のため）
    sleep 1

    # 家老 + 目付 + 足軽（動的ペイン数: N+2）
    MULTIAGENT_PANES=$((ASHIGARU_COUNT + 1))  # 0始まりなので+1（karo, metsuke, ashigaru1-N）
    for i in $(seq 0 $MULTIAGENT_PANES); do
        ./scripts/notify.sh "multiagent:0.$i" "./scripts/claude-shogun --dangerously-skip-permissions"
    done
    log_info "  └─ 家老・目付・足軽、召喚完了"

    log_success "✅ 全軍 Claude Code 起動完了"
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    # STEP 6.5: 各エージェントに指示書を読み込ませる
    # ═══════════════════════════════════════════════════════════════════════════
    log_war "📜 各エージェントに指示書を読み込ませ中..."
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    # 忍者戦士（syntax-samurai/ryu - CC0 1.0 Public Domain）
    # ═══════════════════════════════════════════════════════════════════════════
    echo "  Claude Code の起動を待機中（最大30秒）..."

    # 将軍の起動を確認（最大30秒待機）
    for i in {1..30}; do
        if tmux capture-pane -t shogun -p | grep -q "bypass permissions"; then
            echo "  └─ 将軍の Claude Code 起動確認完了（${i}秒）"
            break
        fi
        sleep 1
    done

    # 将軍に指示書を読み込ませる（notify.sh でメッセージ送信 + Enter自動付与）
    log_info "  └─ 将軍に指示書を伝達中..."
    ./scripts/notify.sh "shogun" "instructions/shogun.md を読んで役割を理解せよ。"

    # 家老に指示書を読み込ませる
    sleep 2
    log_info "  └─ 家老に指示書を伝達中..."
    ./scripts/notify.sh "multiagent:0.0" "instructions/karo.md を読んで役割を理解せよ。"

    # 目付に指示書を読み込ませる
    sleep 2
    log_info "  └─ 目付に指示書を伝達中..."
    ./scripts/notify.sh "multiagent:0.1" "instructions/metsuke.md を読んで役割を理解せよ。"

    # 足軽に指示書を読み込ませる（動的）
    sleep 2
    log_info "  └─ 足軽に指示書を伝達中..."
    for i in $(seq 1 $ASHIGARU_COUNT); do
        PANE_INDEX=$((i + 1))  # metsukeが0.1なので、ashigaru1は0.2から
        ./scripts/notify.sh "multiagent:0.$PANE_INDEX" "instructions/ashigaru.md を読んで役割を理解せよ。汝は足軽${i}号である。"
        sleep 0.5
    done

    log_success "✅ 全軍に指示書伝達完了"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 7: 環境確認・完了メッセージ
# ═══════════════════════════════════════════════════════════════════════════════
log_info "🔍 陣容を確認中..."
echo ""
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  📺 Tmux陣容 (Sessions)                                  │"
echo "  └──────────────────────────────────────────────────────────┘"
tmux list-sessions | sed 's/^/     /'
echo ""
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  📋 布陣図 (Formation)                                   │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
echo "     【shogunセッション】将軍の本陣"
echo "     ┌─────────────────────────────┐"
echo "     │  Pane 0: 将軍 (SHOGUN)      │  ← 総大将・プロジェクト統括"
echo "     └─────────────────────────────┘"
echo ""
echo "     【multiagentセッション】家老・目付・足軽の陣（$((ASHIGARU_COUNT + 2))ペイン）"
echo "     ┌───────────────────────────────────────┐"
echo "     │  Pane 0: karo (家老) ← タスク管理     │"
echo "     │  Pane 1: metsuke (目付) ← 品質保証   │"
for i in $(seq 1 $ASHIGARU_COUNT); do
    PANE_INDEX=$((i + 1))
    echo "     │  Pane $PANE_INDEX: ashigaru$i (足軽$i)            │"
done
echo "     └───────────────────────────────────────┘"
echo "     ※ tmux tiled レイアウトで自動配置"
echo ""

echo ""
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║  🏯 出陣準備完了！天下布武！                              ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo ""

if [ "$SETUP_ONLY" = true ]; then
    echo "  ⚠️  セットアップのみモード: Claude Codeは未起動です"
    echo ""
    echo "  手動でClaude Codeを起動するには:"
    echo "  ┌──────────────────────────────────────────────────────────┐"
    echo "  │  # 将軍を召喚                                            │"
    echo "  │  ./scripts/notify.sh shogun 'claude --dangerously-skip-permissions'    │"
    echo "  │                                                          │"
    echo "  │  # 家老・足軽を一斉召喚                                   │"
    echo "  │  for i in \$(seq 0 $ASHIGARU_COUNT); do                            │"
    echo "  │    ./scripts/notify.sh multiagent:0.\$i \\                │"
    echo "  │      'claude --dangerously-skip-permissions'             │"
    echo "  │  done                                                    │"
    echo "  └──────────────────────────────────────────────────────────┘"
    echo ""
fi

echo "  次のステップ:"
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  将軍の本陣にアタッチして命令を開始:                      │"
echo "  │     tmux attach-session -t shogun   (または: css)        │"
echo "  │                                                          │"
echo "  │  家老・足軽の陣を確認する:                                │"
echo "  │     tmux attach-session -t multiagent   (または: csm)    │"
echo "  │                                                          │"
echo "  │  ※ 各エージェントは指示書を読み込み済み。                 │"
echo "  │    すぐに命令を開始できます。                             │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
echo "  ════════════════════════════════════════════════════════════"
echo "   天下布武！勝利を掴め！ (Tenka Fubu! Seize victory!)"
echo "  ════════════════════════════════════════════════════════════"
echo ""

$SCRIPT_DIR/watchdog.sh
