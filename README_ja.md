# 🏯 multi-agent-shogun

<div align="center">

**Claude Code マルチエージェント統率システム**

*コマンド1つで、8体のAIエージェントが並列稼働*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blueviolet)](https://claude.ai)
[![tmux](https://img.shields.io/badge/tmux-required-green)](https://github.com/tmux/tmux)

[English](README.md) | [日本語](README_ja.md)

</div>

---

## 🚀 クイックスタート

### 🪟 Windowsユーザー（推奨）

1. **ダウンロード**
   ```
   git clone https://github.com/yohey-w/multi-agent-shogun.git C:\tools\multi-agent-shogun
   ```
   または [ZIPダウンロード](https://github.com/yohey-w/multi-agent-shogun/archive/refs/heads/main.zip) して `C:\tools\multi-agent-shogun` に展開

2. **インストール** - `install.bat` をダブルクリック
   - WSL2、tmux、Node.js、Claude Code CLI を自動インストール

3. **毎日の起動** - WSLターミナルで:
   ```bash
   cd /mnt/c/tools/multi-agent-shogun
   ./shutsujin_departure.sh
   ```

### 🐧 Linux / Mac ユーザー

```bash
# 1. クローン
git clone https://github.com/yohey-w/multi-agent-shogun.git ~/multi-agent-shogun
cd ~/multi-agent-shogun

# 2. 初回セットアップ（tmux, Node.js, Claude Code CLI をインストール）
chmod +x *.sh
./first_setup.sh

# 3. 起動
./shutsujin_departure.sh
```

これで10体のAIエージェント（将軍1 + 家老1 + 足軽8）が自動起動し、各自の指示書を読み込んで即座に稼働可能になります。

---

## ⚔️ これは何？

**multi-agent-shogun** は、複数の Claude Code を戦国時代の軍制で統率するシステムです：

```
      あなた（上様）
           │
           ▼
    ┌─────────────┐
    │   SHOGUN    │  ← 戦略統括
    │    将軍     │
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │    KARO     │  ← タスク分配
    │    家老     │
    └──────┬──────┘
           │
  ┌─┬─┬─┬─┴─┬─┬─┬─┐
  │1│2│3│4│5│6│7│8│  ← 並列実行
  └─┴─┴─┴─┴─┴─┴─┴─┘
      ASHIGARU 足軽
```

将軍に1つ命令すれば、8体の足軽が並列で作業します。

---

## ✨ 特徴

| 特徴 | 説明 |
|------|------|
| 🔄 **イベント駆動** | ポーリングなし。tmuxで互いを起こす |
| 📁 **競合なし** | 各足軽に専用タスクファイル |
| 📊 **ダッシュボード** | `dashboard.md` でリアルタイム確認 |
| 🎭 **戦国風** | 楽しい戦国ペルソナ |

---

## 📋 基本的な使い方

`./shutsujin_departure.sh` 実行後、全エージェントが自動的に指示書を読み込み、即座に稼働可能になります。

1. **将軍にアタッチ**（別ターミナルで）:
   ```bash
   tmux attach-session -t shogun
   ```

2. **命令する**（将軍は初期化済み、すぐに命令できます）:
   ```
   JavaScriptフレームワーク5つを調査して比較表を作成せよ
   ```

3. **ダッシュボードを確認**:
   `dashboard.md` を開いてリアルタイム進捗を確認。

---

## 📂 ファイル構成

```
multi-agent-shogun/
├── shutsujin_departure.sh    # メイン起動スクリプト（tmux + Claude Code + 指示書自動読込）
├── first_setup.sh            # 初回セットアップ（tmux, Node.js, Claude Code CLI インストール）
├── install.bat               # Windows用インストーラー（first_setup.shを呼出）
├── instructions/             # エージェント指示書
│   ├── shogun.md
│   ├── karo.md
│   └── ashigaru.md
├── config/settings.yaml      # 言語設定
├── queue/                    # 通信ファイル
│   ├── shogun_to_karo.yaml
│   ├── tasks/ashigaru*.yaml
│   └── reports/
└── dashboard.md              # 状況一覧
```

---

## ⚙️ 設定

### 言語設定

`config/settings.yaml` を編集:

```yaml
language: ja   # 日本語のみ
language: en   # 日本語 + 英訳併記
```

---

## 🔧 上級者向け

### コマンドオプション

```bash
./shutsujin_departure.sh      # フル起動（推奨）
./shutsujin_departure.sh -s   # セットアップのみ（Claude手動起動）
./shutsujin_departure.sh -t   # Windows Terminalタブ展開
./shutsujin_departure.sh -h   # ヘルプ
```

### 便利なエイリアス

`~/.bashrc` に追加:

```bash
alias shogun='cd /mnt/c/tools/multi-agent-shogun && ./shutsujin_departure.sh'
alias css='tmux attach-session -t shogun'
alias csm='tmux attach-session -t multiagent'
```

### tmuxペイン構成

| セッション | ペイン | エージェント |
|------------|--------|-------------|
| shogun | 0 | 将軍（総大将） |
| multiagent | 0 | 家老（管理者） |
| multiagent | 1-8 | 足軽1-8（実働部隊） |

---

## 🔌 MCP統合（オプション）

MCPサーバでエージェントを強化：

| MCPサーバ | 用途 | セットアップ |
|-----------|------|-------------|
| **Notion** | ノート・DB操作 | `claude mcp add notion -e NOTION_TOKEN=xxx -- npx -y @notionhq/notion-mcp-server` |
| **Playwright** | ブラウザ自動化 | `claude mcp add playwright -- npx @playwright/mcp@latest` |
| **GitHub** | リポジトリ操作 | `claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=xxx -- npx -y @modelcontextprotocol/server-github` |
| **Sequential Thinking** | 段階的思考 | `claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking` |

詳細なセットアップ手順はデプロイ後の `dashboard.md` を参照。

---

## 🙏 クレジット

[Claude-Code-Communication](https://github.com/Akira-Papa/Claude-Code-Communication) by Akira-Papa をベースに開発。

---

## 📄 ライセンス

MIT License - [LICENSE](LICENSE) を参照。

---

<div align="center">

**⚔️ AIの軍勢を統率せよ。より速く構築せよ。 🏯**

</div>
