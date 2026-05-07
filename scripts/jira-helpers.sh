#!/usr/bin/env bash
#
# jira-helpers.sh — Sourced library of Jira REST helpers used by
# story-start.sh and story-finish.sh. Not meant to be invoked directly.
#
# Resolves Jira creds in this order:
#   1. $JIRA_API_TOKEN + $JIRA_EMAIL + $JIRA_URL env vars (preferred for CI)
#   2. bd config (jira.api_token, jira.email, jira.url) — for users who
#      already have beads configured.
#
# Exposes:
#   _jira_setup                       Load creds; exit 1 if not findable.
#   _jira_curl <method> <path> [data] Authenticated curl. Returns body.
#                                     Sets $JIRA_HTTP to the status code.
#   _jira_my_account_id               Echo the account ID of the auth'd user.
#   _jira_board_id_for_project <key>  Echo the agile-board ID for a project.
#   _jira_active_sprint_id <board-id> Echo the active sprint's ID.
#   _jira_add_to_sprint <key> <sprint-id>
#   _jira_transition <key> <status-name>     Case-insensitive name match.
#   _jira_assign <key> <accountId|me|email>
#   _jira_status <key>                       Echo current status name.

set -euo pipefail

_jira_setup() {
  if [ -n "${JIRA_API_TOKEN:-}" ] && [ -n "${JIRA_EMAIL:-}" ] && [ -n "${JIRA_URL:-}" ]; then
    return 0
  fi

  if command -v bd >/dev/null 2>&1; then
    local token email url
    token=$(bd config get jira.api_token 2>/dev/null | sed 's/^.*= //')
    email=$(bd config get jira.email     2>/dev/null | sed 's/^.*= //')
    url=$(bd   config get jira.url       2>/dev/null | sed 's/^.*= //')
    if [ -n "$token" ] && [ -n "$email" ] && [ -n "$url" ]; then
      export JIRA_API_TOKEN="$token"
      export JIRA_EMAIL="$email"
      export JIRA_URL="$url"
      return 0
    fi
  fi

  cat >&2 <<EOF
ERROR: Jira credentials not found. Set one of:
  export JIRA_URL=https://yourorg.atlassian.net
  export JIRA_EMAIL=you@example.com
  export JIRA_API_TOKEN=<your-token>

Or configure bd:
  bd config set jira.url https://yourorg.atlassian.net
  bd config set jira.email you@example.com
  bd config set jira.api_token <your-token>
EOF
  exit 1
}

_jira_curl() {
  local method="$1"; shift
  local path="$1"; shift
  local data="${1:-}"
  local out body http
  out=$(mktemp)
  if [ -n "$data" ]; then
    http=$(curl -s -o "$out" -w "%{http_code}" \
      --user "$JIRA_EMAIL:$JIRA_API_TOKEN" \
      -H "Content-Type: application/json" \
      -X "$method" "$JIRA_URL$path" -d "$data")
  else
    http=$(curl -s -o "$out" -w "%{http_code}" \
      --user "$JIRA_EMAIL:$JIRA_API_TOKEN" \
      -X "$method" "$JIRA_URL$path")
  fi
  body=$(cat "$out")
  rm -f "$out"
  export JIRA_HTTP="$http"
  printf '%s' "$body"
}

_jira_my_account_id() {
  _jira_curl GET /rest/api/3/myself \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["accountId"])'
}

_jira_board_id_for_project() {
  local project_key="$1"
  _jira_curl GET "/rest/agile/1.0/board?projectKeyOrId=$project_key" \
    | python3 -c '
import sys, json
data = json.load(sys.stdin)
boards = data.get("values", [])
if not boards:
    sys.exit(1)
# Prefer scrum boards; otherwise first match
for b in boards:
    if b.get("type") == "scrum":
        print(b["id"]); sys.exit(0)
print(boards[0]["id"])
'
}

_jira_active_sprint_id() {
  local board_id="$1"
  _jira_curl GET "/rest/agile/1.0/board/$board_id/sprint?state=active" \
    | python3 -c '
import sys, json
data = json.load(sys.stdin)
sprints = data.get("values", [])
if not sprints:
    sys.exit(1)
print(sprints[0]["id"])
'
}

_jira_add_to_sprint() {
  local issue_key="$1" sprint_id="$2"
  _jira_curl POST "/rest/agile/1.0/sprint/$sprint_id/issue" \
    "{\"issues\":[\"$issue_key\"]}" >/dev/null
  case "$JIRA_HTTP" in
    20*|204) return 0 ;;
    *) echo "ERROR: add-to-sprint $issue_key → $sprint_id failed (HTTP $JIRA_HTTP)" >&2
       return 1 ;;
  esac
}

_jira_transition() {
  local issue_key="$1" target_name="$2"
  local transitions transition_id
  transitions=$(_jira_curl GET "/rest/api/3/issue/$issue_key/transitions")
  transition_id=$(echo "$transitions" | python3 -c "
import sys, json
data = json.load(sys.stdin)
target = '$target_name'.lower()
for t in data.get('transitions', []):
    if t['to']['name'].lower() == target:
        print(t['id']); sys.exit(0)
sys.exit(1)
" 2>/dev/null) || {
    echo "ERROR: no transition to '$target_name' available for $issue_key" >&2
    echo "Available targets:" >&2
    echo "$transitions" | python3 -c "
import sys, json
for t in json.load(sys.stdin).get('transitions', []):
    print(f\"  → {t['to']['name']}\")
" >&2
    return 1
  }
  _jira_curl POST "/rest/api/3/issue/$issue_key/transitions" \
    "{\"transition\":{\"id\":\"$transition_id\"}}" >/dev/null
  case "$JIRA_HTTP" in
    20*|204) return 0 ;;
    *) echo "ERROR: transition $issue_key → $target_name failed (HTTP $JIRA_HTTP)" >&2
       return 1 ;;
  esac
}

_jira_assign() {
  local issue_key="$1" who="$2"
  local account_id

  case "$who" in
    me) account_id=$(_jira_my_account_id) ;;
    *@*)
      # Email — search for the account ID
      account_id=$(_jira_curl GET "/rest/api/3/user/search?query=$who" \
        | python3 -c "
import sys, json
users = json.load(sys.stdin)
if not users: sys.exit(1)
print(users[0]['accountId'])
" 2>/dev/null) || {
        echo "ERROR: no Jira user found for email $who" >&2
        return 1
      }
      ;;
    *) account_id="$who" ;;  # assume already an accountId
  esac

  _jira_curl PUT "/rest/api/3/issue/$issue_key/assignee" \
    "{\"accountId\":\"$account_id\"}" >/dev/null
  case "$JIRA_HTTP" in
    20*|204) return 0 ;;
    *) echo "ERROR: assign $issue_key → $who failed (HTTP $JIRA_HTTP)" >&2
       return 1 ;;
  esac
}

_jira_status() {
  local issue_key="$1"
  _jira_curl GET "/rest/api/3/issue/$issue_key?fields=status" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['fields']['status']['name'])"
}
