# Changelog

[yohey-w/multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) の `9e23e2c` からfork。
以降の変更履歴を記す。

## 2026-02-26

- **コンパクション耐性向上**: 将軍のコンテキスト圧縮後の性能劣化を防ぐ4施策を導入
  - **作戦立案プロトコル（施策A）**: 非軽微な指示に対し `.shogun/plans/` に作戦書を作成し殿に確認してから家老に委譲する仕組みを追加。計画をファイルとして永続化しコンパクション後の文脈復元に使用
    - `instructions/shogun.md`: YAML workflow を 6→9 step に拡張（triage, create_plan, update_shogun_context を追加）。「作戦立案プロトコル」セクション新設（作戦書テンプレート、WHAT/WHYのみでHOWは家老に委ねるルール）
    - `CLAUDE.md`: 「作戦立案（将軍のみ）」概要セクション追加、ファイル構成に `plans/` ディレクトリ追加
    - `shutsujin_departure.sh`: STEP 5d で `.shogun/plans/` ディレクトリ初期化を追加
  - **自己完結型タスク記述（施策B）**: タスク自体に全情報を含め、コンパクション後でも TaskGet だけで作業可能にする
    - `instructions/shogun.md`: 「自己完結型タスク記述（Shogun → Karo）」セクション新設（背景、殿の指示原文、判断済み事項、作戦書パス、成功基準）
    - `instructions/karo.md`: 「自己完結型タスク記述（Karo → Ashigaru）」セクション新設（目的、背景、作業内容、成果物、参照ファイル、関連教訓、完了条件）
  - **コンテキスト節約（施策C）**: 将軍のコンテキスト膨張を抑制するガイドラインを追加
    - `instructions/shogun.md`: 「コンテキスト節約」セクション新設。大規模探索・技術調査は Task tool サブエージェントに委託し、将軍は統括業務に集中（team_name なしの一時利用は F001 違反ではない旨を明記）
  - **SGATE-1 コンテキスト更新ゲート（施策D）**: TaskCreate/SendMessage(karo) の直前に shogun_context.md 更新を強制
    - `instructions/shogun.md`: 「将軍の状況認識ファイル」セクションを SGATE-1 付きに置換。テンプレートに「現在の作戦書」「直近のアクション」を追加、「殿とのやり取り要約」を廃止
    - `shutsujin_departure.sh`: shogun_context.md 初期テンプレートに「現在の作戦書」「直近のアクション」を追加、「殿とのやり取り要約」を削除

## 2026-02-23

- **教訓管理パイプライン**: タスク完了時に教訓を蓄積し次タスクに自動注入する知識循環を導入（参考: simokitafresh/multi-agent-shogun `cc66473`）
  - `shutsujin_departure.sh`: `.shogun/lessons.md` の初期化処理を追加（存在しない場合のみ作成、resume時は蓄積維持）
  - `instructions/ashigaru.md`: 報告フォーマットに教訓候補（lesson_candidate）を必須検討項目として追加。判断基準テーブルと報告フォーマットを定義
  - `instructions/karo.md`: 教訓管理セクション新設。draft登録→confirmed昇格→新タスクへの注入（最大5件）のライフサイクルを定義
  - `instructions/metsuke.md`: チェック項目に教訓候補の妥当性検証（具体性・再現性・汎用性・カテゴリ適切性）を追加
  - `CLAUDE.md`: 教訓管理パイプラインの概要とライフサイクルを全エージェント必須ルールとして追加
- **タスク完了ゲート**: 3層ゲート構造を導入し品質を体系的に担保（参考: simokitafresh/multi-agent-shogun `cc66473`）
  - `instructions/ashigaru.md`: Layer 1（足軽の自己チェック GATE-1〜4）を追加
  - `instructions/karo.md`: Layer 2（家老のゲートチェック KGATE-1〜3）を追加
  - Layer 3 は既存の目付チェック項目に教訓候補チェックを追加して対応
