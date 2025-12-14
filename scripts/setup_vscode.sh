#!/bin/zsh
set -euo pipefail

echo "🔧 OpenCone VS Code Setup"
echo "========================="
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# STEP 1: Install CLI Tools
# ──────────────────────────────────────────────────────────────────────────────
echo "📦 Installing CLI tools via Homebrew..."

brew list xcode-build-server &>/dev/null || brew install xcode-build-server
brew list xcbeautify &>/dev/null || brew install xcbeautify  
brew list swiftlint &>/dev/null || brew install swiftlint
brew list swift-format &>/dev/null || brew install swift-format

echo "✅ CLI tools ready"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# STEP 2: Install iOS Architect Extensions
# ──────────────────────────────────────────────────────────────────────────────
echo "🧩 Installing iOS development extensions..."

# Core iOS stack
code --install-extension sweetpad.sweetpad              # Build/Run/Simulate
code --install-extension swiftlang.swift-vscode         # Official Swift LSP
code --install-extension vadimcn.vscode-lldb            # Debugger
code --install-extension vknabel.vscode-swiftformat     # Code formatter

# Copilot (required for the protocol)
code --install-extension github.copilot
code --install-extension github.copilot-chat

# Cognitive load reducers
code --install-extension usernamehw.errorlens           # Inline errors
code --install-extension eamodio.gitlens                # Git blame/history
code --install-extension gruntfuggly.todo-tree          # TODO/FIXME scanner
code --install-extension yzhang.markdown-all-in-one     # Markdown editing
code --install-extension pkief.material-icon-theme      # File icons

echo "✅ Extensions installed"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# STEP 3: Generate xcode-build-server config
# ──────────────────────────────────────────────────────────────────────────────
echo "🔨 Configuring xcode-build-server..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

# Find the Xcode project
if [[ -d "OpenCone.xcodeproj" ]]; then
    xcode-build-server config -project OpenCone.xcodeproj -scheme OpenCone
    echo "✅ Build server configured for OpenCone.xcodeproj"
else
    echo "⚠️  No .xcodeproj found, skipping build server config"
fi

echo ""
echo "════════════════════════════════════════════════════════════════════════════"
echo "🎉 SETUP COMPLETE"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "1. Restart VS Code"
echo "2. Open the OpenCone folder"
echo "3. Wait for Swift LSP to index (status bar shows progress)"
echo ""
echo "Optional: Create a 'iOS Architect' profile to isolate these extensions:"
echo "   Gear icon → Profiles → Create Profile → 'iOS Architect'"
echo ""
