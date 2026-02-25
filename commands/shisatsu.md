# /shisatsu - 視察コマンド

将軍が家老以下の状態を一括確認する。

## 実行手順

### 0. セッション名を取得

project.env からセッション名を取得する:

```bash
source .shogun/project.env
echo "SESSION: ${TMUX_MULTIAGENT}"
```

以降のコマンドで `${TMUX_MULTIAGENT}` の値を使う。

### 1. 全ペインの状態を取得

各ペインを **個別の Bash 呼び出し** で取得する（パイプの問題回避）:

```bash
tmux capture-pane -t ${TMUX_MULTIAGENT}:0.0 -p 2>/dev/null | tail -15
```
```bash
tmux capture-pane -t ${TMUX_MULTIAGENT}:0.1 -p 2>/dev/null | tail -15
```
```bash
tmux capture-pane -t ${TMUX_MULTIAGENT}:0.2 -p 2>/dev/null | tail -10
```
```bash
tmux capture-pane -t ${TMUX_MULTIAGENT}:0.3 -p 2>/dev/null | tail -10
```
```bash
tmux capture-pane -t ${TMUX_MULTIAGENT}:0.4 -p 2>/dev/null | tail -10
```
```bash
tmux capture-pane -t ${TMUX_MULTIAGENT}:0.5 -p 2>/dev/null | tail -10
```
```bash
tmux capture-pane -t ${TMUX_MULTIAGENT}:0.6 -p 2>/dev/null | tail -10
```
```bash
tmux capture-pane -t ${TMUX_MULTIAGENT}:0.7 -p 2>/dev/null | tail -10
```

### 2. 状態を判定

各ペインの出力から状態を判定:

| 表示内容 | 状態 |
|----------|------|
| `❯` が末尾 | idle（待機中） |
| `thinking` | busy（処理中） |
| `Esc to interrupt` | busy（処理中） |
| `Effecting…` | busy（処理中） |
| `Boondoggling…` | busy（処理中） |
| `Puzzling…` | busy（処理中） |

### 3. タスクリストを確認

Agent Teams の TaskList で未完了タスクを確認する:

```
TaskList
```

タスクの状態を確認:
- `pending` + owner あり → 割当済みだが未着手
- `in_progress` → 作業中
- `completed` → 完了済み
- `pending` + owner なし → 未割当

### 4. dashboard.md を確認

dashboard.md の最新状態を読む:

```bash
Read .shogun/dashboard.md
```

### 5. 視察結果を報告

以下の形式で報告:

```
【視察報告】

■ エージェント状態（tmux）
| 役職 | 状態 | 備考 |
|------|------|------|
| 家老 | idle | 待機中 |
| 目付 | idle | 待機中 |
| 足軽1 | busy | 処理中 |
| 足軽2 | idle | 待機中 |
| 足軽3 | (不在) | - |

■ タスク状況（TaskList）
| ID | 内容 | 担当 | 状態 |
|----|------|------|------|
| 1 | XXXの実装 | ashigaru1 | in_progress |
| 2 | YYYの検証 | metsuke | pending |

■ dashboard.md
- 最終更新: YYYY-MM-DD HH:MM
- 進行中: ...

■ 異常検知
- なし（または検知内容）
```

## 異常検知パターン

以下の場合は警告を出す:

1. **タスク滞留**: TaskList で in_progress だが対応する足軽ペインが idle
2. **状態不整合**: dashboard.md の「進行中」と TaskList の状態が異なる
3. **長時間処理**: 同じ状態が長時間続いている（要確認）
4. **未割当タスク**: pending で owner なしのタスクが残っている

## 使用タイミング

- セッション開始時
- 長時間経過後
- 応答がない時
- 撤退前の確認