- **統合矛盾検出プロトコル INTEG-001**: 複数レポート統合時の矛盾検出・解決ルールを定義（参考: saneaki/multi-agent `9ab1e0f`）
  - `CLAUDE.md`: INTEG-001 プロトコル概要（3ステップ、テンプレート一覧、役割分担）を全エージェント必須ルールとして追加
  - `instructions/karo.md`: 統合タスク設計ルール（統合タイプ判断テーブル、TaskCreate description 必須項目）を追加
  - `instructions/ashigaru.md`: 統合タスク実行手順（INTEG-001フロー、Contradiction Resolution セクション必須）を追加
  - `instructions/metsuke.md`: 統合品質チェック項目（矛盾解決記録・一次情報源参照・情報欠落・論理一貫性）を追加
- **upstream マージ** (upstream/main `73c4113`): fork 元が 107 コミット先行していたため、汎用的改善を選択的に取り込み。通信基盤（YAML+mailbox, inbox_watcher, ntfy 等）、Multi-CLI対応（Codex/Copilot）、Dynamic Model Routing は除外。
  - 取り込み（`101e062`, `b01d56b` より）:
    - `.claude/settings.json`: `permissions.deny` 追加。破壊的コマンド（`rm -rf /`, `git push --force`, `tmux kill-server` 等）を物理的に拒否
    - `CLAUDE.md`: 破壊的操作の安全ルール D001-D008（Tier 1 絶対禁止 / Tier 2 停止報告 / Tier 3 安全代替）を追加。WSL2 固有の保護は macOS 用に変更、`inbox_write` は `SendMessage` に読み替え
    - `CLAUDE.md`: バッチ処理プロトコル追加。30+件の大規模処理で batch1 QC ゲート必須化、バッチサイズ制限、品質テンプレート義務化
    - `instructions/shogun.md`: クリティカルシンキング（簡易版 Step 2-3）追加。数値の再計算とランタイムシミュレーションを殿への報告前に必須化
  - 除外: 通信関連（inbox_watcher, ntfy, send-keys, watcher）約43件、Multi-CLI対応約15件、Dynamic Model Routing/Bloom約8件、軍師(gunshi)ロール、generated instructions、CI/CD

## 2026-02-09

- **セッション再開機能**: 撤退後に前回の将軍セッションを引き継いで再出陣できるようにした
  - `shutsujin_departure.sh`: `-r`/`--resume` オプション追加。保存済みセッションIDで `claude --resume <id>` を実行
  - `tettai_retreat.sh`: 通常撤退時に将軍のセッションID（`.jsonl` の UUID）を `.shogun/status/shogun_session_id` に保存。`-f`（強制撤退）時は保存しない
  - resume 時はダッシュボード初期化をスキップ（前回の内容を引き継ぎ）
  - resume 時は未完了タスク（`pending_tasks.yaml`）の再登録を将軍に指示
  - `.shogun/bin/shutsujin.sh` ラッパーが引数をパススルー（`"$@"`）
- **チームメンバー追加禁止ルール**: `CLAUDE.md` にチームメンバーの spawn 制限を追加。将軍のみがメンバーを追加でき、家老・足軽が独自に増やすことを禁止
- **spawn 制限の物理的強制**: PreToolUse フックで家老・足軽のチームメンバー追加を物理的にブロック
  - `scripts/check-team-spawn.sh` 新規作成: `.shogun/` の有無でシステム内外を判定、`SHOGUN_ROLE=shogun` の有無で将軍/チームメイトを区別
  - `scripts/claude-shogun`: `SHOGUN_ROLE=shogun` 環境変数を追加（将軍プロセスのみ）
  - `shutsujin_departure.sh`: 出陣時にフックのシンボリックリンクと `~/.claude/settings.json` への設定追加を自動実行
  - `instructions/karo.md`, `instructions/ashigaru.md`: spawn 禁止ルール（F006, F007）を追加
