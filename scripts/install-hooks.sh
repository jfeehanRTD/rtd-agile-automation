#!/usr/bin/env bash
#
# install-hooks.sh — Install custom git hooks alongside beads hooks
#
# Appends our custom hooks to the existing beads-managed hook files.
# Safe to run multiple times — checks for existing marker before adding.
#
set -euo pipefail

HOOKS_DIR="$(git rev-parse --show-toplevel)/.beads/hooks"
CUSTOM_DIR="$(git rev-parse --show-toplevel)/scripts/hooks"
MARKER="# --- BEGIN TIS CUSTOM HOOKS ---"

if [ ! -d "$HOOKS_DIR" ]; then
  echo "Error: .beads/hooks not found. Run 'bd init' first."
  exit 1
fi

install_hook() {
  local hook_name="$1"
  local target="$HOOKS_DIR/$hook_name"
  local source="$CUSTOM_DIR/$hook_name"

  if [ ! -f "$source" ]; then
    return
  fi

  # Create hook file if it doesn't exist
  if [ ! -f "$target" ]; then
    echo "#!/usr/bin/env sh" > "$target"
  fi

  # Skip if already installed
  if grep -q "$MARKER" "$target" 2>/dev/null; then
    echo "  $hook_name — already installed, skipping"
    return
  fi

  # Append custom hook
  echo "" >> "$target"
  echo "$MARKER" >> "$target"
  cat "$source" | grep -v '^#!/' >> "$target"
  echo "# --- END TIS CUSTOM HOOKS ---" >> "$target"
  chmod +x "$target"
  echo "  $hook_name — installed"
}

echo "Installing TIS workflow hooks..."
echo ""
install_hook "post-merge"
install_hook "prepare-commit-msg"
install_hook "pre-push"
echo ""
echo "Done. Hooks installed to $HOOKS_DIR"
