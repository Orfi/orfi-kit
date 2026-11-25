# orfi-kit-story-dod

> Definition-of-Done gate for one story — verify the work with sha-pinned evidence and write a single `gate:` stamp.

## What it does

Audits a finished (or in-progress, as a dry-run) **single story** against its Definition of Done and records the result in `<helper-files-root>\orfi-kits\stories\<STORY-KEY>\dod.md`. It verifies evidence rather than re-running everything: a result already recorded at the current `HEAD` — by a code review, a test run, a security review, or anyone else — is credited; stale or missing evidence is re-run; a bare claim is not evidence. It never fixes code, commits, pushes or touches Jira. Adapted from Trackbed's `trackbed-dod`, without the roadmap/phase machinery.

## How to invoke

```
/orfi-kit-story-dod [STORY-KEY]      # Claude Code, OpenCode, Copilot CLI
$orfi-kit-story-dod [STORY-KEY]      # Codex CLI
```

Key resolution matches `orfi-kit-story-preflight` (argument → single ticket ID in the branch name → ask).

## Prerequisites

- The helper-files root configured.
- Test/build/lint commands, resolved from: a `verification:` block in `<root>\orfi-kits\ONBOARDING.md` → the same block in the repo's `ONBOARDING.md` / `docs/ONBOARDING.md` / `CONTRIBUTING.md` → obvious repo convention → asked once (and offered to be recorded).
- Optional: `preflight.md` from `orfi-kit-story-preflight` (supplies the AC register, constraints and open items).

## The checks

| # | Check | Notes |
|---|-------|-------|
| 1 | Acceptance criteria | Every clause needs DIRECT semantic evidence; Jira ACs re-fetched once to detect changes |
| 2 | Tests | Real counts from actual output; test-effectiveness review without mutation campaigns |
| 3 | Build / lint | No errors, no new warnings |
| 4 | Preflight open items settled | Each `OI-n` resolved with evidence or accepted by the user; `skipped (n/a)` with no preflight |
| 5 | Scope and architecture | `git diff <merge-base>..HEAD` against the ACs and recorded constraints |
| 6 | Commits clean | Commit format and a secrets grep |
| 7 | Doc comments | Only when the diff touches `.cs`/`.cpp`/`.h`; no verifier available → **red**, not skipped |
| 8 | Security | Security review route per runtime; unavailable → `skipped (unavailable)`, visible |
| 9 | Project DoD skill | Exists only when `project_dod_skill` is declared |

The diff base is the `Base:` recorded in preflight, else the parent branch per the git conventions (`epic/*` or `origin/master`), asked once if ambiguous.

## Behavior / rules

- **Freshness = sha equality.** Ledger evidence counts only when its sha equals `HEAD`.
- **Evidence ledger.** `dod.md` has an append-only `## Evidence ledger`; anyone may add a row when a gate-relevant tool runs. The `## DoD` section is replaced each run.
- **Stamp.** One line under the title, overwritten each run: `gate: green | red | waived (<date>, ...)`.
- **Waivers** are human-only and recorded with date and reason.
- **Requirements vs engineering** verdicts are reported separately; the gate needs every applicable check to pass or be waived.

## Notes

- Pairs with [`orfi-kit-story-preflight`](orfi-kit-story-preflight.md), and reuses `orfi-kit-csharp-code-review`, `orfi-kit-cpp-code-review`, `orfi-kit-xml-docs` and `orfi-kit-doxygen-docs` results as evidence.
- The security route differs by runtime: `/security-review` on Claude Code/OpenCode, the security-review agent on Copilot CLI, an installed security-review skill on Codex.
