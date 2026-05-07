# Sprint Review — March 17, 2026

**Project:** TIS Next Gen (TNG)
**Sprint:** Ending 2026-03-17
**Board:** [TNG Board](https://rtddevteams.atlassian.net/jira/software/projects/TNG/boards/467)

---

## DoD Script Results

Ran `sprint-review.sh 14` against rideRTD/tis-next-gen (March 3–17).

### PRs with full DoD pass (4/4)

| PR | Jira Key | Title | Author | Merged |
|----|----------|-------|--------|--------|
| #47 | TNG-159 | Add alert data to the realtime debug API endpoint | hugh-rtd | 2026-03-12 |
| #45 | TNG-9 | Service alerts API | ab21882 | 2026-03-11 |

### PRs skipped (no Jira key)

| PR | Title | Author | Merged |
|----|-------|--------|--------|
| #46 | Add ACR-based CI/CD pipeline and Azure VM deploy script | — | 2026-03-17 |

PR #46 has no TNG key in the branch or title. Needs a Jira key assigned retroactively or documented as infrastructure work.

---

## Gap: Jira "Done" with no matching PRs

6 stories marked Done on the Jira board. Only 2 have verified merged PRs (TNG-159, TNG-9). The following 5 have **no PRs, commits, or code changes** in the tis-next-gen repo:

| Jira Key | Found in PRs? | Found in commits? |
|----------|---------------|-------------------|
| TNG-4 | No | No |.   Branch Naming conv fix
| TNG-43 | No | No |.  0 point = cancel/
| TNG-140 | No | No | Passed
| TNG-151 | No | No | Passed no code
| TNG-158 | No | No | Passed no code

**Action needed:** Determine for each whether it was:
1. Non-code work (design, documentation, config) — mark as such in Jira
2. Completed under a different PR/key — link the PR in the Jira ticket
3. Moved to Done prematurely — reopen if work is incomplete

---

## Summary

- **2 stories verified done** via DoD (TNG-159, TNG-9) — all 4 checks passed
- **5 stories unverified** — marked Done in Jira with no code trail
- **1 PR missing Jira key** (#46) — needs retroactive tagging
- **Team action:** Reinforce that every PR needs a TNG-xxx key in branch or title so the DoD script can track it
