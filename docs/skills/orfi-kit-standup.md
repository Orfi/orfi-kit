# orfi-kit-standup
> Build a status/standup report through guided questions, then format it for Teams.

## What it does
Walks you through building a status report one section at a time — **In progress**, **Done**, **Next**, **Blockers** — then assembles it into the team's standard Teams-ready format and iterates on the wording until you confirm. You are the source of the content; the command asks, clarifies, looks up Jira ticket titles when you name a ticket, and formats. It does not invent work or pull activity from git.

## How to invoke
Run the slash command:

```
/orfi-kit-standup
```

## Prerequisites
- The Atlassian MCP server, *only if* you want ticket titles fetched automatically. If it's unavailable, the command asks you for the title instead.

## Behavior / rules
- Goes section by section in order: 🟢 In progress → ✅ Done → 🔵 Next → ❌ Blockers.
- For any Jira ticket ID you mention, it fetches the title via `mcp__atlassian__jira_get_issue` so you don't retype it; on failure it asks you for the title rather than guessing.
- Long Jira summaries are shortened into crisp, readable titles for the report (meaning preserved); if shortening is a judgement call, it shows you the shortened version to approve.
- **In progress** items carry `Remaining:` and `ETA:` lines; Done/Next items don't.
- Items without a ticket (e.g. an ADR amendment) are just described — no ID required.
- Only sections/bullets you provide content for are included.
- Shows you a draft and iterates until you explicitly confirm, then prints the final report as one clean block to paste into Teams.

## Output format

```
🟢 In progress:
  - ORFI-61405 (API Key Scope Model) — widening scopes to string[], adding fingerprint. Code complete; verified end-to-end.
    Remaining: DoD + PR feature→epic.
    ETA: today.

✅ Done:
  - ORFI-61394 (Golden-File Verification Harness) — ported comparators, ran goldens. Merged (PR #499 → epic).

🔵 Next:
  - ORFI-61594 (IdMappingCacheService Redis+S3 Compliance) — drop the tier-3 Postgres fallback, S3-backed rehydration on Redis miss.

❌ Blockers: none.
```

## Notes
- The command only decides formatting (emoji, bullet shape, tightening wording for readability). All content — items, statuses, ETAs, blockers — comes from you.
