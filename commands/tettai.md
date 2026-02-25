# /tettai - 撤退コマンド

全エージェントの状態を保存し、安全に撤退する。
次回起動時に状態を復元できる。

## 実行手順

### 0. セッション名を取得

```bash
source .shogun/project.env
```

### 1. 現在時刻を取得

```bash
date "+%Y-%m-%dT%H:%M:%S"
```

### 2. 各エージェントの状態をスキャン

```bash
# 家老の状態
tmux capture-pane -t ${TMUX_MULTIAGENT}:0.0 -p | tail -10

# 目付の状態
tmux capture-pane -t ${TMUX_MULTIAGENT}:0.1 -p | tail -10

# 足軽の状態（存在するペインのみ）
for i in 2 3 4 5; do
  tmux capture-pane -t ${TMUX_MULTIAGENT}:0.$i -p 2>/dev/null | tail -5
done
```

### 3. タスクリストを確認

Agent Teams の TaskList で未完了タスクを確認する:

```
TaskList
```

### 4. shogun_context.md を更新

撤退前に将軍の状況認識を最新化する（再開時の復帰に使用）:

`.shogun/status/shogun_context.md` に以下を書き込む:

```markdown
# 将軍の状況認識
最終更新: {取得した時刻}

## 殿からの現在の指示
（現在進行中の殿の指示を記載）

## 家老への指示状況
- タスクID: X — 内容 — 状態（指示済み/進行中/完了）

## 待ち状態
（何を待っているか）

## 判断メモ
（重要な判断とその理由）

## 殿とのやり取り要約
（直近の重要なやり取り）
```

### 5. 未完了タスクを保存

TaskList の結果から未完了タスク（pending / in_progress）を `.shogun/status/pending_tasks.yaml` に保存:

```yaml
pending_tasks:
  timestamp: "{取得した時刻}"
  tasks:
    - task_id: 1
      subject: "XXXの実装"
      owner: ashigaru1
      status: in_progress
    - task_id: 2
      subject: "YYYの検証"
      owner: metsuke
      status: pending
```

### 6. 撤退スクリプトを実行

```bash
source .shogun/project.env && "${SHOGUN_ROOT}/tettai_retreat.sh"
```

### 7. 保存完了を報告

```
撤退準備完了。以下を保存した:
- .shogun/status/shogun_context.md（将軍の状況認識）
- .shogun/status/pending_tasks.yaml（未完了タスク）

次回起動時:
  .shogun/bin/shutsujin.sh --resume

さらば！
```

## 復帰時の手順

再出陣時（`shutsujin.sh --resume`）に以下が自動で行われる:

1. `.shogun/status/shogun_context.md` を読んで状況を復帰
2. `.shogun/status/pending_tasks.yaml` から未完了タスクを TaskCreate で再登録
3. dashboard.md は前回のものを引き継ぎ

## 注意事項

- 撤退前に `/shisatsu` で状態を確認すること（処理中のエージェントがいないか）
- 未コミット変更がある場合は警告を出す
- 家老以下が処理中の場合は完了を待つか、状態を記録して撤退
