## Meeting Talking Points — Jira / ServiceNow Integration

### What to listen for first

Before presenting anything, understand what the ServiceNow devs built:
- Is it one-way or bidirectional?
- What fields sync? (status only? priority? descriptions?)
- Does it handle conflicts when both sides change the same item?
- Does it enforce any workflow rules (DoD, dependency ordering)?
- How is it triggered — manual, scheduled, real-time?

### The gap to highlight

Most basic Jira-ServiceNow integrations only sync fields. What they typically don't do:

- **No dependency tracking** — they sync individual tickets but not the relationships between them (what blocks what, what order work should happen)
- **No DoD enforcement** — they move status around but don't verify that the actual process was followed (code reviewed, tests passing, SonarCloud clean)
- **No conflict resolution** — if someone updates in Jira and someone updates in ServiceNow, who wins?
- **No agent/automation support** — no way for AI coding tools or CI pipelines to query "what's ready to work on?"

### What beads adds as the glue

Beads sits between both systems and adds the layer that a basic integration can't:

```
Jira (dev teams)
    ↕ bd jira sync (bidirectional, conflict resolution, field mapping)
  Beads (the glue layer)
    ↕ bd servicenow sync (to be built — same pattern as Jira)
ServiceNow (ITIL/support teams)
```

What beads does that a basic integration doesn't:
1. **Dependency graph** — knows what blocks what, surfaces ready work automatically
2. **DoD verification** — checks PRs against Definition of Done using CI/GitHub data
3. **Conflict resolution** — timestamp-based or configurable (prefer Jira, prefer ServiceNow, newest wins)
4. **Bidirectional field mapping** — status, priority, type, assignee, description — all configurable
5. **Sprint review automation** — generates DoD compliance reports per sprint
6. **Works with AI agents** — Claude Code, Cursor, etc. can query beads for next available work

### How to position it

Don't frame this as "your integration is bad." Frame it as:

"The basic integration handles the connection. What I'm proposing adds the intelligence layer on top — dependency tracking, DoD enforcement, and conflict resolution. The ServiceNow devs can own the ServiceNow configuration, the dev team keeps Jira, and beads makes sure everything stays in sync with the right workflow rules."

### If the CITO asks about ServiceNow support

"Beads already has a plugin system with Jira, Linear, and GitLab integrations built in. ServiceNow uses the same adapter pattern — it needs to be built, but the architecture is there. I can scope that work."

### Demo you can show if needed

Run this from the TIS project:
```
# Show Jira sync working
bd jira status

# Show sprint review automation
./scripts/sprint-review.sh 14

# Show single PR DoD check
./scripts/sprint-review.sh --pr 43
```

This shows the CITO that beads already works with Jira today and that extending to ServiceNow follows the same pattern.
