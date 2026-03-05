Subject: TIS Next Gen — automated DoD enforcement in sprint reviews

Hi [Deputy CITO name],

I know you're driving agile adoption across the org and I'm happy you're pushing this. I wanted to share something we're rolling out on the TIS Next Gen team that might be useful as a pattern for other teams.

Our team is new to agile, so rather than relying on manual process compliance I've set up automated Definition of Done verification for our sprint reviews. It works like this:

**DoD checks (automated):**
1. Code in a PR and reviewed by at least one team member
2. Tests passing in CI
3. PR merged to main
4. SonarCloud analysis clean

**How it works:**
- I built a script that pulls PR data from GitHub — reviews, CI results, SonarCloud status — and checks every merged PR against the DoD automatically.
- This runs at the end of each sprint. The team demos their work first, then I run the report and we accept or reject together.
- It syncs with Jira through an open source tool called Beads, so our PM's board stays up to date.

**Why this matters for a new agile team:**
- The DoD gets enforced consistently from day one — no relying on tribal knowledge
- Sprint reviews have objective evidence, not just verbal walkthroughs
- It builds the right habits early while the team is still learning the process

I'm sending the full process to the team this week. Wanted to give you a heads up and see if you have any input before it goes out. If this works well for TIS, it could be a template for other teams adopting agile.

Happy to walk you through it anytime.

James
