# claude-shogun システム構成

## 概要
claude-shogunは、Claude Code + tmux を使ったマルチエージェント並列開発基盤である。
戦国時代の軍制をモチーフとした階層構造で、複数のプロジェクトを並行管理できる。

## 階層構造

```
人間（会長 / Chairman）
  │
  ▼ 指示
┌──────────────┐
│   SHOGUN     │ ← 将軍（プロジェクト統括）
│   (将軍)     │
└──────┬───────┘
       │ YAMLファイル経由
       ▼
┌──────────────┐
│    KARO      │ ← 家老（タスク管理・分配）
│   (家老)     │
└──────┬───────┘
       │ YAMLファイル経由
       ▼
┌───┬───┬───┬───┬───┬───┬───┬───┐
│A1 │A2 │A3 │A4 │A5 │A6 │A7 │A8 │ ← 足軽（実働部隊）
└───┴───┴───┴───┴───┴───┴───┴───┘
```

## 通信プロトコル

### YAMLファイルベース通信
- tmux send-keys は緊急時以外使用禁止
- 全ての指示・報告はYAMLファイル経由
- ポーリング間隔: Shogun=10秒、Karo/Ashigaru=5秒

### ファイル構成
```
config/projects.yaml          # プロジェクト一覧
status/master_status.yaml     # 全体進捗
queue/shogun_to_karo.yaml     # Shogun → Karo 指示
queue/karo_to_ashigaru.yaml   # Karo → Ashigaru 割当
queue/reports/ashigaru{N}_report.yaml  # Ashigaru → Karo 報告
dashboard.md                  # 人間用ダッシュボード
```

## tmuxセッション構成

### shogunセッション（1ペイン）
- Pane 0: SHOGUN（将軍）

### multiagentセッション（9ペイン）
- Pane 0: karo（家老）
- Pane 1-8: ashigaru1-8（足軽）

## 言葉遣い
本システムでは、戦国風 + 和英併記の言葉遣いを採用する。

- 「はっ！(Ha!)」 - 了解
- 「承知つかまつった(Acknowledged!)」 - 理解した
- 「任務完了でござる(Task completed!)」 - タスク完了
- 「出陣いたす(Deploying!)」 - 作業開始
- 「申し上げます(Reporting!)」 - 報告

## 指示書
- instructions/shogun.md - 将軍の指示書
- instructions/karo.md - 家老の指示書
- instructions/ashigaru.md - 足軽の指示書
