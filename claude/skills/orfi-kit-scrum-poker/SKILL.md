---
name: orfi-kit-scrum-poker
description: Estimate a Jira ticket using planning-poker story points (Fibonacci scale 1/2/3/5/8/?) via the Atlassian MCP server. Use this skill whenever the user asks to estimate, story-point, size, or assign points to a Jira ticket — phrases like "estimate ORFI-123", "how many points is this", "add story points to this ticket", "size this story", or any request that pairs a Jira issue key with estimation. Also triggers when the user references planning poker, Fibonacci sizing, or sprint estimation tied to Jira.
---

# Jira Story Point Estimation

Estimate a Jira ticket on the team's planning-poker scale and, after confirmation, write the estimate back to the ticket via the Atlassian MCP server.

## The Scale

The only valid story-point values are:

| Points | Size | Meaning |
|--------|------|---------|
| 1 | XS | One-liner or trivial fix |
| 2 | S | Small, well-understood change |
| 3 | M | Medium; some moving parts but no unknowns |
| 5 | L | Large; multiple components or moderate unknowns |
| 8 | XL | Very large but still fits in a sprint |
| ? | Spike | Unknown; needs investigation before it can be sized |

**Never assign anything higher than 8.** If the ticket looks like 13+, refuse and ask the user to break it down — see *When the ticket is too big*.

The sizes (XS/S/M/L/XL) are only mental anchors. What gets written to Jira is the **number** (or `?` for a spike) — never the letter.

## Workflow

```
1. Read the ticket  ──► 2. Classify (bug? spike? too big?)
                                   │
                                   ▼
3. Gather calibration data  ──► 4. Propose estimate + reasoning
                                   │
                                   ▼
5. Confirm with user  ──► 6. Write to Jira
```

### 1. Read the ticket

Call `mcp__atlassian__jira_get_issue` with the issue key the user gave you. Read the summary, description, acceptance criteria, issue type, labels, components, and current story-point value (if any).

If the ticket already has story points, mention it and ask whether the user wants to re-estimate or keep the existing value.

### 2. Classify early

Check three things before estimating:

**Is it a bug?** If `issuetype.name == "Bug"`, stop. Bugs don't get story points on this team — bug effort is unpredictable and lumping it with feature velocity distorts sprint planning. Explain this to the user, then add a comment to the ticket via `mcp__atlassian__jira_add_comment` noting that the ticket was reviewed for estimation and skipped per the bugs-no-points policy. Do not call `jira_update_issue`.

**Is it a spike?** A spike is research, not delivery — the output is knowledge, not shippable work. Treat it as a spike if *any* of the following are true:
- Issue type is `Spike` (or `Research`, `Investigation`)
- The summary or labels contain "spike"
- The description is explicitly framed as "investigate X" / "figure out whether Y" / "research Z" with no concrete deliverable

If it's ambiguous — e.g., the ticket has unknowns but also names a concrete deliverable — **ask the user** before defaulting. A misclassified spike skews velocity just as badly as a misclassified story.

For a confirmed spike, propose `?` as the estimate.

**Is it too big?** If on reading the ticket you immediately think "this is 13+" — multiple epics of work, touches everything, weeks of effort — skip directly to *When the ticket is too big*.

### 3. Gather calibration data

Planning poker works by comparison, not by absolute judgment. Before proposing a number, pull 3–5 recently-estimated tickets from the same project to anchor against:

```
mcp__atlassian__jira_search_issues
  jql: project = <PROJ> AND "Story Points" is not EMPTY AND issuetype != Bug ORDER BY updated DESC
  limit: 10
```

Skim them. If any look structurally similar to the ticket you're estimating — same component, similar scope, similar acceptance criteria count — note their points. Your estimate should land in the same neighborhood.

If the project has no estimated history, say so and proceed on absolute judgment, but tell the user the estimate is uncalibrated.

### 4. Propose an estimate with reasoning

Weigh these signals:

- **Complexity**: how many moving parts, how interconnected, how much branching logic
- **Clarity**: is the acceptance criteria concrete, or is the ticket waving at the problem
- **Unknowns**: new tech, unfamiliar subsystem, external dependency, undefined contract
- **Scope**: how many files/components/services likely touched
- **Similar past tickets**: where did comparable work land on the scale

Present your proposed estimate like this:

```
Proposed: **3 points (M)**

Reasoning:
- Touches auth middleware + one new endpoint — moderate surface area
- AC is concrete (3 numbered criteria, all testable)
- No new tech; pattern matches ORFI-60912 (also 3pt) and ORFI-60845 (2pt)
- Minor unknown: whether the token refresh path needs to change (⇒ rounded up from 2)

Confirm to apply, or push back with a different number.
```

Always name the closest-comparable past ticket(s) if you found any — it makes the estimate auditable and gives the user something concrete to disagree with.

### 5. Confirm before writing

**Never call `jira_update_issue` without an explicit confirmation from the user.** Writing story points is reversible in Jira but noisy — it triggers notifications and shows up in sprint reports. Ask, then act.

Accept any of: "yes", "ok", "confirm", "apply", "go", or a different number (in which case use the user's number, not yours).

If the user gives a number outside the scale (e.g., "4" or "6"), round to the nearest valid value and re-confirm — don't silently snap.

### 6. Write to Jira

Story points live in a custom field whose ID varies by Jira instance. Discover it the first time in a session via:

```
mcp__atlassian__jira_search_fields  query: "story points"
```

Look for the field named `Story Points` or `Story point estimate` and grab its `id` (typically `customfield_10016` or similar). Reuse this field ID for the rest of the session — don't re-discover it for every ticket.

Then write:

```
mcp__atlassian__jira_update_issue
  issue_key: <KEY>
  fields: { "<customfield_id>": <number> }
```

For spikes, write the string `?` if the field accepts it; many Jira instances only accept numeric values in the story-point field, in which case leave the field blank and instead add a comment explaining that this was scoped as a spike. Check the field type before writing.

After a successful update, confirm back to the user with the issue key, the value written, and the field used.

## When the ticket is too big

If your honest estimate is 13 or higher, **refuse the estimate** and report the situation. Do not write any number to Jira.

Tell the user:
- The ticket is too large for the scale (cap is 8)
- A short summary of *why* it feels 13+ (which dimensions make it big: scope, unknowns, multiple components, etc.)
- One or two concrete splitting suggestions, e.g.:
  - "Split the backend API work from the frontend integration"
  - "Split the happy path from the edge cases / error handling"
  - "Carve out the unknown piece as a spike first, then re-estimate the remainder"

Do not update the ticket. The user's job is to break it down and come back with the new sub-tickets.

## When to ask vs. decide

- **Ask** when: the ticket could reasonably be either a spike or a small story; the issue type field is missing or unusual; multiple estimates feel equally defensible (e.g., between 3 and 5) and the user's context would tip it; the story-point custom field can't be found.
- **Decide** when: the ticket is clearly in one size bucket and you have calibration evidence. Don't ask for permission to do the thing the skill was invoked to do.

## Output Recap (what the user sees)

A well-run estimation looks like:

```
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

[user] yes

[Write ✓]  Set Story Points = 3 on ORFI-61104 (customfield_10016)
```

Match this shape. Keep it scannable.
