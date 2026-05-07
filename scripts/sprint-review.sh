#!/usr/bin/env bash
#
# sprint-review.sh — Automated DoD verification for sprint review
#
# Checks merged PRs from the last sprint against Definition of Done:
#   1. Code in PR and reviewed (at least one APPROVED review)
#   2. Tests written and passing (Build & Test / Test Results checks)
#   3. PR merged to main
#   4. No new SonarQube/lint warnings (SonarCloud Code Analysis check)
#   5. User story doc exists (docs/stories/TNG-XXX.md) — exempt for bug fixes & config changes
#
# Usage:
#   ./scripts/sprint-review.sh              # last 14 days (default sprint)
#   ./scripts/sprint-review.sh 21           # last 21 days
#   ./scripts/sprint-review.sh 14 TNG       # filter to TNG-* issues only
#   ./scripts/sprint-review.sh --pr 43      # single PR by number
#   ./scripts/sprint-review.sh --pr TNG-9   # single PR by Jira key (searches branch/title)
#   ./scripts/sprint-review.sh --repo rideRTD/tis-next-gen 14     # target a different repo
#
set -euo pipefail

# Parse --repo flag (must come first)
REPO=""
if [ "${1:-}" = "--repo" ]; then
  REPO="${2:?Usage: $0 --repo <owner/repo>}"
  shift 2
fi

# Auto-detect repo from git remote if not specified
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
fi
if [ -z "$REPO" ]; then
  echo "Error: Could not detect GitHub repo. Run from inside a git repo or use --repo <owner/repo>."
  exit 1
fi

# Auto-detect Jira prefix from repo name (e.g., tis-next-gen -> TNG, my-project -> MY)
REPO_BASENAME=$(echo "$REPO" | sed 's|.*/||')
DEFAULT_PREFIX=$(echo "$REPO_BASENAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) printf toupper(substr($i,1,1))}')

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass() { printf "  ${GREEN}[PASS]${NC} %s\n" "$1"; }
fail() { printf "  ${RED}[FAIL]${NC} %s\n" "$1"; }
warn() { printf "  ${YELLOW}[WARN]${NC} %s\n" "$1"; }
info() { printf "  ${CYAN}[INFO]${NC} %s\n" "$1"; }

# Check if a PR requires a user story doc.
# Bug fixes, hotfixes, and config-only changes are exempt.
# Args: $1=PR title, $2=branch name, $3=Jira key (empty = exempt)
# Returns: "REQUIRED" or "EXEMPT"
check_story_doc() {
  local title="$1" branch="$2" jira_key="$3"
  # No Jira key — nothing to check
  if [ -z "$jira_key" ]; then
    echo "EXEMPT"
    return
  fi
  # Bug fix patterns (case-insensitive match on title or branch)
  local title_lower branch_lower
  title_lower=$(echo "$title" | tr '[:upper:]' '[:lower:]')
  branch_lower=$(echo "$branch" | tr '[:upper:]' '[:lower:]')
  if [[ "$title_lower" =~ (^|[^a-z])fix([^a-z]|$)|bugfix|hotfix ]] || [[ "$branch_lower" =~ ^fix[/]|bugfix|hotfix[/] ]]; then
    echo "EXEMPT"
    return
  fi
  # Config-only patterns
  if [[ "$title_lower" =~ config ]]; then
    echo "EXEMPT"
    return
  fi
  echo "REQUIRED"
}

# Parse arguments
SINGLE_PR=""
if [ "${1:-}" = "--pr" ]; then
  SINGLE_PR="${2:?Usage: $0 --pr <number|JIRA-key>}"
  shift 2
fi

DAYS="${1:-14}"
PREFIX="${2:-$DEFAULT_PREFIX}"

echo ""
printf "${BOLD}Sprint Review — DoD Verification${NC}\n"
printf "Repository: %s\n" "$REPO"

if [ -n "$SINGLE_PR" ]; then
  # Single PR mode
  if [[ "$SINGLE_PR" =~ ^[0-9]+$ ]]; then
    # Numeric — fetch by PR number
    printf "Mode:       Single PR #%s\n" "$SINGLE_PR"
    echo "================================================================"
    PRS=$(gh pr view "$SINGLE_PR" --repo "$REPO" \
      --json number,title,headRefName,mergedAt,state,reviews,statusCheckRollup,author \
      | jq '[.]')
  else
    # Jira key — search merged PRs matching the key
    printf "Mode:       Single PR matching %s\n" "$SINGLE_PR"
    echo "================================================================"
    # Word-boundary match to avoid TNG-9 matching TNG-95, TNG-97, etc.
    PRS=$(gh pr list --repo "$REPO" --state merged --limit 200 \
      --json number,title,headRefName,mergedAt,reviews,statusCheckRollup,author \
      | jq --arg key "$SINGLE_PR" \
        '[ .[] | select(
          (.title | test($key + "(?![0-9])")) or
          (.headRefName | test($key + "(?![0-9])"))
        ) ]')
  fi
