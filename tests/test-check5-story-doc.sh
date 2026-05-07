#!/usr/bin/env bash
#
# test-check5-story-doc.sh — RED/GREEN tests for Check 5 (story doc requirement)
#
# Tests that sprint-review.sh has a check_story_doc function which:
#   - Returns "REQUIRED" for normal feature PRs
#   - Returns "EXEMPT" for bug fix PRs (title/branch contains fix/bugfix/hotfix)
#   - Returns "EXEMPT" for config-only PRs (title/branch contains config/configuration)
#   - Returns "EXEMPT" for PRs with no Jira key
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SPRINT_REVIEW="$SCRIPT_DIR/../scripts/sprint-review.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

assert_eq() {
  local test_name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf "  ${GREEN}[PASS]${NC} %s\n" "$test_name"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    printf "  ${RED}[FAIL]${NC} %s (expected: %s, got: %s)\n" "$test_name" "$expected" "$actual"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo ""
printf "${BOLD}Test Suite: Check 5 — Story Doc Requirement${NC}\n"
echo "================================================================"

# --- Test 0: check_story_doc function exists in sprint-review.sh ---
if grep -q 'check_story_doc()' "$SPRINT_REVIEW"; then
  printf "  ${GREEN}[PASS]${NC} check_story_doc function exists\n"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  printf "  ${RED}[FAIL]${NC} check_story_doc function not found in sprint-review.sh\n"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo ""
  printf "${RED}${BOLD}RESULT: %d passed, %d failed${NC}\n" "$PASS_COUNT" "$FAIL_COUNT"
  exit 1
fi

# --- Test 1: Script header lists 5 DoD checks ---
if grep -q '#   5\.' "$SPRINT_REVIEW"; then
  printf "  ${GREEN}[PASS]${NC} Header lists Check 5\n"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  printf "  ${RED}[FAIL]${NC} Header does not list Check 5\n"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# --- Test 2: Summary shows /5 denominator ---
if grep -q '/5)' "$SPRINT_REVIEW"; then
  printf "  ${GREEN}[PASS]${NC} Summary denominator is /5\n"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  printf "  ${RED}[FAIL]${NC} Summary denominator is not /5\n"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Source only the function (don't run the full script)
# We source with a guard so the script doesn't execute
eval "$(sed -n '/^check_story_doc()/,/^}/p' "$SPRINT_REVIEW")"

echo ""
printf "${BOLD}Feature PRs — doc REQUIRED${NC}\n"

# --- Feature PR: normal title, doc required ---
assert_eq "Feature PR: 'TNG-42 Add user dashboard'" \
  "REQUIRED" \
  "$(check_story_doc "TNG-42 Add user dashboard" "feature/TNG-42-dashboard" "TNG-42")"

assert_eq "Feature PR: 'TNG-15 Implement login flow'" \
  "REQUIRED" \
  "$(check_story_doc "TNG-15 Implement login flow" "TNG-15-login" "TNG-15")"

echo ""
printf "${BOLD}Bug fix PRs — doc EXEMPT${NC}\n"

# --- Bug fix PRs: exempt from doc ---
assert_eq "Bug fix title: 'fix: TNG-10 null pointer in auth'" \
  "EXEMPT" \
  "$(check_story_doc "fix: TNG-10 null pointer in auth" "TNG-10-auth-fix" "TNG-10")"

assert_eq "Bug fix title: 'TNG-11 bugfix for login timeout'" \
  "EXEMPT" \
  "$(check_story_doc "TNG-11 bugfix for login timeout" "TNG-11-login" "TNG-11")"

assert_eq "Bug fix branch: 'TNG-12 update handler' on hotfix/ branch" \
  "EXEMPT" \
  "$(check_story_doc "TNG-12 update handler" "hotfix/TNG-12-handler" "TNG-12")"

assert_eq "Bug fix title: 'TNG-13 Fix broken pagination'" \
  "EXEMPT" \
  "$(check_story_doc "TNG-13 Fix broken pagination" "TNG-13-pagination" "TNG-13")"

echo ""
printf "${BOLD}Config PRs — doc EXEMPT${NC}\n"

# --- Config PRs: exempt from doc ---
assert_eq "Config title: 'TNG-20 config: update CI timeout'" \
  "EXEMPT" \
  "$(check_story_doc "TNG-20 config: update CI timeout" "TNG-20-ci" "TNG-20")"

assert_eq "Config title: 'TNG-21 update configuration for staging'" \
  "EXEMPT" \
  "$(check_story_doc "TNG-21 update configuration for staging" "TNG-21-staging" "TNG-21")"

echo ""
printf "${BOLD}No Jira key — doc EXEMPT${NC}\n"

# --- No Jira key: exempt ---
assert_eq "No Jira key: doc not required" \
  "EXEMPT" \
  "$(check_story_doc "update README" "update-readme" "")"

# --- Final summary ---
echo ""
echo "================================================================"
printf "${BOLD}RESULT: %d passed, %d failed${NC}\n" "$PASS_COUNT" "$FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
