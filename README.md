# RTD Agile Automation

Lightweight agile workflow automation for RTD dev teams, built on [Beads](https://github.com/steveyegge/beads).

Replaces manual agile ceremonies with automated tooling: sprint review DoD verification, Jira sync, git hooks, and auto-close on PR merge.

## What's In Here

```
scripts/
  sprint-review.sh       # Automated Definition of Done verification
  dev-setup.sh           # One-time developer onboarding
  install-hooks.sh       # Git hook installer
  hooks/
    post-merge           # Reminds devs of ready tasks after git pull
    prepare-commit-msg   # Auto-tags commits with Jira key from branch name
    pre-push             # Warns if branch has no Jira key

.github/workflows/
  beads-auto-close.yml   # Auto-closes beads tasks when PRs merge

docs/
  team-workflow.md       # How we work (replaces agile handbook)
  sprint-review-email.md # Team email template
  pm-pre-email.md        # PM pre-email template
  cito-pre-email.md      # Leadership pre-email template
  beads-servicenow-talking-points.md  # ServiceNow integration pitch
```

## Prerequisites

- [Beads](https://github.com/steveyegge/beads) (`brew install beads`)
- [GitHub CLI](https://cli.github.com/) (`brew install gh`)
- [jq](https://jqlang.github.io/jq/) (`brew install jq`)

## Setup for a New Project

### 1. Install beads and initialize

```bash
brew install beads
cd your-project
bd init
```

### 2. Configure Jira sync

```bash
bd config set jira.url "https://yourcompany.atlassian.net"
bd config set jira.project "PROJ"
bd config set jira.username "you@company.com"
export JIRA_API_TOKEN="your-token"  # add to ~/.zshrc
```

### 3. Copy scripts to your project

```bash
cp -r /path/to/rtd-agile-automation/scripts/ your-project/scripts/
cp /path/to/rtd-agile-automation/.github/workflows/beads-auto-close.yml your-project/.github/workflows/
```

### 4. Install hooks and run setup

```bash
cd your-project
./scripts/dev-setup.sh
```

### 5. Add JIRA_API_TOKEN to GitHub Secrets

Go to your repo Settings > Secrets > Actions > add `JIRA_API_TOKEN`

## Daily Workflow

```bash
bd ready                      # What can I work on?
bd update <id> --claim        # Claim a task
# branch as PROJ-123-description, hooks auto-tag commits
# open PR, get review, merge when CI passes
bd close <id> --reason "Done" # Or let CI auto-close on merge
```

## Sprint Review (Every 2 Weeks)

```bash
# Before the meeting — sync and run report
bd jira sync --pull
./scripts/sprint-review.sh 14

# Check a single PR
./scripts/sprint-review.sh --pr 43
./scripts/sprint-review.sh --pr TNG-9

# After the meeting — sync results back
bd jira sync --push
```

## Definition of Done (Checked Automatically)

1. Code in a PR and approved by at least one reviewer
2. Tests passing (Build & Test + Test Results CI checks)
3. PR merged to main
4. SonarCloud analysis passed (no new warnings)

## What This Replaces

| Before | Now |
|--------|-----|
| Daily standup | `bd ready` |
| Sprint planning meeting | PO sets priorities in beads |
| "What should I work on?" | `bd ready` |
| Manual Jira status updates | `bd jira sync` |
| Verbal "is it done?" | `sprint-review.sh` |
| Sprint review slide deck | `sprint-review.sh 14` |

## Git Hooks (Installed Automatically)

| Hook | What it does |
|------|-------------|
| post-merge | Shows ready task count after `git pull` |
| prepare-commit-msg | Prepends Jira key from branch name to commits |
| pre-push | Warns if branch has no Jira key |

## License

MIT
