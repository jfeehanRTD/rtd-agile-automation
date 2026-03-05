#!/usr/bin/env bash
#
# dev-setup.sh — One-time setup for TIS Next Gen developers
#
# Run this after cloning the repo:
#   ./scripts/dev-setup.sh
#
set -euo pipefail

echo ""
echo "TIS Next Gen — Developer Setup"
echo "==============================="
echo ""

# 1. Check/install beads
if command -v bd >/dev/null 2>&1; then
  echo "[OK] bd CLI already installed ($(bd version 2>/dev/null || echo 'unknown version'))"
else
  echo "[INSTALLING] bd CLI via Homebrew..."
  if command -v brew >/dev/null 2>&1; then
    brew install beads
  else
    echo "Homebrew not found. Install bd manually:"
    echo "  brew install beads"
    echo "  OR: npm install -g @beads/bd"
    echo "  OR: curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash"
    exit 1
  fi
fi

# 2. Check jq (needed for hooks)
if command -v jq >/dev/null 2>&1; then
  echo "[OK] jq installed"
else
  echo "[INSTALLING] jq..."
  if command -v brew >/dev/null 2>&1; then
    brew install jq
  else
    echo "Please install jq: brew install jq"
    exit 1
  fi
fi

# 3. Initialize beads if not already done
if [ -d ".beads" ]; then
  echo "[OK] Beads already initialized"
else
  echo "[INIT] Initializing beads..."
  bd init
fi

# 4. Install git hooks
echo "[HOOKS] Installing workflow hooks..."
./scripts/install-hooks.sh

echo ""
echo "==============================="
echo "Setup complete! Quick reference:"
echo ""
echo "  bd ready                  # What can I work on?"
echo "  bd update <id> --claim    # Claim a task"
echo "  bd close <id>             # Mark task done"
echo "  bd blocked                # What's stuck?"
echo ""
echo "Branch naming: TNG-xxx-description"
echo "  e.g. TNG-37-blob-export"
echo ""
echo "See docs/team-workflow.md for the full workflow."
echo ""
