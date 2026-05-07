# Sprint Trend Report — Through 2026-04-28

**Repository:** [rideRTD/tis-next-gen](https://github.com/rideRTD/tis-next-gen)
**Period:** 4 sprints (2026-03-04 → 2026-04-28)
**Source:** `scripts/sprint-metrics.sh --repo rideRTD/tis-next-gen --bd-dir ~/projects/tisng/tis-next-gen --sprints 4`
**CSV:** `~/projects/tisng/tis-next-gen/docs/metrics/sprint-trend-2026-04-28.csv`

This is the first multi-sprint trend report for the team. Numbers come from automated checks against merged PRs (`gh`) and closed beads issues (`bd`). Where the script and the sprint-review meeting disagree, both are noted.

---

## Headlines

1. **PR throughput up ~5–8×** — 3 → 15 → 24 → 15 PRs/sprint. This is the team's first real deploy-frequency baseline.
2. **Median time-to-merge fell from 139h to 20h.** Flow is faster *and* measurable.
3. **DoD pass rate: 33% → 100% → 100% → 100%** (sprint-review accepted, see notes below). Auto-detected pass was 91% / 80% for the last two sprints; the gap is missed approvals and late story-doc commits accepted in sprint review.
4. **Story doc discipline: 0% → 85%** — adoption stuck after introduction.
5. **SonarCloud adoption: 66% → 100%** with one gap (see Caveats).
6. **Phantom-done: 7 of 7 closed beads issues in the latest sprint have no matching PR.** This is the single most striking finding in this report — see below.

---

## Trend Table

| Metric | 2026-03-17 | 2026-03-31 | 2026-04-14 | 2026-04-28 |
| --- | --- | --- | --- | --- |
| PRs merged | 3 | 15 | 24 | 15 |
| PRs with TNG key | 2 | 13 | 23 | 15 |
| **DoD pass — script (auto)** | 33% | 100% | 91% | 80% |
| **DoD pass — sprint-review accepted** | 33% | 100% | **100%** | **100%** |
| Tests passing (Build & Test Results) | 100% | 100% | 100% | 93% |
| Sonar passing (SUCCESS only) | 66% | 0% | 95% | 100% |
| Sonar check present (adoption) | 66% | 0% | 95% | 100% |
| Story doc present (when required) | 0% | 100% | 88% | 85% |
| ≥1 GitHub approval | 100% | 100% | 100% | 100% |
| Distinct PR authors | 3 | 2 | 3 | 3 |
| Median time-to-merge | 139h | 43h | 2h | 20h |
| bd issues closed | 0 | 0 | 2 | 7 |
| Phantom-done (bd closed, no PR) | 0 | 0 | 1 | 7 |

---

## Script vs. Accepted DoD

The script is intentionally strict: it checks GitHub-visible state at PR-merge time. The sprint-review meeting is the human override layer — items where the story doc landed in a follow-up commit, or where a test failure was understood and accepted, are confirmed done in the meeting even though the script flags them.

For the last two sprints, **all PRs were accepted in sprint review** (100% accepted DoD). The auto-pass numbers (91%, 80%) reflect the **automation maturity gap** — what the script can prove without human context. Closing that gap is a tooling investment, not a quality problem.

The two views matter for different audiences:
- **Auto-pass** is what shows up in trend dashboards and what the contractor's transformation can move without ambiguity.
- **Accepted-pass** is what the team agreed shipped to spec.

---

## The Phantom-Done Finding

In the 2026-04-28 sprint, **7 beads issues were closed and 0 of them have a matching PR in `rideRTD/tis-next-gen`.**

Most of those 7 are legitimate non-code work — Azure infrastructure, Container Apps environments, dev-network access requests, Application Owner setup. The work happened. It was real. Production environments were stood up.

But the dev tooling sees none of it. CAB sees none of it. Jira holds the only record, and Jira's "Done" column has no concept of evidence — anyone can drag a card.

This is the gap the agile transformation needs to close. The headline isn't "the team is faking work" — it's:

> **RTD has no shared system of record for what changed.** Code changes live in GitHub. Infrastructure changes live in Jira and people's heads. CAB sees neither. The "every change is a new change" pattern in CAB is the symptom; the absence of a unified change ledger is the cause.

Beads-derived metrics are the first artifact in the org that surfaces this gap as a number rather than a feeling.

---

## Caveats Before Sharing Externally

1. **2026-03-31 Sonar = 0%.** Almost certainly a check-name change rather than a real regression. Spot-check one PR from that window before this number lands in front of leadership.
2. **100% approval rate with 2–3 authors and solo reviewers** reads as quality but is structurally indistinguishable from rubber-stamp. Worth a footnote when comparing to industry benchmarks.
3. **Phantom-done is a coarse signal.** It counts bd issues closed in the window with no PR in this repo for the same window. Cross-repo work, multi-sprint work, and legitimate non-code work all show up as "phantom." A categorization pass is the obvious next step.
4. **Sprint 1 (2026-03-17)** was the team's first sprint with the DoD script in the loop — the 33% auto-pass reflects the learning curve, not steady-state quality.

---

## Recommended Next Steps

1. **Investigate the 03-31 Sonar gap** before any external share.
2. **Categorize the 7 phantom-done items** in 2026-04-28 (code-but-untagged vs. legitimate non-code) → produces the "% of work invisible to dev tooling" trend, which is the contractor's case-for-change.
3. **Tighten the approval signal** — distinct reviewer count, time-to-first-review — to distinguish real review from rubber-stamp.
4. **Run `sprint-metrics.sh` every other Tuesday** post-sprint (consider scheduling) and append to a rolling trend file rather than per-sprint files. Trend lines in a single doc are far more persuasive than four separate snapshots.
5. **Hand the contractor this doc.** The numbers prove the transformation has measurable signal *and* show where the next investment lives.
