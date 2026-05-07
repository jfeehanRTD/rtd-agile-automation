#!/usr/bin/env bash
#
# story-finish.sh — End-to-end "ship a story" automation. One command:
#   1. Marks the PR ready for review (off draft, if needed)
#   2. Squash-merges the PR (optionally; --no-merge to just transition Jira)
#   3. Transitions the linked Jira issue → Done
#   4. Reassigns it to you (Jira sometimes auto-assigns to project default)
#   5. Deletes the local + remote branch
#   6. Switches back to main and pulls
#
# Auto-detects the PR from the current branch unless --pr is given.
# Auto-detects the Jira key from the branch name (TNG-### prefix).
#
# Usage:
#   ./scripts/story-finish.sh
#   ./scripts/story-finish.sh --pr 115
#   ./scripts/story-finish.sh --issue TNG-242
#   ./scripts/story-finish.sh --no-merge       # just transition Jira (PR already merged)
#   ./scripts/story-finish.sh --keep-branch    # don't delete the branch
#   ./scripts/story-finish.sh --status Done    # transition target (default Done)
#   ./scripts/story-finish.sh --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./jira-helpers.sh
source "$SCRIPT_DIR/jira-helpers.sh"

PR_NUMBER=""
ISSUE_KEY=""
TARGET_STATUS="Done"
DO_MERGE=true
KEEP_BRANCH=false
DRY_RUN=false

show_help() {
  awk 'NR==1 && /^#!/ {next} /^#/ {sub(/^#[[:space:]]?/,""); print; seen=1; next} seen{exit}' "$0"
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)        show_help ;;
    --pr)             PR_NUMBER="$2"; shift ;;
    --issue)          ISSUE_KEY="$2"; shift ;;
    --status)         TARGET_STATUS="$2"; shift ;;
    --no-merge)       DO_MERGE=false ;;
    --keep-branch)    KEEP_BRANCH=true ;;
    --dry-run)        DRY_RUN=true ;;
    -*) echo "Unknown flag: $1 (try --help)" >&2; exit 2 ;;
    *) echo "Unknown arg: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done

# Resolve the current branch (used for PR + Jira-key inference + cleanup)
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || true)

# Auto-detect PR if not given
if [ -z "$PR_NUMBER" ] && [ -n "$CURRENT_BRANCH" ] && command -v gh >/dev/null 2>&1; then
  PR_NUMBER=$(gh pr list --head "$CURRENT_BRANCH" --state all --json number --jq '.[0].number' 2>/dev/null || true)
fi

# Auto-detect issue key from branch name (TNG-### prefix) or PR title
if [ -z "$ISSUE_KEY" ]; then
  ISSUE_KEY=$(printf '%s' "$CURRENT_BRANCH" | grep -oE '^[A-Z]+-[0-9]+' | head -1 || true)
fi
if [ -z "$ISSUE_KEY" ] && [ -n "$PR_NUMBER" ] && command -v gh >/dev/null 2>&1; then
  ISSUE_KEY=$(gh pr view "$PR_NUMBER" --json title --jq '.title' 2>/dev/null \
    | grep -oE '[A-Z]+-[0-9]+' | head -1 || true)
fi
[ -n "$ISSUE_KEY" ] || { echo "ERROR: could not infer Jira issue key (use --issue TNG-###)" >&2; exit 1; }

echo "=== story-finish ==="
echo "  PR:           ${PR_NUMBER:-(none)}"
echo "  issue:        $ISSUE_KEY"
echo "  branch:       ${CURRENT_BRANCH:-(none)}"
echo "  target:       $TARGET_STATUS"
echo "  merge PR:     $DO_MERGE"
echo "  keep branch:  $KEEP_BRANCH"
[ "$DRY_RUN" = "true" ] && { echo "  (dry run — no changes)"; exit 0; }
echo ""

_jira_setup

# --- 1+2: PR ready + merge -----------------------------------------------
if [ "$DO_MERGE" = "true" ] && [ -n "$PR_NUMBER" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: gh CLI required for PR merge — install or use --no-merge" >&2; exit 1
  fi

  PR_STATE=$(gh pr view "$PR_NUMBER" --json state,isDraft,mergeable,mergeStateStatus -q '"\(.state)/draft=\(.isDraft)/\(.mergeable)/\(.mergeStateStatus)"' 2>&1)
  echo "[1/5] PR #$PR_NUMBER state: $PR_STATE"

  IS_DRAFT=$(gh pr view "$PR_NUMBER" --json isDraft -q '.isDraft')
  if [ "$IS_DRAFT" = "true" ]; then
    echo "  marking ready for review..."
    gh pr ready "$PR_NUMBER" >/dev/null
  fi

  PR_MERGED=$(gh pr view "$PR_NUMBER" --json state -q '.state')
  if [ "$PR_MERGED" = "MERGED" ]; then
    echo "[2/5] PR already merged — skipping merge step"
  else
    echo "[2/5] Squash-merging PR #$PR_NUMBER..."
    gh pr merge "$PR_NUMBER" --squash --delete-branch=false 2>&1 | tail -3
    # GitHub can take a beat to reflect MERGED state; poll briefly
    for _ in $(seq 1 6); do
      sleep 2
      PR_MERGED=$(gh pr view "$PR_NUMBER" --json state -q '.state' 2>/dev/null || echo "")
      [ "$PR_MERGED" = "MERGED" ] && break
    done
  fi
elif [ "$DO_MERGE" = "false" ]; then
  echo "[1/5] (skipping PR ready/merge — --no-merge)"
  echo "[2/5] (skipping PR ready/merge — --no-merge)"
else
  echo "[1/5] (no PR number — skipping ready/merge)"
  echo "[2/5] (no PR number — skipping ready/merge)"
fi

# --- 3: Jira → target status ---------------------------------------------
CURRENT_STATUS=$(_jira_status "$ISSUE_KEY")
if [ "$CURRENT_STATUS" = "$TARGET_STATUS" ]; then
  echo "[3/5] $ISSUE_KEY already $TARGET_STATUS"
else
  echo "[3/5] Transitioning $ISSUE_KEY: $CURRENT_STATUS → $TARGET_STATUS"
  _jira_transition "$ISSUE_KEY" "$TARGET_STATUS"
fi

# --- 4: Reassign to me (defends against Jira project-default re-assignment) -
echo "[4/5] Ensuring $ISSUE_KEY is assigned to you..."
_jira_assign "$ISSUE_KEY" me

# --- 5: Branch cleanup ---------------------------------------------------
if [ "$KEEP_BRANCH" = "true" ]; then
  echo "[5/5] (keeping branch — --keep-branch)"
elif [ -z "$CURRENT_BRANCH" ]; then
  echo "[5/5] (no current branch — skipping cleanup)"
else
  echo "[5/5] Cleaning up branch $CURRENT_BRANCH..."
  git checkout main >/dev/null 2>&1
  git pull origin main >/dev/null 2>&1 || true
  git branch -D "$CURRENT_BRANCH" 2>/dev/null && echo "  local: deleted" || echo "  local: not present"
  if git ls-remote --heads origin "$CURRENT_BRANCH" 2>/dev/null | grep -q .; then
    git push origin --delete "$CURRENT_BRANCH" 2>&1 | tail -1
  fi
fi

echo ""
echo "=== Done ==="
echo "  Jira:   $JIRA_URL/browse/$ISSUE_KEY  ($(_jira_status "$ISSUE_KEY"))"
[ -n "$PR_NUMBER" ] && echo "  PR:     #$PR_NUMBER"
echo "  Branch: $(git branch --show-current 2>/dev/null || echo '?')"
