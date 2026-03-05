# RTD Agile Automation

Lightweight agile workflow automation for RTD dev teams, built on [Beads](https://github.com/steveyegge/beads).

## Project Context

- **Owner**: James Feehan (Software Architect + Product Owner, RTD Denver)
- **Repo**: `jfeehanRTD/rtd-agile-automation`
- **Purpose**: Replace manual agile ceremonies ("wagile") with automated tooling
- **Team**: 2 devs (hugh-rtd, ab21882), 1 PM (new to agile)
- **Org**: Deputy CITO pushing agile adoption; CITO prefers ServiceNow over Jira

## Key Files

- `scripts/sprint-review.sh` — DoD verification against GitHub PR data (reviews, CI checks, SonarCloud)
- `scripts/dev-setup.sh` — One-time developer onboarding (installs beads, hooks)
- `scripts/install-hooks.sh` — Git hook installer (idempotent, uses markers)
- `scripts/hooks/` — post-merge, prepare-commit-msg, pre-push hooks
- `.github/workflows/beads-auto-close.yml` — Auto-closes beads tasks on PR merge, syncs Jira
- `docs/team-workflow.md` — How the team works (replaces agile handbook)
- `docs/sprint-review-email.md` — Team email introducing DoD automation
- `docs/pm-pre-email.md` — PM pre-email (waiting to send)
- `docs/cito-pre-email.md` — Deputy CITO pre-email (sent)
- `docs/beads-servicenow-talking-points.md` — ServiceNow integration pitch

## Definition of Done (4 Checks)

1. Code in PR and approved by at least one reviewer
2. Tests passing (Build & Test + Test Results CI checks)
3. PR merged to main
4. SonarCloud analysis passed (no new warnings)

## Related Projects

- **tis-next-gen** (`~/projects/tisng/tis-next-gen`): Primary project using this automation
  - Beads initialized with Dolt backend, Jira sync configured (TNG project)
  - Metadata branch: `beads-metadata` (main is protected)
  - Jira: `rtddevteams.atlassian.net`, project TNG
  - JIRA_API_TOKEN set in `~/.zshrc` and as GitHub Secret
- **RtdCICD/jci** (`~/projects/agent1`): Java CI/CD CLI tool (separate, not integrated here)
- **RTD-DevOps** (`~/projects/RTD-DevOps`): MCP server for dev onboarding (separate)

## Conventions

- Beads-only integration (deliberately simplified from earlier 3-tool approach)
- No Claude slash commands — keep it simple for the org
- Sprint cadence: 2 weeks, ends on Tuesdays
- Sprint review flow: Demo (30min) -> DoD Script (10min) -> Decisions (5min)
- Generalized scripts auto-detect repo and Jira prefix from git remote
