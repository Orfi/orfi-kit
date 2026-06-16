# orfi-kit-code-review
> Run an in-depth, file-by-file code review of the entire codebase, optionally scoped to bugs, security, or performance.

## What it does
Explores your codebase file-by-file to find potential issues and improvements, then produces a detailed report of its findings. By default it performs a thorough, general review; you can narrow the focus by passing a mode.

## How to invoke
Run the slash command:

```
/orfi-kit-code-review
```

You can pass an optional mode as the argument (see Behavior / rules).

## Prerequisites
None.

## Behavior / rules
- The command takes an optional `MODE` argument that scopes the review:
  - `BUGS` — focus ONLY on logical or other bugs.
  - `SECURITY` — focus ONLY on security issues.
  - `PERFORMANCE` — focus ONLY on performance issues.
- You can combine modes with commas (e.g. `BUGS,SECURITY`) to run the combined review.
- If `MODE` is anything else, or omitted, it performs a thorough, general code review.
- The review covers the entire codebase, explored file-by-file. It is meant to be deliberate, not rushed, so the structure and architecture are fully understood before findings are made.
- The output is a detailed report of all findings.
- The command runs read-only (its only allowed tool is `Read`), so it inspects but does not modify your code.

## Example
Scope the review to bugs and security only:

```
/orfi-kit-code-review BUGS,SECURITY
```

## Notes
- For a review focused on changes rather than the whole codebase, see the related `orfi-code-review` skill.
