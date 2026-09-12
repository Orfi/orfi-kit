---
name: orfi-kit-code-review
description: Perform a focused or full code review.
---

MODE: $ARGUMENTS

Supported modes:
- `BUGS` -> logical/functional defects only
- `SECURITY` -> security issues only
- `PERFORMANCE` -> performance concerns only
- Combinations allowed, e.g. `BUGS,SECURITY`

If mode is missing/invalid, run a full review.

Review scope:
1. Inspect changed files first, then related call sites.
2. Prefer high-signal findings only (real bugs, security risks, data loss, correctness issues).
3. Avoid style-only comments.
4. Return findings with: severity, file path, evidence, and concrete fix suggestion.
