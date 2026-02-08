# Changelog

[yohey-w/multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) の `9e23e2c` からfork。
以降の変更履歴を記す。

## 2026-02-08

- 全スクリプトのパス参照を `SHOGUN_ROOT` 環境変数に統一し、任意のディレクトリから実行可能に

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