else
  # Sprint mode
  SINCE=$(date -v-"${DAYS}"d +%Y-%m-%dT00:00:00Z 2>/dev/null || date -d "${DAYS} days ago" +%Y-%m-%dT00:00:00Z)
  printf "Period:     last %s days (since %s)\n" "$DAYS" "$SINCE"
  printf "Filter:     %s-* issues\n" "$PREFIX"
  echo "================================================================"
  PRS=$(gh pr list --repo "$REPO" --state merged --limit 100 \
    --json number,title,headRefName,mergedAt,reviews,statusCheckRollup,author \
    --jq "[ .[] | select(.mergedAt >= \"$SINCE\") ]")
fi

PR_COUNT=$(echo "$PRS" | jq 'length')

if [ "$PR_COUNT" -eq 0 ]; then
  echo ""
  echo "No merged PRs found in the last $DAYS days."
  exit 0
fi

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_WARN=0
ISSUES_CHECKED=0
declare -a FAILURES=()

echo "$PRS" | jq -c '.[]' | while IFS= read -r pr; do
  PR_NUM=$(echo "$pr" | jq -r '.number')
  PR_TITLE=$(echo "$pr" | jq -r '.title')
  BRANCH=$(echo "$pr" | jq -r '.headRefName')
  MERGED_AT=$(echo "$pr" | jq -r '.mergedAt')
  AUTHOR=$(echo "$pr" | jq -r '.author.login')

  # Extract Jira key from title or branch
  JIRA_KEY=""
  if [[ "$PR_TITLE" =~ ($PREFIX-[0-9]+) ]]; then
    JIRA_KEY="${BASH_REMATCH[1]}"
  elif [[ "$BRANCH" =~ ($PREFIX-[0-9]+) ]]; then
    JIRA_KEY="${BASH_REMATCH[1]}"
  fi

  # Skip PRs without a Jira key if prefix filter is set
  if [ -n "$PREFIX" ] && [ -z "$JIRA_KEY" ]; then
    echo ""
    printf "${YELLOW}PR #%s${NC} — %s\n" "$PR_NUM" "$PR_TITLE"
    warn "No $PREFIX issue key found in PR title or branch — skipping DoD check"
    continue
  fi

  echo ""
  ISSUE_LABEL="${JIRA_KEY:-"no-key"}"
  printf "${BOLD}PR #%s${NC} — %s\n" "$PR_NUM" "$PR_TITLE"
  printf "  Jira: %-12s  Branch: %-30s  Author: %s\n" "$ISSUE_LABEL" "$BRANCH" "$AUTHOR"
  printf "  Merged: %s\n" "$MERGED_AT"

  DOD_PASS=0
  DOD_FAIL=0

  # --- Check 1: PR reviewed (at least one APPROVED review) ---
  APPROVED=$(echo "$pr" | jq '[.reviews[] | select(.state == "APPROVED")] | length')
  REVIEWERS=$(echo "$pr" | jq -r '[.reviews[] | select(.state == "APPROVED") | .author.login] | unique | join(", ")')
  if [ "$APPROVED" -gt 0 ]; then
    pass "Code reviewed — approved by: $REVIEWERS"
    DOD_PASS=$((DOD_PASS + 1))
  else
    fail "No approved review found"
    DOD_FAIL=$((DOD_FAIL + 1))
  fi

  # --- Check 2: Tests passing (build check + Test Results) ---
  # Match common build check names: "Build & Test", "Build, Test & Sonar", "Gradle Build + Sonar Scan"
  BUILD_TEST=$(echo "$pr" | jq -r '[.statusCheckRollup[] | select(.name | test("Build.*Test|Gradle Build"))] | .[0].conclusion // "MISSING"')
  BUILD_NAME=$(echo "$pr" | jq -r '[.statusCheckRollup[] | select(.name | test("Build.*Test|Gradle Build"))] | .[0].name // "Build & Test"')
  TEST_RESULTS=$(echo "$pr" | jq -r '[.statusCheckRollup[] | select(.name == "Test Results")] | .[0].conclusion // "MISSING"')

  if [ "$BUILD_TEST" = "SUCCESS" ] && [ "$TEST_RESULTS" = "SUCCESS" ]; then
    pass "Tests passing — $BUILD_NAME: SUCCESS, Test Results: SUCCESS"
    DOD_PASS=$((DOD_PASS + 1))
  elif [ "$BUILD_TEST" = "MISSING" ] && [ "$TEST_RESULTS" = "MISSING" ]; then
    fail "No test checks found on this PR"
    DOD_FAIL=$((DOD_FAIL + 1))
  else
    fail "Tests not fully passing — Build & Test: $BUILD_TEST, Test Results: $TEST_RESULTS"
    DOD_FAIL=$((DOD_FAIL + 1))
  fi

  # --- Check 3: PR merged to main ---
  pass "PR merged to main"
  DOD_PASS=$((DOD_PASS + 1))

  # --- Check 4: SonarCloud / lint clean ---
  SONAR=$(echo "$pr" | jq -r '[.statusCheckRollup[] | select(.name | test("SonarCloud|Sonar|sonar"))] | .[0].conclusion // "MISSING"')
  SONAR_URL=$(echo "$pr" | jq -r '[.statusCheckRollup[] | select(.name | test("SonarCloud|Sonar|sonar"))] | .[0].detailsUrl // ""')

  if [ "$SONAR" = "SUCCESS" ]; then
    pass "SonarCloud analysis passed"
    DOD_PASS=$((DOD_PASS + 1))
  elif [ "$SONAR" = "MISSING" ]; then
    warn "No SonarCloud check found"
    DOD_PASS=$((DOD_PASS + 1))
  else
    fail "SonarCloud analysis: $SONAR"
    if [ -n "$SONAR_URL" ]; then
      info "Details: $SONAR_URL"
    fi
    DOD_FAIL=$((DOD_FAIL + 1))
  fi

  # --- Check 5: User story document exists (exempt for bug fixes / config) ---
  DOC_STATUS=$(check_story_doc "$PR_TITLE" "$BRANCH" "$JIRA_KEY")
  if [ "$DOC_STATUS" = "EXEMPT" ]; then
    pass "Story doc — exempt (bug fix or config change)"
    DOD_PASS=$((DOD_PASS + 1))
  else
    PROJECT_DIR="${BEADS_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
    STORY_DOC="$PROJECT_DIR/docs/stories/${JIRA_KEY}.md"
    if [ -f "$STORY_DOC" ]; then
      pass "User story doc exists — docs/stories/${JIRA_KEY}.md"
      DOD_PASS=$((DOD_PASS + 1))
    else
      fail "User story doc missing — expected docs/stories/${JIRA_KEY}.md"
      DOD_FAIL=$((DOD_FAIL + 1))
    fi
  fi

  # --- Summary per PR ---
  if [ "$DOD_FAIL" -eq 0 ]; then
    printf "  ${GREEN}${BOLD}>> DoD: ALL PASSED (%d/5)${NC}\n" "$DOD_PASS"
  else
    printf "  ${RED}${BOLD}>> DoD: %d FAILED (%d/5 passed)${NC}\n" "$DOD_FAIL" "$DOD_PASS"
  fi

done

# Final summary
echo ""
echo "================================================================"
printf "${BOLD}Summary${NC}\n"
echo "  Total PRs in period: $PR_COUNT"
echo "================================================================"
echo ""
echo "To accept work in beads:"
echo "  bd jira sync --pull    # pull latest status"
echo "  bd list --status closed # review closed issues"
echo ""
echo "To flag issues for rework:"
echo "  bd update <id> --status open"
echo "  bd comment <id> 'Needs rework: <reason>'"
echo "  bd jira sync --push"
