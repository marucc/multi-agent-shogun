# /jintate - 陣立て直し

全軍のコンテキストをコンパクトし、ロール（役割指示）を再注入する。
戦の最中に陣形を整え直す命令。

## 実行手順

### 1. 殿に確認

以下を殿に確認する:

- **対象**: 全軍か、将軍のみか？
  - **全軍**: 全エージェントにコンパクト＋ロール再注入
  - **将軍のみ**: 将軍だけロール再読み込み＋状況復帰（配下はそのまま）
- **コンパクト**（全軍の場合）: 各エージェントの `/compact` を実行するか？（コンテキスト圧縮）
  - 実行する場合: それまでの作業の細かい経緯は圧縮される
  - 実行しない場合: ロール再注入のみ

**「将軍のみ」が選ばれた場合 → ステップ 3 のみ実行して完了。**

### 2. コンパクト送信（コンパクトありの場合）

compact_team.sh で全ペインに `/compact` を一斉送信する。
スクリプトは送信のみで即終了する（完了待ちしない）。

```bash
source .shogun/project.env && bash ${WORK_DIR}/.shogun/bin/compact_team.sh
```

**確認のみ（dry-run）**の場合:
```bash
source .shogun/project.env && bash ${WORK_DIR}/.shogun/bin/compact_team.sh --dry-run
```

### 3. 将軍自身のロール再読み込み

以下を順に読み直す:

1. `${SHOGUN_ROOT}/instructions/shogun.md` — 将軍の指示書
2. `${SHOGUN_ROOT}/CLAUDE.md` — 全体ルール
3. `.shogun/status/shogun_context.md` — 将軍の状況認識（コンパクション前に自分が書いた状態メモ）
4. `.shogun/dashboard.md` — 現在の戦況
5. `TaskList` — 全タスクの進捗

**「将軍のみ」モードの場合はここで完了。** 以下を殿に報告:

```
【将軍ロール再注入完了】

■ 読み込み済み
- instructions/shogun.md ✅
- CLAUDE.md ✅
- shogun_context.md ✅ / なし
- dashboard.md ✅
- TaskList ✅

■ 現在の状況認識
（shogun_context.md と dashboard.md から要約）

陣形を整え直した。引き続き参る。
```

### 4. Agent Teams でロール再注入を指示

SendMessage で各エージェントにロール再読み込みを指示する。
Agent Teams の機能で完了を把握できる。

```
# 家老
SendMessage(type="message", recipient="karo", content="コンパクション復帰手順を実行せよ。以下を読み直し、ロールを再確認せよ:\n1. ${SHOGUN_ROOT}/instructions/karo.md\n2. ${SHOGUN_ROOT}/CLAUDE.md\n3. TaskList で現在のタスクを確認\n完了したら報告せよ。", summary="ロール再注入指示")

# 目付
SendMessage(type="message", recipient="metsuke", content="コンパクション復帰手順を実行せよ。以下を読み直し、ロールを再確認せよ:\n1. ${SHOGUN_ROOT}/instructions/metsuke.md\n2. ${SHOGUN_ROOT}/CLAUDE.md\n3. TaskList で現在のタスクを確認\n完了したら報告せよ。", summary="ロール再注入指示")

# 足軽1〜6（各自に送信）
SendMessage(type="message", recipient="ashigaru1", content="コンパクション復帰手順を実行せよ。以下を読み直し、ロールを再確認せよ:\n1. ${SHOGUN_ROOT}/instructions/ashigaru.md\n2. ${SHOGUN_ROOT}/CLAUDE.md\n3. TaskList で自分のタスクを確認\n完了したら家老に報告せよ。", summary="ロール再注入指示")
# ashigaru2〜6 も同様
```

### 5. 結果報告

各エージェントからのメッセージ（idle通知）で完了を確認し、報告する:

```
【陣立て直し完了】

■ 実施内容
- コンパクト: 実施 / 未実施
- ロール再注入: 全 X 名完了

■ 対象
| 役職 | コンパクト | ロール再注入 |
|------|-----------|-------------|
| 家老 | 完了 | 完了 |
| 目付 | 完了 | 完了 |
| 足軽1 | 完了 | 完了 |
| ... | ... | ... |

■ 将軍
- コンパクト: 実施済み / 未実施

全軍、陣形を整え直した。引き続き参る。
```

## 注意事項

- 処理中（busy）のエージェントがいる場合、先に `/shisatsu` で状態を確認すること
- コンパクトは tmux 経由で送信、ロール再注入は Agent Teams（SendMessage）で実施
- Agent Teams 経由なので完了把握が確実
