#!/usr/bin/env bash
#
# sprint-metrics.sh — Multi-sprint trend metrics for DoD + flow
#
# Walks back N sprints (default 4, ending on the most recent Tuesday) and emits
# a markdown trend table to stdout plus a CSV file. Pulls PR data from gh and
# closed-issue counts + Jira keys from bd.
#
# Usage:
#   ./scripts/sprint-metrics.sh
#   ./scripts/sprint-metrics.sh --repo rideRTD/tis-next-gen --bd-dir ~/projects/tisng/tis-next-gen
#   ./scripts/sprint-metrics.sh --sprints 6 --end 2026-04-28
#   ./scripts/sprint-metrics.sh --csv /tmp/trend.csv
#
set -euo pipefail

REPO=""
BD_DIR=""
SPRINTS=4
END_DATE=""
CSV_OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)    REPO="$2"; shift 2;;
    --bd-dir)  BD_DIR="$2"; shift 2;;
    --sprints) SPRINTS="$2"; shift 2;;
    --end)     END_DATE="$2"; shift 2;;
    --csv)     CSV_OUT="$2"; shift 2;;
    -h|--help)
      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

# --- Repo + Jira prefix ---
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
fi
[ -z "$REPO" ] && { echo "Error: --repo required (or run inside a git repo)" >&2; exit 1; }
REPO_BASENAME=${REPO##*/}
PREFIX=$(echo "$REPO_BASENAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) printf toupper(substr($i,1,1))}')

PROJECT_DIR="${BEADS_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
BD_PATH="${BD_DIR:-$PROJECT_DIR}"

# --- Date helpers (BSD date on macOS, GNU date on Linux) ---
date_shift() {
  local n="$1" d="$2"
  date -j -v"${n}"d -f "%Y-%m-%d" "$d" "+%Y-%m-%d" 2>/dev/null \
    || date -d "$d $n days" "+%Y-%m-%d"
}
date_dow() {
  date -j -f "%Y-%m-%d" "$1" "+%u" 2>/dev/null || date -d "$1" "+%u"
}
recent_tuesday() {
  local d="$1" dow back
  dow=$(date_dow "$d")
  back=$(( (dow - 2 + 7) % 7 ))
  date_shift "-$back" "$d"
}

[ -z "$END_DATE" ] && END_DATE=$(recent_tuesday "$(date +%Y-%m-%d)")

# Sprint windows oldest -> newest
declare -a STARTS ENDS LABELS
for ((i=SPRINTS-1; i>=0; i--)); do
  E=$(date_shift "-$((i*14))" "$END_DATE")
  S=$(date_shift "-13" "$E")
  STARTS+=("$S"); ENDS+=("$E"); LABELS+=("$E")
done

pct() {
  local n="$1" d="$2"
  [ "$d" -eq 0 ] && { echo "n/a"; return; }
  echo "$(( n*100/d ))%"
}

# --- One gh call covering the full reporting window ---
GLOBAL_START="${STARTS[0]}T00:00:00Z"
GLOBAL_END="${ENDS[$((${#ENDS[@]}-1))]}T23:59:59Z"

ALL_PRS=$(gh pr list --repo "$REPO" --state merged --limit 500 \
  --json number,title,headRefName,createdAt,mergedAt,reviews,statusCheckRollup,author \
  --jq "[ .[] | select(.mergedAt >= \"$GLOBAL_START\" and .mergedAt <= \"$GLOBAL_END\") ]")

# --- Per-sprint metric arrays ---
declare -a M_PRS M_TAGGED M_DOD M_TESTS M_SONAR_PASS M_SONAR_PRES M_DOCS M_REVIEW M_AUTHORS M_MEDIAN M_BD M_PHANTOM

for i in "${!ENDS[@]}"; do
  S="${STARTS[$i]}"; E="${ENDS[$i]}"
  WIN=$(echo "$ALL_PRS" | jq --arg s "${S}T00:00:00Z" --arg e "${E}T23:59:59Z" \
    '[.[] | select(.mergedAt >= $s and .mergedAt <= $e)]')
  COUNT=$(echo "$WIN" | jq 'length')
  M_PRS+=("$COUNT")

  TAGGED=0; PASS_REVIEW=0; PASS_TESTS=0; PASS_SONAR=0; PRES_SONAR=0
  PASS_DOCS=0; PASS_ALL=0; DOC_REQ=0
  declare -a HOURS=()
  declare -a PR_KEYS=()

  if [ "$COUNT" -gt 0 ]; then
    while IFS= read -r pr; do
      TITLE=$(echo "$pr" | jq -r '.title')
      BRANCH=$(echo "$pr" | jq -r '.headRefName')
      CREATED=$(echo "$pr" | jq -r '.createdAt')
      MERGED=$(echo "$pr" | jq -r '.mergedAt')

      JKEY=""
      if [[ "$TITLE" =~ ($PREFIX-[0-9]+) ]]; then JKEY="${BASH_REMATCH[1]}"
      elif [[ "$BRANCH" =~ ($PREFIX-[0-9]+) ]]; then JKEY="${BASH_REMATCH[1]}"
      fi
      if [ -n "$JKEY" ]; then
        TAGGED=$((TAGGED+1))
        PR_KEYS+=("$JKEY")
      fi

      C_EP=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CREATED" "+%s" 2>/dev/null || date -d "$CREATED" "+%s")
      M_EP=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$MERGED" "+%s" 2>/dev/null || date -d "$MERGED" "+%s")
      HOURS+=( $(( (M_EP - C_EP) / 3600 )) )

      APPROVED=$(echo "$pr" | jq '[.reviews[] | select(.state == "APPROVED")] | length')
      R_OK=0; [ "$APPROVED" -gt 0 ] && { PASS_REVIEW=$((PASS_REVIEW+1)); R_OK=1; }

      BUILD=$(echo "$pr" | jq -r '[.statusCheckRollup[] | select(.name | test("Build.*Test|Gradle Build"))] | .[0].conclusion // "MISSING"')
      TESTS=$(echo "$pr" | jq -r '[.statusCheckRollup[] | select(.name == "Test Results")] | .[0].conclusion // "MISSING"')
      T_OK=0
      if [ "$BUILD" = "SUCCESS" ] && [ "$TESTS" = "SUCCESS" ]; then
        PASS_TESTS=$((PASS_TESTS+1)); T_OK=1
      fi

      SONAR=$(echo "$pr" | jq -r '[.statusCheckRollup[] | select(.name | test("[Ss]onar"))] | .[0].conclusion // "MISSING"')
      [ "$SONAR" = "SUCCESS" ] && PASS_SONAR=$((PASS_SONAR+1))
      [ "$SONAR" != "MISSING" ] && PRES_SONAR=$((PRES_SONAR+1))
      # DoD-strict treats MISSING as warn (pass) to match sprint-review.sh
      S_OK=0; { [ "$SONAR" = "SUCCESS" ] || [ "$SONAR" = "MISSING" ]; } && S_OK=1

      D_OK=1
      if [ -n "$JKEY" ]; then
        LOWER=$(echo "$TITLE $BRANCH" | tr '[:upper:]' '[:lower:]')
        if ! [[ "$LOWER" =~ (^|[^a-z])fix([^a-z]|$)|bugfix|hotfix|config ]]; then
          DOC_REQ=$((DOC_REQ+1))
          if [ -f "$PROJECT_DIR/docs/stories/${JKEY}.md" ]; then
            PASS_DOCS=$((PASS_DOCS+1))
          else
            D_OK=0
          fi
        fi
      fi

      if [ "$R_OK" = 1 ] && [ "$T_OK" = 1 ] && [ "$S_OK" = 1 ] && [ "$D_OK" = 1 ]; then
        PASS_ALL=$((PASS_ALL+1))
      fi
    done < <(echo "$WIN" | jq -c '.[]')
  fi

  M_TAGGED+=("$TAGGED")
  if [ "$COUNT" -eq 0 ]; then
    M_DOD+=("-"); M_TESTS+=("-"); M_SONAR_PASS+=("-"); M_SONAR_PRES+=("-")
    M_DOCS+=("-"); M_REVIEW+=("-"); M_AUTHORS+=("0"); M_MEDIAN+=("-")
  else
    M_DOD+=("$(pct $PASS_ALL $COUNT)")
    M_TESTS+=("$(pct $PASS_TESTS $COUNT)")
    M_SONAR_PASS+=("$(pct $PASS_SONAR $COUNT)")
    M_SONAR_PRES+=("$(pct $PRES_SONAR $COUNT)")
    M_REVIEW+=("$(pct $PASS_REVIEW $COUNT)")
    if [ "$DOC_REQ" -eq 0 ]; then M_DOCS+=("n/a"); else M_DOCS+=("$(pct $PASS_DOCS $DOC_REQ)"); fi
    AUTHORS=$(echo "$WIN" | jq '[.[].author.login] | unique | length')
    M_AUTHORS+=("$AUTHORS")
    SORTED=$(printf '%s\n' "${HOURS[@]}" | sort -n)
    N=${#HOURS[@]}; MID=$((N/2))
    if (( N % 2 == 1 )); then
      MED=$(echo "$SORTED" | sed -n "$((MID+1))p")
    else
      A1=$(echo "$SORTED" | sed -n "${MID}p"); A2=$(echo "$SORTED" | sed -n "$((MID+1))p")
      MED=$(( (A1+A2)/2 ))
    fi
    M_MEDIAN+=("${MED}h")
  fi

  # --- bd: closed-issue count + phantom-done cross-reference ---
  if [ -d "$BD_PATH/.beads" ]; then
    E_PLUS=$(date_shift "+1" "$E")
    BD_LINES=$( (cd "$BD_PATH" && bd list --all --closed-after "$S" --closed-before "$E_PLUS" --flat --limit 0 2>/dev/null) || true)
    BD_IDS=$(echo "$BD_LINES" | grep -oE '^✓ [a-z0-9-]+' | awk '{print $2}' || true)
    BD_CL=$([ -z "$BD_IDS" ] && echo 0 || echo "$BD_IDS" | wc -l | tr -d ' ')
    M_BD+=("$BD_CL")

    PHANTOM=0
    if [ "$BD_CL" -gt 0 ]; then
      PR_KEY_SET=" ${PR_KEYS[*]:-} "
      while IFS= read -r bid; do
        [ -z "$bid" ] && continue
        TNG=$( (cd "$BD_PATH" && bd show "$bid" 2>/dev/null) | grep -oE "${PREFIX}-[0-9]+" | head -1 || true)
        if [ -z "$TNG" ] || [[ "$PR_KEY_SET" != *" $TNG "* ]]; then
          PHANTOM=$((PHANTOM+1))
        fi
      done <<< "$BD_IDS"
    fi
    M_PHANTOM+=("$PHANTOM")
  else
    M_BD+=("-"); M_PHANTOM+=("-")
  fi

  unset HOURS PR_KEYS
done

# --- Render markdown ---
hdr=""; sep=""
for L in "${LABELS[@]}"; do hdr="$hdr | $L"; sep="$sep | ---"; done

echo
echo "# Sprint Metrics — $REPO"
echo "_Generated $(date +%Y-%m-%d) · ${#ENDS[@]} sprints ending ${END_DATE} · Jira prefix: ${PREFIX}_"
echo
echo "| Metric$hdr |"
echo "| ---$sep |"

print_row() {
  local label="$1"; shift
  local row="| $label"
  for v in "$@"; do row="$row | $v"; done
  echo "$row |"
}

print_row "PRs merged"                           "${M_PRS[@]}"
print_row "PRs with $PREFIX key"                 "${M_TAGGED[@]}"
print_row "DoD all-passed (lenient Sonar)"       "${M_DOD[@]}"
print_row "Tests passing (Build & Test Results)" "${M_TESTS[@]}"
print_row "Sonar passing (SUCCESS only)"         "${M_SONAR_PASS[@]}"
print_row "Sonar check present (adoption)"       "${M_SONAR_PRES[@]}"
print_row "Story doc present (when required)"    "${M_DOCS[@]}"
print_row "≥1 approval"                          "${M_REVIEW[@]}"
print_row "Distinct PR authors"                  "${M_AUTHORS[@]}"
print_row "Median time-to-merge"                 "${M_MEDIAN[@]}"
print_row "bd issues closed"                     "${M_BD[@]}"
print_row "Phantom-done (bd closed, no PR)"      "${M_PHANTOM[@]}"

# --- CSV ---
[ -z "$CSV_OUT" ] && CSV_OUT="$PROJECT_DIR/docs/metrics/sprint-trend-${END_DATE}.csv"
mkdir -p "$(dirname "$CSV_OUT")"

csv_row() {
  local label="$1"; shift
  printf '%s' "$label"
  for v in "$@"; do printf ',%s' "$v"; done
  echo
}

{
  printf 'metric'
  for L in "${LABELS[@]}"; do printf ',%s' "$L"; done
  echo
  csv_row prs_merged                "${M_PRS[@]}"
  csv_row prs_tagged                "${M_TAGGED[@]}"
  csv_row dod_all_passed_pct        "${M_DOD[@]}"
  csv_row tests_passing_pct         "${M_TESTS[@]}"
  csv_row sonar_passing_pct         "${M_SONAR_PASS[@]}"
  csv_row sonar_present_pct         "${M_SONAR_PRES[@]}"
  csv_row story_doc_pct             "${M_DOCS[@]}"
  csv_row approval_pct              "${M_REVIEW[@]}"
  csv_row distinct_authors          "${M_AUTHORS[@]}"
  csv_row median_time_to_merge      "${M_MEDIAN[@]}"
  csv_row bd_closed                 "${M_BD[@]}"
  csv_row phantom_done              "${M_PHANTOM[@]}"
} > "$CSV_OUT"

echo
echo "_CSV: ${CSV_OUT}_"
