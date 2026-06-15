# orfi-kit-scrum-poker

A Copilot skill that estimates Jira tickets using planning-poker story points via Atlassian tools. When you ask Copilot to estimate an ORFI ticket, the skill reads the ticket, pulls recent estimated tickets for calibration, proposes a number with reasoning, waits for your confirmation, and writes the value back to Jira.

## Install

1. Copy the `orfi-kit-scrum-poker/` folder into your Copilot skills directory:
   - **Mac/Linux:** `~/.claude/skills/`
   - **Windows:** `C:\Users\<you>\.claude\skills\`
2. Restart your Copilot session after installing in your local skill path.

## Prerequisite

You need Atlassian tools configured with access to the Orfi Jira instance. The skill calls:

- `atlassian-jira_get_issue`
- `atlassian-jira_search_issues`
- `atlassian-jira_search_fields`
- `atlassian-jira_update_issue`
- `atlassian-jira_add_comment`

On first use, the skill auto-discovers your `Story Points` custom field ID via `atlassian-jira_search_fields` — no manual config needed.

## How to use

Just ask Copilot, naturally. Any of these will trigger the skill:

- `estimate ORFI-61104`
- `add story points to ORFI-61201`
- `size this story: ORFI-61310`
- `how many points is ORFI-61415`
- `run planning poker on ORFI-61520`

The skill will read the ticket, propose an estimate with reasoning, and ask you to confirm before writing to Jira.

## The story point scale

We use Fibonacci, capped at 8. T-shirt sizes are only mental anchors — **only the number (or `?`) gets written to Jira**.

| Points | Size | Meaning |
|--------|------|---------|
| **1** | XS | One-liner or trivial fix |
| **2** | S | Small, well-understood change |
| **3** | M | Medium; some moving parts but no unknowns |
| **5** | L | Large; multiple components or moderate unknowns |
| **8** | XL | Very large but still fits in a sprint |
| **?** | Spike | Unknown; needs investigation before it can be sized |

## Rules the skill enforces

### Never assign more than 8

If the skill thinks a ticket is 13+, it **refuses to estimate** and instead:
- Tells you why the ticket feels too big (scope, unknowns, components touched)
- Suggests 1–2 concrete ways to split it
- Does **not** write anything to Jira

You break it down into smaller stories and come back to estimate each one.

### Bugs do not get story points

If the ticket's issue type is `Bug`, the skill:
- Skips estimation (refuses to assign points)
- Explains that bug effort is unpredictable and would distort sprint velocity
- Adds a comment to the ticket via `atlassian-jira_add_comment` noting it was reviewed for estimation and skipped per the bugs-no-points policy
- Does **not** write to the Story Points field

### Spikes get `?`, not a number

A spike is research — the output is knowledge, not shippable work. The skill treats a ticket as a spike if *any* of the following are true:
- Issue type is `Spike`, `Research`, or `Investigation`
- Summary or labels contain "spike"
- Description is framed as "investigate X" / "research Y" with no concrete deliverable

If signals are mixed (e.g. a Task with a POC deliverable), the skill **asks you** before deciding.

For a confirmed spike:
- Proposes `?` as the estimate
- Because Jira's Story Points field is numeric-only, the skill leaves the field blank
- Records the spike classification as an `atlassian-jira_add_comment` so the context lives on the ticket

## Example session

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
