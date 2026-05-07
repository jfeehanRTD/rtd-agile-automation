# Getting Started — Beads + Jira for RTD Devs

A one-page setup guide for adopting `bd` (Beads) as your Jira automation. Covers two paths: **joining an existing project** (e.g. `tis-next-gen`, where James already wired everything up) and **starting fresh in a new project**.

---

## Prerequisites

Install once on your machine:

```bash
brew install beads jq gh
```

Verify:

```bash
bd version && jq --version && gh --version
```

---

## Get a Jira API token (one time per person)

1. Go to https://id.atlassian.com/manage-profile/security/api-tokens
2. Create token, label it `bd-cli`, copy the value
3. Add to `~/.zshrc` (or `~/.bashrc`):

   ```bash
   export JIRA_API_TOKEN="paste-token-here"
   ```

4. Reload your shell: `source ~/.zshrc`

The token is **personal** — don't commit it, don't share it. `bd` reads it from the env var; nothing on disk.

---

## Path A — Joining an existing bd-enabled project

Use this for `tis-next-gen` and any other repo where `.beads/config.yaml` already exists.

```bash
git clone git@github.com:rideRTD/tis-next-gen.git
cd tis-next-gen

# Pull the metadata branch — bd state syncs through this branch because main is protected
git fetch origin beads-metadata

# Run the setup script (installs hooks, verifies bd, etc.)
./scripts/dev-setup.sh

# Pull the latest Jira state into your local bd db
bd jira sync --pull
```

That's it. Try `bd ready` to see what's open.

> **No need to configure jira.url / jira.project / priority_map / type_map** — those live in the repo's `.beads/config.yaml` and you inherit them by cloning.

---

## Path B — Setting up a new project

Use this when you want to add bd+Jira to a project that doesn't have it yet.

### 1. Initialize beads

```bash
cd your-project
bd init
```

### 2. Configure Jira sync

```bash
bd config set jira.url        "https://rtddevteams.atlassian.net"
bd config set jira.project    "PROJ"                    # your Jira project key
bd config set jira.username   "you@rtd-denver.com"
```

### 3. Configure the priority_map (REQUIRED — undocumented gotcha)

Without this, `bd jira sync --push` fails with a 400 on the priority field. The CLI help doesn't mention it.

```bash
bd config set jira.priority_map "0:Critical/Blocker,1:High,2:Medium,3:Low,4:Informational"
```

### 4. Configure the type_map

Map bd issue types → your Jira project's issue types. For TNG-style projects:

```bash
bd config set jira.type_map "bug:Task,feature:Story,task:Task,epic:Epic,chore:Task"
```

Adjust if your Jira project has different types (e.g. if `Bug` exists, map `bug:Bug`).

### 5. If `main` is protected, redirect bd's git sync

bd writes a metadata branch back to the remote. If you can't push to main, point it at a separate branch:

```bash
# .beads/config.yaml
git:
  sync_branch: "beads-metadata"

# disable git-push backup since the metadata branch is your off-machine backup
backup:
  git-push: false
```

(Jira itself becomes the secondary backup.)

### 6. Copy in the RTD automation scripts

```bash
cp -r ~/projects/rtd-agile-automation/scripts/ ./scripts/
cp ~/projects/rtd-agile-automation/.github/workflows/beads-auto-close.yml \
   ./.github/workflows/
```

### 7. Run dev-setup

```bash
./scripts/dev-setup.sh
```

This installs the git hooks (auto-tag commits with the Jira key from your branch, warn on missing key, post-merge ready-task reminder).

### 8. Add the GHA secret

In GitHub: **Settings → Secrets and variables → Actions → New repository secret**

- Name: `JIRA_API_TOKEN`
- Value: the same token you put in `~/.zshrc`

This lets `beads-auto-close.yml` push back to Jira when PRs merge.

### 9. First sync

```bash
bd jira sync --pull
bd list
```

You should see your Jira issues mirrored in bd.

---

## Daily workflow (cheat sheet)

```bash
bd ready                       # what can I work on right now?
bd update <id> --claim         # take it (sets assignee + in_progress)
# branch as PROJ-123-short-description; hooks auto-tag your commits
git push                       # pre-push hook warns if no Jira key
# open PR, get a review, merge when CI is green
bd close <id> --reason "Merged in #42"   # or let beads-auto-close.yml do it
bd jira sync --push            # if you made local edits you want in Jira
```

See [team-workflow.md](team-workflow.md) for the full workflow doc.

---

## Common gotchas

- **`bd jira sync --push` fails on priority** → you skipped step 3 (priority_map).
- **Hook didn't tag the commit** → branch name doesn't start with `PROJ-NNN-`. The hook parses the branch name; rename it.
- **`bd ready` is empty** → either nothing's unblocked, or you haven't run `bd jira sync --pull` recently.
- **`bd init` complained** → you're inside another bd-enabled project's directory. `cd` out first.
- **GHA workflow can't sync back** → `JIRA_API_TOKEN` GHA secret missing or wrong (step 8).

---

## Where things live

| Thing                        | Location                                                   |
|------------------------------|------------------------------------------------------------|
| bd config (per project)      | `.beads/config.yaml`                                       |
| bd database                  | `.beads/beads.db` (gitignored; state syncs via metadata branch) |
| Jira API token               | `~/.zshrc` env var `JIRA_API_TOKEN`                        |
| Custom git hooks             | `.beads/hooks/` (installed by `install-hooks.sh`)          |
| Sprint review script         | `scripts/sprint-review.sh`                                 |
| Auto-close workflow          | `.github/workflows/beads-auto-close.yml`                   |

---

## Help

- `bd help` — full command list
- `bd <command> --help` — flags for one command
- Beads upstream: https://github.com/steveyegge/beads
- Ask James if a sync goes sideways — most issues are config, not bd itself.
