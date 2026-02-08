# multi-agent-shogun

<div align="center">

**Claude Code マルチエージェント統率システム**

*コマンド1つで、複数のAIエージェントが Agent Teams で並列稼働*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blueviolet)](https://claude.ai)
[![tmux](https://img.shields.io/badge/tmux-required-green)](https://github.com/tmux/tmux)

[English](README.md) | [日本語](README_ja.md)

</div>

> **Fork元:** [yohey-w/multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) からのforkです。
> fork以降の変更は [CHANGELOG.md](CHANGELOG.md) を参照してください。

---

## これは何？

**multi-agent-shogun** は、Claude Code の **Agent Teams** を使って複数のインスタンスを同時に実行し、戦国時代の軍制のように統率するシステムです。

**なぜ使うのか？**
- 1つの命令で、複数のAIワーカーが並列で実行
- Claude Code の **Agent Teams** 基盤 — SendMessage/TaskCreate でエージェント間通信
- 待ち時間なし - タスクがバックグラウンドで実行中も次の命令を出せる
- AIがセッションを跨いであなたの好みを記憶（Memory MCP）
- ダッシュボードでリアルタイム進捗確認

```
      あなた（上様）
           │
           ▼ 命令を出す
    ┌─────────────┐
    │   SHOGUN    │  ← 命令を受け取り、即座に委譲
    └──────┬──────┘
           │ Agent Teams API
    ┌──────▼──────┐
    │    KARO     │  ← タスクをワーカーに分配
    └──────┬──────┘
           │
  ┌────────┼────────┐
  ▼        ▼        ▼
┌────────┐ ┌──┬──┬──┐
│METSUKE │ │A1│A2│A3│ ...  ← ワーカーが並列実行
│(品質)  │ └──┴──┴──┘
└────────┘   ASHIGARU
```

---

## 🚀 クイックスタート

### 🪟 Windowsユーザー（最も一般的）

<table>
<tr>
<td width="60">

**Step 1**

</td>
<td>

📥 **リポジトリをダウンロード**

[ZIPダウンロード](https://github.com/marucc/multi-agent-shogun/archive/refs/heads/main.zip) して `C:\tools\multi-agent-shogun` に展開

*または git を使用:* `git clone https://github.com/marucc/multi-agent-shogun.git C:\tools\multi-agent-shogun`

</td>
</tr>
<tr>
<td>

**Step 2**

</td>
<td>

🖱️ **`install.bat` をダブルクリック**

これだけ！インストーラーが全て自動で処理します。

</td>
</tr>
<tr>
<td>

**Step 3**

</td>
<td>

✅ **完了！** AIエージェントが起動しました。

</td>
</tr>
</table>

#### 📅 毎日の起動（初回インストール後）

**Ubuntuターミナル**（WSL）を開いて、**プロジェクトディレクトリ**で実行：

```bash
cd /mnt/c/your-project
/mnt/c/tools/multi-agent-shogun/shutsujin_departure.sh
```

---

<details>
<summary>🐧 <b>Linux / Mac ユーザー</b>（クリックで展開）</summary>

### 初回セットアップ

```bash
# 1. リポジトリをクローン
git clone https://github.com/marucc/multi-agent-shogun.git ~/multi-agent-shogun
cd ~/multi-agent-shogun

# 2. スクリプトに実行権限を付与
chmod +x *.sh

# 3. 初回セットアップを実行
./first_setup.sh
```

### 毎日の起動

```bash
cd ~/your-project
~/multi-agent-shogun/shutsujin_departure.sh
```

</details>

---

<details>
<summary>❓ <b>WSL2とは？なぜ必要？</b>（クリックで展開）</summary>

### WSL2について

**WSL2（Windows Subsystem for Linux）** は、Windows内でLinuxを実行できる機能です。このシステムは `tmux`（Linuxツール）を使って複数のAIエージェントを管理するため、WindowsではWSL2が必要です。

### WSL2がまだない場合

問題ありません！`install.bat` を実行すると：
1. WSL2がインストールされているかチェック
2. なければ、インストール方法を案内
3. 全プロセスをガイド

**クイックインストールコマンド**（PowerShellを管理者として実行）：
```powershell
wsl --install
```

その後、コンピュータを再起動して `install.bat` を再実行してください。

</details>

---

<details>
<summary>📋 <b>スクリプトリファレンス</b>（クリックで展開）</summary>

| スクリプト | 用途 | 実行タイミング |
|-----------|------|---------------|
| `install.bat` | Windows: 初回セットアップ（WSL経由でfirst_setup.shを実行） | 初回のみ |
| `first_setup.sh` | tmux、Node.js、Claude Code CLI をインストール | 初回のみ |
| `shutsujin_departure.sh` | `.shogun/` 生成 + tmuxセッション作成 + Claude Code起動 | 毎日（プロジェクトディレクトリで実行） |

### `install.bat` が自動で行うこと：
- ✅ WSL2がインストールされているかチェック
- ✅ Ubuntuを開いて `first_setup.sh` を実行
- ✅ tmux、Node.js、Claude Code CLI をインストール
- ✅ 必要なディレクトリを作成

### `shutsujin_departure.sh` が行うこと：
- ✅ プロジェクトに `.shogun/` ディレクトリを作成（ダッシュボード、ログ、ラッパースクリプト）
- ✅ tmuxセッションを作成（`shogun-<project>` + `multiagent-<project>`）
- ✅ Agent Teams を有効にしてClaude Codeを起動
- ✅ 各エージェントに指示書を自動読み込み
- ✅ チーム階層を構築（将軍 → 家老 → 足軽）

**実行後、全エージェントが即座にコマンドを受け付ける準備完了！**

</details>

---

<details>
<summary>🔧 <b>必要環境（手動セットアップの場合）</b>（クリックで展開）</summary>

依存関係を手動でインストールする場合：

| 要件 | インストール方法 | 備考 |
|------|-----------------|------|
| WSL2 + Ubuntu | PowerShellで `wsl --install` | Windowsのみ |
| tmux | `sudo apt install tmux` | ターミナルマルチプレクサ |
| Node.js v20+ | `nvm install 20` | Claude Code CLIに必要 |
| Claude Code CLI | `npm install -g @anthropic-ai/claude-code` | Anthropic公式CLI |

</details>

---

### ✅ セットアップ後の状態

どちらのオプションでも、AIエージェントが自動起動します：

| エージェント | 役割 | 数 |
|-------------|------|-----|
| 🏯 将軍（Shogun） | 総大将 — あなたの命令を受ける | 1 |
| 📋 家老（Karo） | 管理者 — タスクを分配 | 1 |
| 🔍 目付（Metsuke） | 品質保証 — レビュー担当 | 1 |
| ⚔️ 足軽（Ashigaru） | ワーカー — 並列でタスク実行 | 設定可能（デフォルト: 3） |

tmuxセッションが作成されます（プロジェクト名がセッション名に含まれます）：
- `shogun-<project>` — ここに接続してコマンドを出す
- `multiagent-<project>` — ワーカーがバックグラウンドで稼働

`.shogun/bin/` にラッパースクリプトが生成されるので、簡単にアクセスできます。

---

## 📖 基本的な使い方

### Step 1: 将軍に接続

`shutsujin_departure.sh` 実行後、全エージェントが自動的に指示書を読み込み、作業準備完了となります。

新しいターミナルを開いて将軍に接続：

```bash
.shogun/bin/shogun.sh
```

### Step 2: 最初の命令を出す

将軍は既に初期化済み！そのまま命令を出せます：

```
JavaScriptフレームワーク上位5つを調査して比較表を作成せよ
```

将軍は：
1. Agent Teams API でタスクを作成
2. SendMessage で家老（管理者）に指示
3. 即座にあなたに制御を返す（待つ必要なし！）

その間、家老はタスクを足軽ワーカーに分配し、並列実行します。

### Step 3: 進捗を確認

エディタで `.shogun/dashboard.md` を開いてリアルタイム状況を確認：

```markdown
## 進行中
| ワーカー | タスク | 状態 |
|----------|--------|------|
| 足軽 1 | React調査 | 実行中 |
| 足軽 2 | Vue調査 | 実行中 |
| 足軽 3 | Angular調査 | 完了 |
```

---

## ✨ 主な特徴

### ⚡ 1. 並列実行

1つの命令で複数の並列タスクを生成：

```
あなた: 「5つのMCPサーバを調査せよ」
→ 足軽が同時に調査開始
→ 数時間ではなく数分で結果が出る
```

### 🔄 2. ノンブロッキングワークフロー

将軍は即座に委譲して、あなたに制御を返します：

```
あなた: 命令 → 将軍: 委譲 → あなた: 次の命令をすぐ出せる
                                    ↓
                    ワーカー: バックグラウンドで実行
                                    ↓
                    ダッシュボード: 結果を表示
```

長いタスクの完了を待つ必要はありません。

### 🧠 3. セッション間記憶（Memory MCP）

AIがあなたの好みを記憶します：

```
セッション1: 「シンプルな方法が好き」と伝える
            → Memory MCPに保存

セッション2: 起動時にAIがメモリを読み込む
            → 複雑な方法を提案しなくなる
```

### 📡 4. Agent Teams 通信

エージェント間の通信は Claude Code の **Agent Teams** API で行います：
- **SendMessage** — エージェント間のダイレクトメッセージ
- **TaskCreate / TaskUpdate** — タスク管理と割り当て
- **自動配信** — ポーリング不要、APIコールの浪費なし

### 📸 5. スクリーンショット連携

VSCode拡張のClaude Codeはスクショを貼り付けて事象を説明できます。このCLIシステムでも同等の機能を実現：

```
# config/settings.yaml でスクショフォルダを設定
screenshot:
  path: "/mnt/c/Users/あなたの名前/Pictures/Screenshots"

# 将軍に伝えるだけ:
あなた: 「最新のスクショを見ろ」
あなた: 「スクショ2枚見ろ」
→ AIが即座にスクリーンショットを読み取って分析
```

**💡 Windowsのコツ:** `Win + Shift + S` でスクショが撮れます。保存先を `settings.yaml` のパスに合わせると、シームレスに連携できます。

### 📁 6. コンテキスト管理

効率的な知識共有のため、3層構造のコンテキストを採用：

| レイヤー | 場所 | 用途 |
|---------|------|------|
| Memory MCP | `memory/shogun_memory.jsonl` | セッションを跨ぐ長期記憶 |
| グローバル | `memory/global_context.md` | システム全体の設定、殿の好み |
| プロジェクト | `context/{project}.md` | プロジェクト固有の知見 |

### 汎用コンテキストテンプレート

すべてのプロジェクトで同じ7セクション構成のテンプレートを使用：

| セクション | 目的 |
|-----------|------|
| What | プロジェクトの概要説明 |
| Why | 目的と成功の定義 |
| Who | 関係者と責任者 |
| Constraints | 期限、予算、制約 |
| Current State | 進捗、次のアクション、ブロッカー |
| Decisions | 決定事項と理由の記録 |
| Notes | 自由記述のメモ・気づき |

---

### 🛠️ スキル

初期状態ではスキルはありません。
運用中にダッシュボード（dashboard.md）の「スキル化候補」から承認して増やしていきます。

スキルは `/スキル名` で呼び出し可能。将軍に「/スキル名 を実行」と伝えるだけ。

### スキルの思想

**1. スキルはコミット対象外**

`.claude/commands/` 配下のスキルはリポジトリにコミットしない設計。理由：
- 各ユーザの業務・ワークフローは異なる
- 汎用的なスキルを押し付けるのではなく、ユーザが自分に必要なスキルを育てていく

**2. スキル取得の手順**

```
足軽が作業中にパターンを発見
    ↓
dashboard.md の「スキル化候補」に上がる
    ↓
殿（あなた）が内容を確認
    ↓
承認すれば家老に指示してスキルを作成
```

---

## 🏛️ 設計思想

### なぜ階層構造（将軍→家老→足軽）なのか

1. **即時応答**: 将軍は即座に委譲してあなたに制御を返す
2. **並列実行**: 家老が複数の足軽に同時にタスクを分配
3. **関心の分離**: 将軍は「何を」、家老は「誰に」を決定
4. **品質ゲート**: 目付が独立してレビューを実施

### なぜ Agent Teams なのか

- **ネイティブ統合**: Claude Code の Agent Teams API を直接使用
- **自動メッセージ配信**: ポーリング不要、ファイルベースの回避策不要
- **タスク管理**: TaskCreate/TaskUpdate/TaskList が組み込み済み
- **確実な通信**: SendMessage による配信保証

### なぜ dashboard.md は家老のみが更新するのか

1. **単一更新者**: 競合を防ぐため、更新責任者を1人に限定
2. **情報集約**: 家老は全足軽の報告を受ける立場なので全体像を把握
3. **割り込み防止**: 将軍が更新すると、殿の入力中に割り込む恐れあり

---

## 🔌 MCPセットアップガイド

MCP（Model Context Protocol）サーバはClaudeの機能を拡張します。セットアップ方法：

### MCPとは？

MCPサーバはClaudeに外部ツールへのアクセスを提供します：
- **Notion MCP** → Notionページの読み書き
- **GitHub MCP** → PR作成、Issue管理
- **Memory MCP** → セッション間で記憶を保持

### MCPサーバのインストール

以下のコマンドでMCPサーバを追加：

```bash
# 1. Notion - Notionワークスペースに接続
claude mcp add notion -e NOTION_TOKEN=your_token_here -- npx -y @notionhq/notion-mcp-server

# 2. Playwright - ブラウザ自動化
claude mcp add playwright -- npx @playwright/mcp@latest
# 注意: 先に `npx playwright install chromium` を実行してください

# 3. GitHub - リポジトリ操作
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=your_pat_here -- npx -y @modelcontextprotocol/server-github

# 4. Sequential Thinking - 複雑な問題を段階的に思考
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking

# 5. Memory - セッション間の長期記憶（推奨！）
claude mcp add memory -e MEMORY_FILE_PATH="$PWD/memory/shogun_memory.jsonl" -- npx -y @modelcontextprotocol/server-memory
```

### インストール確認

```bash
claude mcp list
```

全サーバが「Connected」ステータスで表示されるはずです。

---

## ⚙️ 設定

### エージェント数

`config/settings.yaml` を編集：

```yaml
ashigaru_count: 3   # 足軽の数（1〜8）
```

### 言語設定

```yaml
language: ja   # 日本語のみ
language: en   # 日本語 + 英訳併記
```

---

## 🛠️ 上級者向け

<details>
<summary><b>スクリプトアーキテクチャ</b>（クリックで展開）</summary>

```
┌─────────────────────────────────────────────────────────────────────┐
│                      初回セットアップ（1回だけ実行）                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  install.bat (Windows)                                              │
│      │                                                              │
│      └──▶ first_setup.sh (WSL経由)                                  │
│                │                                                    │
│                ├── tmuxのチェック/インストール                        │
│                ├── Node.js v20+のチェック/インストール (nvm経由)       │
│                └── Claude Code CLIのチェック/インストール             │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                      毎日の起動（毎日実行）                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  shutsujin_departure.sh                                             │
│      │                                                              │
│      ├──▶ プロジェクトに .shogun/ ディレクトリを作成                    │
│      │                                                              │
│      ├──▶ tmuxセッションを作成                                       │
│      │         • "shogun-<project>"セッション（将軍）                │
│      │         • "multiagent-<project>"セッション（家老+目付+足軽）  │
│      │                                                              │
│      └──▶ Agent Teams を有効にしてClaude Codeを起動                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

</details>

<details>
<summary><b>shutsujin_departure.sh オプション</b>（クリックで展開）</summary>

```bash
# プロジェクトディレクトリで実行
cd /path/to/your/project

# デフォルト: フル起動（.shogun/ 作成 + tmuxセッション + Claude Code起動）
/path/to/multi-agent-shogun/shutsujin_departure.sh

# ヘルプを表示
/path/to/multi-agent-shogun/shutsujin_departure.sh -h
```

</details>

<details>
<summary><b>よく使うワークフロー</b>（クリックで展開）</summary>

**通常の毎日の使用：**
```bash
cd /path/to/your/project
/path/to/multi-agent-shogun/shutsujin_departure.sh   # 全て起動
.shogun/bin/shogun.sh                                 # 接続してコマンドを出す
```

**再出陣（撤退後）：**
```bash
.shogun/bin/shutsujin.sh          # プロジェクトディレクトリから再出陣
```

**撤退（終了）：**
```bash
.shogun/bin/tettai.sh             # バックアップ付きで終了
```

</details>

---

## 📁 ファイル構成

<details>
<summary><b>クリックでファイル構成を展開</b></summary>

```
multi-agent-shogun/                      # SHOGUN_ROOT（システムファイル）
│
│  ┌─────────────────── スクリプト ───────────────────────────┐
├── install.bat               # Windows: 初回セットアップ
├── first_setup.sh            # Ubuntu/Mac: 初回セットアップ
├── shutsujin_departure.sh    # 出陣（プロジェクトディレクトリで実行）
├── tettai_retreat.sh         # 撤退・終了
├── watchdog.sh               # 監視デーモン
├── switch_account.sh         # アカウント切り替え
│  └────────────────────────────────────────────────────────┘
│
├── instructions/             # エージェント指示書
│   ├── shogun.md             # 将軍の指示書
│   ├── karo.md               # 家老の指示書
│   ├── metsuke.md            # 目付の指示書
│   └── ashigaru.md           # 足軽の指示書
│
├── scripts/
│   ├── claude-shogun         # Claude Code起動ラッパー
│   ├── notify.sh             # tmux send-keysラッパー
│   └── project-env.sh        # 共通変数定義
│
├── config/
│   └── settings.yaml         # 言語、エージェント数の設定
│
├── context/                  # プロジェクトコンテキスト
├── memory/                   # Memory MCP保存場所
└── CLAUDE.md                 # Claude用プロジェクトコンテキスト

your-project/.shogun/                    # プロジェクトごとに生成
├── project.env               # プロジェクトメタデータ
├── dashboard.md              # リアルタイム状況一覧
├── bin/
│   ├── shutsujin.sh          # 再出陣ラッパー
│   ├── tettai.sh             # 撤退ラッパー
│   ├── shogun.sh             # 将軍セッションにアタッチ
│   └── multiagent.sh         # 配下セッションにアタッチ
├── status/
│   └── pending_tasks.yaml    # 撤退時に自動保存
└── logs/
    └── backup_*/             # バックアップ
```

</details>

---

## 🔧 トラブルシューティング

<details>
<summary><b>MCPツールが動作しない？</b></summary>

MCPツールは「遅延ロード」方式で、最初にロードが必要です：

```
# 間違い - ツールがロードされていない
mcp__memory__read_graph()  ← エラー！

# 正しい - 先にロード
ToolSearch("select:mcp__memory__read_graph")
mcp__memory__read_graph()  ← 動作！
```

</details>

<details>
<summary><b>エージェントが権限を求めてくる？</b></summary>

`--dangerously-skip-permissions` 付きで起動していることを確認：

```bash
claude --dangerously-skip-permissions --system-prompt "..."
```

</details>

<details>
<summary><b>ワーカーが停止している？</b></summary>

ワーカーのペインを確認：
```bash
.shogun/bin/multiagent.sh
# Ctrl+B の後に矢印キーでペインを切り替え
```

</details>

---

## 📚 tmux クイックリファレンス

| コマンド | 説明 |
|----------|------|
| `.shogun/bin/shogun.sh` | 将軍に接続 |
| `.shogun/bin/multiagent.sh` | ワーカーに接続 |
| `.shogun/bin/tettai.sh` | 撤退（終了） |
| `Ctrl+B` の後 矢印キー | ペイン間を切り替え |
| `Ctrl+B` の後 `d` | デタッチ（実行継続） |
| `tmux ls` | 全セッション一覧 |

---

## 🙏 クレジット

[Claude-Code-Communication](https://github.com/Akira-Papa/Claude-Code-Communication) by Akira-Papa をベースに開発。

[yohey-w/multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) からfork。

---

## 📄 ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照。

---

<div align="center">

**AIの軍勢を統率せよ。より速く構築せよ。**

</div>
