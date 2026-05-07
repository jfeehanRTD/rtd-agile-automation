#!/usr/bin/env bash
#
# story-start.sh — End-to-end "start a new story" automation. One command:
#   1. Creates a beads issue with the given title + description
#   2. Pushes to Jira (gets the assigned key, e.g. TNG-242)
#   3. Adds the issue to the project's currently-active sprint
#   4. Assigns it to you
#   5. Transitions it to "In Progress" (via bd --claim)
#   6. Cuts a branch named <KEY>-<short-slug> off main
#
# After this you're ready to start coding. Run from inside any git repo
# whose remote/origin maps to a known beads/Jira project.
#
# Usage:
#   ./scripts/story-start.sh "Title of the story"
#   ./scripts/story-start.sh "Title" --type feature --priority 2
#   ./scripts/story-start.sh "Title" --description-file PLAN.md
#   ./scripts/story-start.sh "Title" --slug short-name        # branch suffix override
#   ./scripts/story-start.sh "Title" --no-claim                # skip the in-progress flip
#   ./scripts/story-start.sh "Title" --no-branch               # skip git branch creation
#   ./scripts/story-start.sh "Title" --dry-run
#
# Defaults:
#   --type     feature   (bd issue type)
#   --priority 3         (P3)
#   --slug     auto      (derived from title — first 4 words, lowercased, hyphenated)
#
# Requires:
#   - bd (beads CLI, with jira sync configured for the current repo's project)
#   - Jira creds via env vars or bd config (see jira-helpers.sh)
#   - git (in a repo with origin/main reachable)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./jira-helpers.sh
source "$SCRIPT_DIR/jira-helpers.sh"

TITLE=""
ISSUE_TYPE="feature"
PRIORITY="3"
DESCRIPTION=""
DESCRIPTION_FILE=""
SLUG=""
DO_CLAIM=true
DO_BRANCH=true
DRY_RUN=false

show_help() {
  awk 'NR==1 && /^#!/ {next} /^#/ {sub(/^#[[:space:]]?/,""); print; seen=1; next} seen{exit}' "$0"
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) show_help ;;
    --type)             ISSUE_TYPE="$2"; shift ;;
    --priority|-p)      PRIORITY="$2"; shift ;;
    --description|-d)   DESCRIPTION="$2"; shift ;;
    --description-file) DESCRIPTION_FILE="$2"; shift ;;
    --slug)             SLUG="$2"; shift ;;
    --no-claim)         DO_CLAIM=false ;;
    --no-branch)        DO_BRANCH=false ;;
    --dry-run)          DRY_RUN=true ;;
    -*) echo "Unknown flag: $1 (try --help)" >&2; exit 2 ;;
    *)
      if [ -z "$TITLE" ]; then TITLE="$1"
      else echo "ERROR: only one positional title argument supported" >&2; exit 2
      fi
      ;;
  esac
  shift
done

[ -n "$TITLE" ] || { echo "ERROR: title required (try --help)" >&2; exit 2; }

if [ -n "$DESCRIPTION_FILE" ]; then
  [ -r "$DESCRIPTION_FILE" ] || { echo "ERROR: cannot read $DESCRIPTION_FILE" >&2; exit 2; }
  DESCRIPTION=$(cat "$DESCRIPTION_FILE")
fi

# Auto-slug if not provided: first 4 words, lowercase, hyphenated, alnum only
if [ -z "$SLUG" ]; then
  SLUG=$(printf '%s' "$TITLE" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -c 'a-z0-9 \n' ' ' \
    | awk '{for(i=1;i<=4 && i<=NF;i++) printf("%s%s", $i, (i==4||i==NF?"":"-"))}')
fi

# Auto-detect project key from git remote (e.g., tis-next-gen → TNG)
PROJECT_KEY="${PROJECT_KEY:-}"
if [ -z "$PROJECT_KEY" ] && command -v gh >/dev/null 2>&1; then
  REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)
  REPO_BASENAME=$(printf '%s' "${REPO##*/}")
  PROJECT_KEY=$(printf '%s' "$REPO_BASENAME" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) printf toupper(substr($i,1,1))}')
