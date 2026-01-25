#!/bin/bash
# 🏯 claude-shogun セットアップスクリプト
# Multi-Agent Orchestration System with Samurai Theme

set -e

# 色付きログ関数
log_info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;34m[SUCCESS]\033[0m $1"
}

echo "🏯 claude-shogun 陣立て開始 (Setting up the battlefield)"
echo "=========================================================="
echo ""

# STEP 1: 既存セッションクリーンアップ
log_info "🧹 既存の陣を片付けております (Cleaning up existing sessions)..."
tmux kill-session -t multiagent 2>/dev/null && log_info "multiagentセッション削除完了" || log_info "multiagentセッションは存在しませんでした"
tmux kill-session -t shogun 2>/dev/null && log_info "shogunセッション削除完了" || log_info "shogunセッションは存在しませんでした"

# 報告ファイルクリア
log_info "📜 報告書を片付けております (Clearing reports)..."
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

log_success "✅ 片付け完了 (Cleanup complete)"
echo ""

# STEP 2: multiagentセッション作成（9ペイン：karo1 + ashigaru1-8）
log_info "⚔️ 足軽・家老の陣を構築中 (Creating multiagent session - 9 panes)..."

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
    tmux send-keys -t "multiagent:0.$i" "echo '=== ${PANE_TITLES[$i]} 参上 (${PANE_TITLES[$i]} reporting for duty) ==='" C-m
done

log_success "✅ 足軽・家老の陣、構築完了 (Multiagent session created)"
echo ""

# STEP 3: shogunセッション作成（1ペイン）
log_info "👑 将軍の本陣を構築中 (Creating shogun session)..."
tmux new-session -d -s shogun
tmux send-keys -t shogun "cd $(pwd)" C-m
tmux send-keys -t shogun "export PS1='(\[\033[1;35m\]SHOGUN\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ '" C-m
tmux send-keys -t shogun "echo '=== 将軍 御座所 (SHOGUN Headquarters) ==='" C-m
tmux send-keys -t shogun "echo '天下統一の時は近い (The time for unification is near)'" C-m
tmux send-keys -t shogun "echo '=========================================='" C-m

log_success "✅ 将軍の本陣、構築完了 (Shogun session created)"
echo ""

# STEP 4: 環境確認・表示
log_info "🔍 陣容を確認中 (Verifying setup)..."
echo ""
echo "📊 陣立て完了 (Setup Complete):"
echo "================================"
echo ""
echo "📺 Tmux Sessions:"
tmux list-sessions
echo ""
echo "📋 陣容 (Formation):"
echo "  multiagentセッション（9ペイン）:"
echo "    Pane 0: karo       (家老 - Field Commander)"
echo "    Pane 1: ashigaru1  (足軽1 - Infantry 1)"
echo "    Pane 2: ashigaru2  (足軽2 - Infantry 2)"
echo "    Pane 3: ashigaru3  (足軽3 - Infantry 3)"
echo "    Pane 4: ashigaru4  (足軽4 - Infantry 4)"
echo "    Pane 5: ashigaru5  (足軽5 - Infantry 5)"
echo "    Pane 6: ashigaru6  (足軽6 - Infantry 6)"
echo "    Pane 7: ashigaru7  (足軽7 - Infantry 7)"
echo "    Pane 8: ashigaru8  (足軽8 - Infantry 8)"
echo ""
echo "  shogunセッション（1ペイン）:"
echo "    Pane 0: SHOGUN     (将軍 - Supreme Commander)"
echo ""

log_success "🏯 陣立て完了！いざ出陣！ (Setup complete! Ready for battle!)"
echo ""
echo "📋 次の一手 (Next Steps):"
echo "  1. 🔗 陣に入る (Attach to sessions):"
echo "     tmux attach-session -t multiagent   # 足軽・家老の陣"
echo "     tmux attach-session -t shogun       # 将軍の本陣"
echo ""
echo "  2. 🤖 Claude Code 起動:"
echo "     # 将軍から先に起動"
echo "     tmux send-keys -t shogun 'claude --dangerously-skip-permissions' C-m"
echo "     # 次に家老・足軽を一括起動"
echo "     for i in {0..8}; do tmux send-keys -t multiagent:0.\$i 'claude --dangerously-skip-permissions' C-m; done"
echo ""
echo "  3. 📜 指示書:"
echo "     SHOGUN: instructions/shogun.md"
echo "     Karo: instructions/karo.md"
echo "     Ashigaru: instructions/ashigaru.md"
echo ""
echo "  4. 🎯 出陣: SHOGUNに「汝は将軍なり。instructions/shogun.mdを読み、指示に従え」と申し付けよ"
