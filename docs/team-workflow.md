# TIS Next Gen — How We Work

We're a small team (2 devs + architect/PO). We don't have the staff for full agile ceremonies, so we automate what we can and skip what we don't need.

---

## The System

```
James sets priorities + dependencies in Beads
    ↓
Beads syncs from Jira:    bd jira sync --pull
    ↓
Devs check what's ready:  bd ready
    ↓
Dev claims a task:         bd update <id> --claim
    ↓
Dev does the work, opens PR with TNG-xxx in branch/title
    ↓
PR gets reviewed, CI passes, merged to main
    ↓
Dev closes the task:       bd close <id>
    ↓
Every 2 weeks (Tuesday):  sprint review script checks DoD
    ↓
Results sync back:         bd jira sync --push
```

---

## First-Time Setup

Run this once after cloning the repo:

```
./scripts/dev-setup.sh
```

This installs the bd CLI, initializes beads, and sets up git hooks that:
- Remind you of ready tasks after `git pull`
- Auto-add the TNG key to your commit messages from the branch name
- Warn if you push a branch with no TNG key
- Remind you to close your beads task when pushing

---

## Daily Workflow (No Standup Needed)

### For devs

1. **Start of day** — find your work:
   ```
   bd ready
   ```
   This shows tasks with no blockers, sorted by priority. Pick the top one.

2. **Claim it** so nobody doubles up:
   ```
   bd update <id> --claim
   ```

3. **Do the work.** Branch naming: `TNG-xxx-short-description`

4. **Open a PR.** Include `TNG-xxx` in the title. Get a review from the other dev.

5. **Merge when CI passes** (Build & Test, Test Results, SonarCloud).

6. **Close the task:**
   ```
   bd close <id> --reason "Merged in PR #xx"
   ```

7. **Found something else while working?** File it:
   ```
   bd create "Found a bug in X" -p 1 --deps discovered-from:<current-task-id>
   ```

8. **Blocked?** Check what's in the way:
   ```
   bd blocked
   ```
   Talk to James if it's a decision or external dependency.

### For James (architect/PO)

1. **Weekly** — sync Jira and set priorities:
   ```
   bd jira sync --pull
   bd list
   ```
   Add dependencies, acceptance criteria, design notes:
   ```
   bd update <id> --acceptance "Must handle 10k events/sec"
   bd update <id> --design "Use Kafka Streams with exactly-once"
   bd dep add <task-B> <task-A>    # B can't start until A is done
   ```

2. **Push updates back to Jira** so PM has visibility:
   ```
   bd jira sync --push
   ```

3. **Every 2 weeks (sprint Tuesday)** — run DoD check:
   ```
   ./scripts/sprint-review.sh 14
   ```
   Accept or reject. Sync results.

---

## What We Replaced

| Before (wagile)                | Now (automated)                          |
|--------------------------------|------------------------------------------|
| Daily standup meeting          | `bd ready` — self-serve, no meeting      |
| Sprint planning meeting        | James sets priorities in beads            |
| "What should I work on?" Slack | `bd ready` — always has the answer        |
| Manual status updates in Jira  | `bd jira sync` — automatic               |
| Verbal "is it done?" checks    | Sprint review script checks GitHub/CI    |
| Sprint review slide deck       | `./scripts/sprint-review.sh 14`          |
| Assigning work in meetings     | `bd update <id> --claim` — self-service  |

---

## Rules

1. **Every PR needs a TNG-xxx key** in the branch name or PR title. No exceptions.
2. **Every PR needs one approval** before merge.
3. **CI must pass** before merge — Build & Test, Test Results, SonarCloud.
4. **Claim before you start** — `bd update <id> --claim` prevents double work.
5. **Close when done** — `bd close <id>` so the system knows it's finished.

---

## Quick Reference

```
bd ready                         # What can I work on?
bd update <id> --claim           # I'm taking this one
bd show <id>                     # Show me the details
bd blocked                       # What's stuck and why?
bd close <id> --reason "Done"    # I'm finished
bd create "Title" -p 1           # New task
bd dep add <B> <A>               # B depends on A
bd jira sync                     # Sync with Jira
./scripts/sprint-review.sh 14   # Sprint DoD report
./scripts/sprint-review.sh --pr 43  # Check one PR
```