fi
[ -n "$PROJECT_KEY" ] || { echo "ERROR: could not detect Jira project key (override with PROJECT_KEY=... env)" >&2; exit 1; }

echo "=== story-start ==="
echo "  title:       $TITLE"
echo "  type:        $ISSUE_TYPE"
echo "  priority:    P$PRIORITY"
echo "  project:     $PROJECT_KEY"
echo "  slug:        $SLUG"
echo "  claim:       $DO_CLAIM"
echo "  branch:      $DO_BRANCH"
[ "$DRY_RUN" = "true" ] && { echo "  (dry run — no changes)"; exit 0; }
echo ""

# 1. Create the beads issue
echo "[1/6] Creating beads issue..."
BD_CREATE_ARGS=(--type "$ISSUE_TYPE" --priority "$PRIORITY" --silent)
[ -n "$DESCRIPTION" ] && BD_CREATE_ARGS+=(--description "$DESCRIPTION")
BD_ID=$(bd create "$TITLE" "${BD_CREATE_ARGS[@]}")
[ -n "$BD_ID" ] || { echo "ERROR: bd create returned no ID" >&2; exit 1; }
echo "  bd ID: $BD_ID"

# 2. Push to Jira
echo "[2/6] Syncing to Jira..."
bd jira sync --push --quiet 2>&1 | tail -3

JIRA_KEY=$(bd show "$BD_ID" 2>&1 | grep -oE "$PROJECT_KEY-[0-9]+" | head -1 || true)
[ -n "$JIRA_KEY" ] || { echo "ERROR: could not resolve Jira key for $BD_ID after push" >&2; exit 1; }
echo "  Jira key: $JIRA_KEY"

# 3-5: Jira-side cleanup (sprint + assignee) requires REST API
_jira_setup
BOARD_ID=$(_jira_board_id_for_project "$PROJECT_KEY")

echo "[3/6] Adding $JIRA_KEY to active sprint..."
SPRINT_ID=$(_jira_active_sprint_id "$BOARD_ID" 2>/dev/null || true)
if [ -n "$SPRINT_ID" ]; then
  _jira_add_to_sprint "$JIRA_KEY" "$SPRINT_ID" && echo "  added to sprint $SPRINT_ID"
else
  echo "  (no active sprint on board $BOARD_ID — skipping)"
fi

echo "[4/6] Assigning $JIRA_KEY to me..."
_jira_assign "$JIRA_KEY" me && echo "  assigned"

if [ "$DO_CLAIM" = "true" ]; then
  echo "[5/6] Claiming (status → In Progress)..."
  bd update "$BD_ID" --claim --quiet 2>&1 | tail -1
  bd jira sync --push --quiet 2>&1 | tail -1
else
  echo "[5/6] Skipping --claim (--no-claim)"
fi

if [ "$DO_BRANCH" = "true" ]; then
  echo "[6/6] Cutting branch $JIRA_KEY-$SLUG..."
  if git rev-parse --git-dir >/dev/null 2>&1; then
    git fetch origin main >/dev/null 2>&1 || true
    BRANCH="$JIRA_KEY-$SLUG"
    if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
      echo "  branch $BRANCH already exists — checking out"
      git checkout "$BRANCH"
    else
      git checkout -b "$BRANCH" origin/main
      echo "  on branch $BRANCH"
    fi
  else
    echo "  (not in a git repo — skipping)"
  fi
else
  echo "[6/6] Skipping branch creation (--no-branch)"
fi

echo ""
echo "=== Ready ==="
echo "  Jira:   $JIRA_URL/browse/$JIRA_KEY"
echo "  Status: $(_jira_status "$JIRA_KEY")"
echo "  Branch: $(git branch --show-current 2>/dev/null || echo '(no branch)')"
echo ""
echo "When the work is merged, finish with:"
echo "  $SCRIPT_DIR/story-finish.sh"
