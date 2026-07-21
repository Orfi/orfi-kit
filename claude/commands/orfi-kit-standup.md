---
name: orfi-kit-standup
description: Build a status/standup report through guided questions, then format it for Teams.
---

# Standup / Status Report Builder

Walk the user through building a status report — one section at a time — then assemble it
into the standard format below and iterate on the wording until the user confirms.

You are the scribe, not the source. The user supplies the content; you ask, clarify,
look up Jira titles when given a ticket, and format. Do not invent work, statuses, or
tickets. Do not pull activity from git or anywhere else unless the user tells you to.

## The format

Produce exactly this structure. Only include a bullet if the user gave you content for it.

```
🟢 In progress:
  - <TICKET-ID> (<title>) — <what's being done>.
    Remaining: <what's left>.
    ETA: <when>.

✅ Done:
  - <TICKET-ID> (<title>) — <what was done>. <merge/PR reference>.

🔵 Next:
  - <TICKET-ID> (<title>) — <what's coming>.

❌ Blockers: <blocker, or "none">.
```

Notes on the format:
- Ticket ID + parenthesized title is the lead when an item maps to a ticket. If an item
  has no ticket (e.g. an ADR amendment, a report added to a ticket), just describe it.
- `Remaining:` and `ETA:` lines belong to **In progress** items. Done/Next items don't need them.
- Keep every line sharp, concise, and readable. One idea per bullet. No filler.

## Titles

A Jira `summary` is often too long to read well in a status report (e.g.
"API Key Scope Model + Fingerprint Field, Identity domain"). Shorten it into a crisp
title for the parenthesized `(<title>)` slot:
- Keep the core noun phrase; drop trailing qualifiers, domains, and "+ X" tack-ons that
  the description already covers (e.g. → "API Key Scope Model").
- Never change the meaning or invent words the summary didn't imply.
- Preserve any distinguishing term that's the whole point of the ticket.
- If shortening a title is a judgement call, show the user your shortened version and let
  them adjust it — this is wording they'll paste, so it's theirs to approve.

## Workflow

Go section by section, in order. Ask, listen, confirm, move on.

### 1. 🟢 In progress
Ask what the user is currently working on. For each item:
- If they mention a Jira ticket ID, fetch its title via `mcp__atlassian__jira_get_issue`
  (read `summary`) so you don't have to ask them to retype it. If the MCP server isn't
  available or the fetch fails, ask the user for the title instead — don't guess.
- Shorten the fetched summary into a readable title (see *Titles*).
- Discuss the status with them: what's being done, what's remaining, and the ETA.

### 2. ✅ Done
Ask what's been completed. For each item, capture what was done and any merge/PR reference
(e.g. "Merged (PR #499 → epic)"). Fetch titles for any ticket IDs mentioned.

### 3. 🔵 Next
Ask what's coming up next. Fetch titles for any ticket IDs mentioned.

### 4. ❌ Blockers
Ask if there are any blockers. If none, write `Blockers: none.`

## Confirm before finishing

When all four sections are gathered, assemble the full report and show it to the user.
**Do not treat the first draft as final.** Ask them to confirm the wording or tell you
what to change, then re-render. Repeat until they explicitly confirm.

Once confirmed, present the final report as a single clean block they can paste straight
into Teams — no surrounding commentary.

## When to ask vs. decide
- **Ask** for all content — in-progress items, done items, next items, blockers, statuses,
  ETAs. The user is the source of truth.
- **Decide** only formatting: which emoji, bullet shape, where the Remaining/ETA lines go,
  and tightening wording for readability (without changing meaning).