- **動的グリッドレイアウト**: `scripts/tmux-grid-layout.sh` を新規追加。multiagent セッションのペインをペイン数に応じて自動的にグリッド配置（家老ペイン優遇付き）

## 2026-02-08

- **プロジェクト単位の独立運用**: 複数プロジェクトを並行管理できるよう全スクリプトを改修
  - `scripts/project-env.sh` 新規作成: 共通変数定義（`PROJECT_NAME_SAFE`, `TMUX_SHOGUN`, `TEAM_NAME` 等を WORK_DIR から自動導出）
  - tmux セッション名を `shogun-<project>` / `multiagent-<project>` に変更
  - Agent Teams チーム名を `shogun-team-<project>` に変更
  - `shutsujin_departure.sh`: 作業ディレクトリに `.shogun/` を自動生成（`project.env`, `bin/` ラッパー, ダッシュボード等）
  - `tettai_retreat.sh`: `--project-dir` オプション追加、WORK_DIR 自動発見ロジック
  - `watchdog.sh`: `--project-dir` オプション追加、PID ファイル管理
  - `switch_account.sh`: `project-env.sh` 対応、再起動ロジックを `shutsujin_departure.sh` に統一
  - `shogun.sh`, `multiagent.sh` を削除 → `.shogun/bin/` ラッパーに置き換え
  - `first_setup.sh`: 旧キューファイル初期化を削除（Agent Teams 移行済み）
  - 全スクリプトのパス参照を `SHOGUN_ROOT` 環境変数に統一
- **upstream マージ** (upstream/main `95356d2`): fork 元が 64 コミット先行していたため、汎用的改善を選択的に取り込み。通信基盤が根本的に異なる（upstream: YAML+mailbox vs ours: Agent Teams）ため cherry-pick 方式。
  - 取り込み: `first_setup.sh`（tmux マウス設定、CLI ネイティブ版、shell オプション）、`shutsujin_departure.sh`（pane-base-index）、`instructions/karo.md`（RACE-001、idle 最小化、Bloom 分類、FG ブロック禁止）、`instructions/ashigaru.md`（目的検証、自己識別）、`docs/philosophy.md`（新規、Agent Teams 版に書き換え）、`templates/integ_*.md`（統合テンプレート5ファイル）、`.claude/settings.json`（spinnerVerbs）、`LICENSE`
  - 除外: `scripts/inbox_*.sh`, `scripts/ntfy*.sh`, `saytask/`, `images/screenshots/`（Agent Teams で不要）
  - ours 維持: `CLAUDE.md`, `README.md`, `README_ja.md`, `instructions/shogun.md`, `.gitignore`

## 2026-02-06

- **Agent Teams 完全移行**: YAML + `$NOTIFY_SH` 通信基盤を Agent Teams API（SendMessage, TaskCreate 等）に全面置き換え
- Agent Teams 移行計画ドキュメント（`AGENT_TEAMS_MIGRATION.md`）を追加
- `scripts/claude-shogun`: Claude Code 起動ラッパーを追加、`$NOTIFY_SH` 環境変数によるパス統一
- 将軍を tmux セッション内で正しく起動するよう修正
- 出陣・撤退スクリプトを shogun / multiagent の2セッション構成に改善

## 2026-02-03

- `scripts/notify.sh`: tmux send-keys ラッパースクリプトを追加
- `watchdog.sh`: ダッシュボード更新検知・Limit 検知の監視システムを追加
- `tettai_retreat.sh`: 撤退（終了）スクリプトを追加
- `switch_account.sh`: Claude アカウント切り替えスクリプトを追加
- `instructions/metsuke.md`: 目付（レビュー担当）の指示書を新規作成
- `instructions/ashigaru-checker.md`: 足軽チェック用補助指示書を新規作成
- 既存の指示書（shogun, karo, ashigaru）を大幅拡充
