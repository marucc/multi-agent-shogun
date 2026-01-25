#!/bin/bash
# 🏯 claude-shogun セットアップスクリプト
# Multi-Agent Orchestration System with Samurai Theme

set -e

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

echo ""
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║  🏯 claude-shogun 〜 戦国マルチエージェント統率システム 〜  ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  天下布武！陣立てを開始いたす (Setting up the battlefield)"
echo ""

# STEP 1: 既存セッションクリーンアップ
log_info "🧹 既存の陣を撤収中..."
tmux kill-session -t multiagent 2>/dev/null && log_info "  └─ multiagent陣、撤収完了" || log_info "  └─ multiagent陣は存在せず"
tmux kill-session -t shogun 2>/dev/null && log_info "  └─ shogun本陣、撤収完了" || log_info "  └─ shogun本陣は存在せず"

# 報告ファイルクリア
log_info "📜 前回の軍議記録を破棄中..."
for i in {1..8}; do
    cat > ./queue/reports/ashigaru${i}_report.yaml << EOF
worker_id: ashigaru${i}
task_id: null
timestamp: ""
status: idle
result: null
EOF
done

# キューファイルリセット
cat > ./queue/shogun_to_karo.yaml << 'EOF'
queue: []
EOF

cat > ./queue/karo_to_ashigaru.yaml << 'EOF'
assignments:
  ashigaru1:
    task_id: null
    description: null
    target_path: null
    status: idle
  ashigaru2:
    task_id: null
    description: null
    target_path: null
    status: idle
  ashigaru3:
    task_id: null
    description: null
    target_path: null
    status: idle
  ashigaru4:
    task_id: null
    description: null
    target_path: null
    status: idle
  ashigaru5:
    task_id: null
    description: null
    target_path: null
    status: idle
  ashigaru6:
    task_id: null
    description: null
    target_path: null
    status: idle
  ashigaru7:
    task_id: null
    description: null
    target_path: null
    status: idle
  ashigaru8:
    task_id: null
    description: null
    target_path: null
    status: idle
EOF

log_success "✅ 陣払い完了"
echo ""

# STEP 2: multiagentセッション作成（9ペイン：karo + ashigaru1-8）
log_war "⚔️ 家老・足軽の陣を構築中（9名配備）..."

# 最初のペイン作成
tmux new-session -d -s multiagent -n "agents"

# 3x3グリッド作成（合計9ペイン）
# 最初に3列に分割
tmux split-window -h -t "multiagent:0"
tmux split-window -h -t "multiagent:0"

# 各列を3行に分割
tmux select-pane -t "multiagent:0.0"
tmux split-window -v
tmux split-window -v

tmux select-pane -t "multiagent:0.3"
tmux split-window -v
tmux split-window -v

tmux select-pane -t "multiagent:0.6"
tmux split-window -v
tmux split-window -v

# ペインタイトル設定（0: karo, 1-8: ashigaru1-8）
PANE_TITLES=("karo" "ashigaru1" "ashigaru2" "ashigaru3" "ashigaru4" "ashigaru5" "ashigaru6" "ashigaru7" "ashigaru8")
PANE_COLORS=("1;31" "1;34" "1;34" "1;34" "1;34" "1;34" "1;34" "1;34" "1;34")  # karo: 赤, ashigaru: 青

for i in {0..8}; do
    tmux select-pane -t "multiagent:0.$i" -T "${PANE_TITLES[$i]}"
    tmux send-keys -t "multiagent:0.$i" "cd $(pwd)" C-m
    tmux send-keys -t "multiagent:0.$i" "export PS1='(\[\033[${PANE_COLORS[$i]}m\]${PANE_TITLES[$i]}\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ '" C-m
    tmux send-keys -t "multiagent:0.$i" "echo ''" C-m
    tmux send-keys -t "multiagent:0.$i" "echo '╔════════════════════════════════════╗'" C-m
    tmux send-keys -t "multiagent:0.$i" "echo '║  ${PANE_TITLES[$i]} 参上！出陣の用意完了  ║'" C-m
    tmux send-keys -t "multiagent:0.$i" "echo '╚════════════════════════════════════╝'" C-m
done

log_success "  └─ 家老・足軽の陣、構築完了"
echo ""

# STEP 3: shogunセッション作成（1ペイン）
log_war "👑 将軍の本陣を構築中..."
tmux new-session -d -s shogun
tmux send-keys -t shogun "cd $(pwd)" C-m
tmux send-keys -t shogun "export PS1='(\[\033[1;35m\]将軍\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ '" C-m
tmux send-keys -t shogun "echo ''" C-m
tmux send-keys -t shogun "echo '╔═══════════════════════════════════════════╗'" C-m
tmux send-keys -t shogun "echo '║     🏯 将 軍 御 座 所 (SHOGUN HQ) 🏯      ║'" C-m
tmux send-keys -t shogun "echo '║                                           ║'" C-m
tmux send-keys -t shogun "echo '║       天下統一の時は近い                  ║'" C-m
tmux send-keys -t shogun "echo '║       The time for unification is near    ║'" C-m
tmux send-keys -t shogun "echo '╚═══════════════════════════════════════════╝'" C-m

log_success "  └─ 将軍の本陣、構築完了"
echo ""

# STEP 4: 環境確認・表示
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
echo "     【multiagentセッション】家老・足軽の陣（3x3 = 9ペイン）"
echo "     ┌─────────┬─────────┬─────────┐"
echo "     │  karo   │ashigaru3│ashigaru6│"
echo "     │  (家老) │ (足軽3) │ (足軽6) │"
echo "     ├─────────┼─────────┼─────────┤"
echo "     │ashigaru1│ashigaru4│ashigaru7│"
echo "     │ (足軽1) │ (足軽4) │ (足軽7) │"
echo "     ├─────────┼─────────┼─────────┤"
echo "     │ashigaru2│ashigaru5│ashigaru8│"
echo "     │ (足軽2) │ (足軽5) │ (足軽8) │"
echo "     └─────────┴─────────┴─────────┘"
echo ""

echo ""
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║  🏯 陣立て完了！いざ出陣！(Ready for battle!)            ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  📜 出陣の手順 (Deployment Steps)                        │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
echo "  【壱】陣に参上せよ (Attach to sessions)"
echo "     tmux attach-session -t shogun       # 将軍の本陣へ"
echo "     tmux attach-session -t multiagent   # 家老・足軽の陣へ"
echo ""
echo "  【弐】Claude Codeを召喚せよ (Summon Claude Code)"
echo "     # まず将軍を召喚"
echo "     tmux send-keys -t shogun 'claude --dangerously-skip-permissions' C-m"
echo ""
echo "     # 続いて家老・足軽を一斉召喚"
echo "     for i in {0..8}; do tmux send-keys -t multiagent:0.\$i 'claude --dangerously-skip-permissions' C-m; done"
echo ""
echo "  【参】指示書を確認せよ (Check instruction scrolls)"
echo "     将軍: instructions/shogun.md"
echo "     家老: instructions/karo.md"
echo "     足軽: instructions/ashigaru.md"
echo ""
echo "  【肆】出陣を命ぜよ (Give the order)"
echo "     将軍に申し付けよ：「汝は将軍なり。instructions/shogun.mdを読み、指示に従え」"
echo ""
echo "  ════════════════════════════════════════════════════════════"
echo "   天下布武！勝利を掴め！ (Tenka Fubu! Seize victory!)"
echo "  ════════════════════════════════════════════════════════════"
echo ""
