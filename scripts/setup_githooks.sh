#!/bin/bash
# scripts/setup_githooks.sh — Git hooks setup script
# Gitleaks pre-commit hookを有効化するセットアップスクリプト

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "=== Git Hooks Setup ==="

# 1. Set git hooks path to .githooks
echo "Setting git hooks path to .githooks..."
git config core.hooksPath .githooks

# 2. Make pre-commit executable
chmod +x .githooks/pre-commit

# 3. Check if gitleaks is installed
if command -v gitleaks >/dev/null 2>&1; then
    echo "✅ gitleaks is installed: $(gitleaks version 2>&1 | head -1)"
else
    echo "⚠️  gitleaks is NOT installed."
    echo ""
    echo "Gitleaksをインストールすることを強く推奨します。"
    echo ""
    echo "【インストール手順 (WSL2/Linux)】"
    echo "  wget https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks-linux-amd64 -O /tmp/gitleaks"
    echo "  sudo mv /tmp/gitleaks /usr/local/bin/gitleaks"
    echo "  sudo chmod +x /usr/local/bin/gitleaks"
    echo ""
    echo "【インストール手順 (macOS)】"
    echo "  brew install gitleaks"
    echo ""
    echo "インストール後、再度このスクリプトを実行してください。"
    echo ""
fi

echo ""
echo "=== Setup Complete ==="
echo "Git hooks path: .githooks"
echo "Pre-commit hook: .githooks/pre-commit"
echo ""
