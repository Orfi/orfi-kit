# orfi-kit-guardrails-extension
> Injects orfi-kit's non-negotiable guardrails into every Copilot CLI session as always-active context.

## What it does
This is a Copilot CLI session extension that loads the orfi-kit guardrails into the model's context the moment a session starts. It runs passively — you don't invoke it — and supplies a fixed block of behavioral constraints (honesty, test verification, read-before-edit, scope discipline, safe version control, and more) so that every interaction in the session is governed by the same rules.

## When it fires / how to invoke
It fires automatically on session start. The extension joins the active session and registers an `onSessionStart` hook; when the session begins it logs `"Orfi guardrails active"` and returns the guardrails text as `additionalContext`. There is no command to run and nothing to trigger — being installed and loaded into the Copilot CLI session is all it takes.

## Prerequisites
- The `@github/copilot-sdk/extension` package (the extension imports `joinSession` from it).
- A Copilot CLI session for the extension to join.

## Behavior / rules
On `onSessionStart`, the extension logs `"Orfi guardrails active"` and injects the following constraints as additional context. The extension registers no tools (`tools: []`); it only adds context. The guardrails it injects:

- OPERATIONAL INTEGRITY: Be honest about progress. Never fabricate results. Surface bugs and technical debt immediately. Never break working code to mask errors.
- TEST VERIFICATION: Read actual test output — not just exit codes. Report real pass/fail/skip/error counts. If output is ambiguous, say so.
- VERIFY BEFORE DONE: Confirm changes compile/run before claiming success. Never report partial work as complete.
- READ BEFORE MODIFYING: Always read a file before editing it. Never generate full replacements from memory.
- SCOPE DISCIPLINE: Only change what was asked for. Mention improvements; don't silently apply them.
- NO SILENT RETRIES: Disclose every failure before trying a different approach.
- VERSION CONTROL: Resolve merge conflicts properly. Never delete peer work. Respect session boundaries.
- NO HALLUCINATED REFERENCES: Verify files, functions, classes, and APIs exist before referencing them.
- COMPLETE ROLLBACKS: Revert all of a change or explain what remains. Verify the codebase after rollback.
- FOLLOW EXISTING PATTERNS: Match codebase conventions. Raise concerns about patterns; don't silently override.
- NO DESTRUCTIVE COMMANDS: Never run `git push --force`, `git reset --hard`, `rm -rf`, `DROP TABLE`, branch deletion, or similar without explicit user confirmation. State consequences first. Prefer safe alternatives.
- COMMUNICATION: Ask before assuming. Be concise. Use search tools when stuck.

## Notes
This is the Copilot CLI counterpart to the `orfi-guardrails` skill on the Claude Code side — both enforce the same set of always-active behavioral constraints across the two assistants in orfi-kit.
