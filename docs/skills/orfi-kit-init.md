# orfi-kit-init

> Bootstrap the per-repo helper-files root and create placeholder session-state + onboarding files (only if they do not already exist).

## What it does

Prepares a repo to use orfi-kit's session-continuity commands. It ensures the helper-files root is configured, then creates placeholder files under `<helper-files-root>\orfi-kits\` — **only if they are absent**. It never overwrites existing files; if the repo is already initialized it reports that and quits. To *change* an existing root path, use `/orfi-kit-set-helper-files-root` instead.

## How to invoke

```
/orfi-kit-init
```

## Prerequisites

- None. If the helper-files root isn't configured yet, init runs the config routine on the spot (prompting for the path).

## Behavior / rules

1. Resolve/define the helper-files root (configuring it if missing). `<kit-root>` = `<helper-files-root>\orfi-kits`.
2. If `<kit-root>` already contains the session-state file and `ONBOARDING.md`, report "already initialized" and stop.
3. Otherwise create only the missing placeholders: the session-state file (this Claude command owns `CLAUDE-SESSION-STATE.md`; the Copilot skill owns `COPILOT-SESSION-STATE.md`) and `ONBOARDING.md`, each with guiding comment headers.
4. Confirm the resolved `<kit-root>` and which files were created.

## Notes

- Pairs with `/orfi-kit-set-helper-files-root` (sets/changes the path) and `/orfi-kit-load-state` / `/orfi-kit-persist-state` (read/write the state file init creates).
- orfi-ae-kit ships a superset `/orfi-ae-kit-init` that additionally writes the Architect/Executor orientation files.
