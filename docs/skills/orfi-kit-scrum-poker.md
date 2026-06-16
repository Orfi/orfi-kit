# orfi-kit-scrum-poker

> Estimate a Jira ticket on the planning-poker Fibonacci scale (1/2/3/5/8/?) and, after you confirm, write the points back to Jira.

## What it does

When you ask Claude to estimate a Jira ticket, this skill reads the ticket, pulls a handful of recently-estimated tickets from the same project to anchor against, proposes a story-point number with explicit reasoning, waits for your confirmation, and only then writes the value back to the ticket via the Atlassian MCP server. It enforces the team's estimation policy: cap at 8, bugs get no points, spikes get `?`.

## When it fires / how to invoke

Auto-triggers whenever you ask to estimate, story-point, size, or assign points to a Jira ticket — any request that pairs a Jira issue key with estimation. It also fires when you reference planning poker, Fibonacci sizing, or sprint estimation tied to Jira. Examples that trigger it:

- `estimate ORFI-61104`
- `add story points to ORFI-61201`
- `size this story: ORFI-61310`
- `how many points is ORFI-61415`
- `run planning poker on ORFI-61520`

## Prerequisites

- The Atlassian MCP server, configured with access to your Jira instance. The skill calls `mcp__atlassian__jira_get_issue`, `mcp__atlassian__jira_search_issues`, `mcp__atlassian__jira_search_fields`, `mcp__atlassian__jira_update_issue`, and `mcp__atlassian__jira_add_comment`.

No manual config of the Story Points field is needed — the skill auto-discovers the custom field ID on first use.

## The story point scale

Fibonacci, capped at 8. The T-shirt sizes are only mental anchors — only the **number** (or `?` for a spike) ever gets written to Jira, never the letter.

| Points | Size | Meaning |
|--------|------|---------|
| **1** | XS | One-liner or trivial fix |
| **2** | S | Small, well-understood change |
| **3** | M | Medium; some moving parts but no unknowns |
| **5** | L | Large; multiple components or moderate unknowns |
| **8** | XL | Very large but still fits in a sprint |
| **?** | Spike | Unknown; needs investigation before it can be sized |

## Behavior / rules

The skill runs a fixed workflow: read the ticket → classify → gather calibration data → propose an estimate with reasoning → confirm with you → write to Jira.

**Read first.** It calls `jira_get_issue` and reads the summary, description, acceptance criteria, issue type, labels, components, and any existing story-point value. If the ticket is already pointed, it tells you and asks whether to re-estimate or keep the value.

**Classify before estimating.** Three checks happen up front:

- **Never assign more than 8.** If the honest estimate is 13+, the skill refuses, writes nothing to Jira, explains which dimensions make it big (scope, unknowns, components touched), and suggests one or two concrete ways to split it (e.g. backend API from frontend integration, happy path from edge cases, or carving out the unknown as a spike first). You break it down and come back with the sub-tickets.
- **Bugs do not get story points.** If the issue type is `Bug`, the skill skips estimation, explains that bug effort is unpredictable and would distort sprint velocity, and adds a comment via `jira_add_comment` noting the ticket was reviewed for estimation and skipped per the bugs-no-points policy. It does **not** call `jira_update_issue`.
- **Spikes get `?`, not a number.** A ticket is treated as a spike if *any* of these hold: issue type is `Spike`, `Research`, or `Investigation`; the summary or labels contain "spike"; or the description is framed as "investigate X" / "research Y" with no concrete deliverable. For a confirmed spike it proposes `?`. Because Jira's Story Points field is typically numeric-only, it leaves the field blank and records the spike classification as a comment instead. If the signals are mixed (e.g. a Task with a POC deliverable), it asks you before deciding.

**Calibrate by comparison.** Planning poker works by comparison, not absolute judgment. Before proposing a number the skill pulls 3–5 recently-estimated tickets from the same project (via `jira_search_issues`, excluding bugs) and anchors against any that look structurally similar. If the project has no estimated history, it says so and tells you the estimate is uncalibrated.

**Propose with reasoning.** It weighs complexity, clarity of acceptance criteria, unknowns, likely scope, and where comparable past tickets landed — and names the closest-comparable past ticket(s) so the estimate is auditable and you have something concrete to push back on.

**Confirm before writing.** The skill never calls `jira_update_issue` without your explicit confirmation, because writing points triggers notifications and shows up in sprint reports. It accepts "yes", "ok", "confirm", "apply", "go", or a different number (in which case it uses your number). If you give a value outside the scale (e.g. 4 or 6), it rounds to the nearest valid value and re-confirms rather than silently snapping.

**Write to Jira.** Story points live in a custom field whose ID varies by instance. The skill discovers it once per session via `jira_search_fields` (looking for `Story Points` / `Story point estimate`, typically `customfield_10016`) and reuses that ID for the rest of the session. After a successful update it confirms the issue key, the value written, and the field used.

**Ask vs. decide.** It asks when a ticket could reasonably be a spike or a small story, when the issue type field is missing or unusual, when two estimates feel equally defensible and your context would tip it, or when the story-point field can't be found. Otherwise it decides — it won't ask permission to do the thing it was invoked for.

## Example

```
You: estimate ORFI-61104

[Ticket read ✓]  ORFI-61104 — "Add rate limiting to /api/export"
  Type: Story · Status: To Do · Current points: none

[Calibration]
  - ORFI-61082 (3pt): added rate limiting to /api/import
  - ORFI-60991 (5pt): full quota system across 4 endpoints

Proposed: **3 points (M)**
  - Mirrors ORFI-61082 almost exactly (same pattern, different endpoint)
  - AC is concrete (3 criteria)
  - One unknown: whether the existing rate-limit middleware covers export's payload shape

Confirm to apply?

You: yes

[Write ✓]  Set Story Points = 3 on ORFI-61104 (customfield_10016)
```

## Notes

- Estimation writes are gated behind explicit confirmation by design — this aligns with the kit's `orfi-guardrails` safe-version-control posture (no surprise mutations).
- The skill only touches Jira through the Atlassian MCP server; it shares that dependency with other Jira-aware orfi-kit capabilities.
