Subject: TIS Next Gen — Automating Sprint Reviews with Beads

Hi team,

I've set up a tool called Beads to help automate our sprint reviews and enforce the Definition of Done we agreed to. Here's how it works.

---

## Our Definition of Done

Every story must meet these 4 checks before it's accepted:

1. Code in a PR and approved by at least one reviewer
2. Tests passing (Build & Test + Test Results CI checks)
3. PR merged to main
4. SonarCloud analysis passed (no new warnings)

---

## How It Works

Beads is an open source issue tracking tool that syncs with our Jira board. I've built a sprint review script on top of it that checks each merged PR against our DoD automatically using GitHub data — reviews, CI results, and SonarCloud status.

No manual tracking. No spreadsheets. The script checks the facts.

---

## Sprint Review Meeting Flow (Every Other Tuesday)

### Step 1 — Demo (~30 min)
Each developer demos their completed work:
- Walk through what was built and why
- Show it working (live or screenshot)
- Team asks questions

This is the qualitative check — does it do what we intended?

### Step 2 — DoD Verification (~10 min)
I run the report live or share results I ran beforehand:
```
./scripts/sprint-review.sh 14
```
We walk through the output together:
- **4/4 PASS** — accepted, move on
- **FAIL** — discuss: real gap or explainable?
- **WARN** — note for process improvement

This is the objective check — did we follow our process?

### Step 3 — Decisions (~5 min)
- Accept or reject each item
- Rejected items carry to next sprint
- Note any DoD improvements for retro

Demo first so the team can show their work, then the script confirms it with hard evidence. Over time this becomes a quick formality as everyone follows the process.

### Behind the Scenes (What I Do as PO)

Before the meeting:
1. Sync Jira issues into Beads:
   ```
   bd jira sync --pull
   ```
2. Run the sprint review report:
   ```
   ./scripts/sprint-review.sh 14
   ```

After the meeting:
3. Sync accepted/rejected status back to Jira:
   ```
   bd jira sync --push
   ```

If I miss a meeting, I run the same steps async. The report is the objective record.

---

## Getting Set Up

Run this once from the repo:

```
./scripts/dev-setup.sh
```

This installs everything and sets up git hooks that:
- Remind you of ready tasks after `git pull`
- Auto-add the TNG key to your commit messages from the branch name
- Warn if you push a branch with no TNG key
- Remind you to close your task when pushing

Also, when your PR merges to main, the CI will automatically close the beads task and sync to Jira. No manual status updates needed.

---

## What You Need to Do

1. **Put the Jira key in your branch name or PR title** — e.g. `TNG-37` or `TNG-37-blob-export`. The hooks and CI use this to link everything together. No key = flagged as a warning.

2. **Make sure CI passes before merging** — Build & Test, Test Results, and SonarCloud all get checked.

3. **Get at least one approval** before merging.

That's it. The hooks and CI handle the rest. See `docs/team-workflow.md` for the full workflow and quick reference.

---

## Check Your Own Work

You can verify any PR against the DoD yourself:

```
./scripts/sprint-review.sh --pr 43
./scripts/sprint-review.sh --pr TNG-9
```

Or review the full sprint:

```
./scripts/sprint-review.sh
```

---

## Example — Sprint Ending Tuesday March 3rd

I wasn't able to attend the sprint review on Tuesday, so I ran the script to catch up. Here are the results for the last 14 days:

```
Sprint Review — DoD Verification
Repository: rideRTD/tis-next-gen
Period:     last 14 days (since 2026-02-19)
================================================================

PR #44 — TNG-37 - Add scheduled GTFS-RT protobuf file export to Azure Blob Storage
  Jira: TNG-37        Branch: TNG-37          Author: hugh-rtd
  [PASS] Code reviewed — approved by: ab21882
  [PASS] Tests passing — Build & Test: SUCCESS, Test Results: SUCCESS
  [PASS] PR merged to main
  [PASS] SonarCloud analysis passed
  >> DoD: ALL PASSED (4/4)

PR #43 — TNG 9 get Service alerts file from AWS S3 bucket and publish to kafka topic
  Jira: TNG-9         Branch: TNG-9-FeedSubscription          Author: ab21882
  [PASS] Code reviewed — approved by: hugh-rtd
  [PASS] Tests passing — Build & Test: SUCCESS, Test Results: SUCCESS
  [PASS] PR merged to main
  [PASS] SonarCloud analysis passed
  >> DoD: ALL PASSED (4/4)

PR #42 — TNG-149 - Enable JWT authentication through Spring Security
  Jira: TNG-149       Branch: TNG-149                         Author: hugh-rtd
  [PASS] Code reviewed — approved by: ab21882
  [PASS] Tests passing — Build & Test: SUCCESS, Test Results: SUCCESS
  [PASS] PR merged to main
  [PASS] SonarCloud analysis passed
  >> DoD: ALL PASSED (4/4)

PR #41 — Fix spotless import styling to match Sonarqube standards
  [WARN] No TNG issue key found in PR title or branch — skipping DoD check

PR #40 — TNG-122 - Configure Automated GitHub Actions Test Workflow
  Jira: TNG-122       Branch: enable-unit-tests               Author: hugh-rtd
  [PASS] Code reviewed — approved by: ab21882
  [PASS] Tests passing — Build & Test: SUCCESS, Test Results: SUCCESS
  [PASS] PR merged to main
  [PASS] SonarCloud analysis passed
  >> DoD: ALL PASSED (4/4)

PR #39 — TNG-148 - Fix realtime debug endpoint counts
  Jira: TNG-148       Branch: TNG-147-fix                     Author: hugh-rtd
  [PASS] Code reviewed — approved by: ab21882
  [FAIL] No test checks found on this PR
  [PASS] PR merged to main
  [PASS] SonarCloud analysis passed
  >> DoD: 1 FAILED (3/4 passed)

PR #38 — Tng 147 vehicle position by route
  Jira: TNG-147       Branch: TNG-147-vehiclePositionByRoute  Author: ab21882
  [PASS] Code reviewed — approved by: hugh-rtd
  [FAIL] No test checks found on this PR
  [PASS] PR merged to main
  [PASS] SonarCloud analysis passed
  >> DoD: 1 FAILED (3/4 passed)

PR #37 — TNG-150 - Upgrade Spring Boot to Version 4.0.2
  Jira: TNG-150       Branch: TNG-150-b                       Author: hugh-rtd
  [PASS] Code reviewed — approved by: ab21882
  [PASS] Tests passing — Build & Test: SUCCESS, Test Results: SUCCESS
  [PASS] PR merged to main
  [PASS] SonarCloud analysis passed
  >> DoD: ALL PASSED (4/4)

================================================================
Summary: 8 PRs — 5 passed, 2 failed, 1 warning
================================================================
```

**Notes:**
- TNG-148 and TNG-147 failed the test check because they were merged before the CI test workflow (TNG-122) was set up. These are accepted — not a process issue.
- PR #41 has no Jira key in the branch or title. Going forward, please include the TNG key so the script can link it.

---

The goal is simple — automate what we can so sprint reviews are quick and consistent. Once we finalize the DoD as a team, I'll update the script with any changes.

James
