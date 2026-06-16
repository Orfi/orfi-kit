# orfi-kit-commit

> Commit your current changes using orfi-kit's git conventions.

## What it does

Commits whatever changes are currently staged/present in your working tree, formatting the commit message according to the `orfi-kit-git-conventions` skill. You don't have to remember the message format — the command delegates to that skill so the resulting commit follows the kit's required `{type}({ticket-id}): {VERB}: description` shape.

## When it fires / how to invoke

Run the slash command:

```
/orfi-kit-commit
```

## Prerequisites

- A ticket ID, if one applies. The conventions ask for it when committing; if you don't already know it, you'll be prompted. If there is no ticket ID, it is simply omitted from the message.

## Behavior / rules

The command applies the commit-message rules from `orfi-kit-git-conventions`:

- **Format:** `{type}({ticket-id}): {VERB}: description`
- **Without a ticket:** `{type}: {VERB}: description`
- **Verb** is one of: `ADDED`, `CHANGED`, `IMPROVED`, `FIXED`, `REMOVED`, `REFACTORED`, `UPDATED`, `DEPRECATED`, `MOVED` — chosen to match what the change actually did.
- If a ticket ID is available, every commit must reference it — no exceptions.

## Example

```
feat(ORFI-123): ADDED: user role management
fix: FIXED: login timeout issue
```

## Notes

- Backed by the `orfi-kit-git-conventions` skill, which also governs branch names, PR titles, and the epic/story branching strategy. See that skill for the full convention set.
