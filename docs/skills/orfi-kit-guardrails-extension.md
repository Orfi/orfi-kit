# orfi-kit-guardrails-extension
> Injects orfi-kit's guardrails, a brevity nudge, and the repo's own C#/C++ coding conventions into every Copilot CLI session as always-active context.

## What it does
This is a Copilot CLI session extension that loads three things into the model's context. It runs passively — you don't invoke it:

1. **The guardrails** — a fixed block of behavioral constraints (honesty, test verification, read-before-edit, scope discipline, safe version control, and more), injected at session start.
2. **A brevity nudge** — measures the previous assistant reply on each new prompt and injects a correction when it ran long.
3. **Language conventions** — the C# and/or C++ convention rules, so code is written against the repo's own config rather than fixed up at review time. The workspace is scanned to decide which block applies, so a C#-only repo doesn't carry C++ rules it will never use.

## When it fires / how to invoke
It fires automatically. The extension joins the active session and registers two hooks — the only two the Copilot SDK exposes:

- **`onSessionStart`** — logs `"Orfi guardrails active"` and returns the guardrails plus any applicable convention blocks as `additionalContext`.
- **`onUserPromptSubmitted`** — runs the brevity check against the previous reply.

There is no command to run and nothing to trigger.

## Prerequisites
- The `@github/copilot-sdk/extension` package (the extension imports `joinSession` from it).
- A Copilot CLI session for the extension to join.

## Behavior / rules
The extension registers no tools (`tools: []`); it only adds context.

### Guardrails (always injected)

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

- BREVITY: Keep replies under ~25 lines by default; expand only when the user asks for depth.

### Brevity nudge

On each new prompt the extension measures the previous assistant reply and, if it exceeded 25 lines, injects a correction. Phrases that request depth ("in full", "in detail", "elaborate", …) suppress it for that turn.

**This is a nudge, not a gate.** The SDK has no post-response event, so the over-long reply has already been sent by the time it is measured. With the kit's **native Copilot hooks** installed (`~/.copilot/hooks/orfi-kit.json` registers `orfi-kit-enforce-brevity.sh` as a `Stop` hook), the reply is blocked instead and must be rewritten; the nudge is the fallback for sessions without native hooks.

### Language conventions

Injected at session start, scoped to the languages actually present in the workspace:

- **C#** — read the nearest `.editorconfig` (nearest-file-wins to `root = true`); read `dotnet_naming_rule` / `_symbols` / `_style` as complete triplets; read `applicable_kinds` literally, because `field` **covers `const` and `static readonly`**; read `Directory.Build.props` for `TreatWarningsAsErrors`, `EnforceCodeStyleInBuild`, and `Nullable`.
- **C++** — read the nearest `.clang-format` and `.clang-tidy`; know that `clang-tidy` is largely inert without `compile_commands.json`; treat "no config at all" as the normal C++ case; respect an encoded `cppcoreguidelines-owning-memory` policy; never propose bulk filename renames.

Detection is a bounded, read-only walk of the workspace (depth 3, common build and vendor dirs skipped). If it fails or finds nothing, **no** convention block is injected — guessing the wrong language would assert conventions the repo never agreed to.

**The repo under review always wins.** These blocks tell the model to go read the repo's own config; they do not restate a baseline, because a hardcoded rule here would outrank the repo's own.

## Notes

This is the Copilot CLI counterpart to the `orfi-kit-guardrails` skill on the Claude Code side, and it
works **together with** the Copilot native hooks ([orfi-kit-copilot-hooks](orfi-kit-copilot-hooks.md)):
the extension loads context, the native hooks gate and verify.

| | Copilot extension (this) | Copilot native hooks | Claude Code |
| --- | --- | --- | --- |
| Guardrails context | Yes, at session start | — | `orfi-kit-guardrails` skill |
| Brevity | Nudge, one turn late | **Gate** — `Stop` hook | **Gate** — `Stop` hook |
| Load conventions before a write | Yes, at session start | — (served by the extension) | Yes — 2 `PreToolUse` loaders |
| Verify a file after a write | No — SDK has no per-edit event | Yes — 2 `PostToolUse` verifiers | Yes — 2 `PostToolUse` verifiers |
| Skill-contract gate | No | Yes — `Stop` hook | Yes — `Stop` hook |

OpenCode is the remaining partial platform: no Stop event, so brevity and skill-contract are not
ported there (see [orfi-kit-opencode-plugin](orfi-kit-opencode-plugin.md)).

Do not "fix" this extension's missing verifier by faking one here: a check that runs a turn late,
against a file that may have changed again, is worse than an honest gap — the native hooks are how
Copilot truly gates.

**Duplicated rule text is deliberate.** The brevity depth-request list and the convention rule text each exist twice — once here, once in the Claude hooks — because the two run on different platforms and cannot share code. They have drifted before (this extension was once missing "elaborate" and "show more"). **Change them together.**
