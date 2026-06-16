# orfi-kit-xml-docs

> Always-on enforcement of `///` XML documentation comments on every public, protected, and static C# member.

## What it does

This skill enforces formal `///` XML documentation on all C# public and protected members. It is always active: it applies automatically the moment any `.cs` file is opened for writing, without you invoking it and without relying on the pre-commit hook. A C# task is not considered done until every changed public and protected member carries a `///` block. C# only — TypeScript, Python, and C++ are covered by separate skills.

## When it fires / how to invoke

Always active. It auto-applies whenever a `.cs` file is written or edited. You can also nudge it explicitly with trigger phrases such as "xml docs", "add xml docs", "document members", "check xml docs", or "enforce docs".

## Prerequisites

- A C# project (the skill is C#-only).
- PowerShell (`pwsh`) to run `scripts/check-xml-docs.ps1`.
- For the pre-commit hook: a one-time `pwsh scripts/setup-hooks.ps1` per clone (sets `git config core.hooksPath .githooks`).

## Behavior / rules

Documentation requirement by visibility:

| Visibility | Document? |
|---|---|
| `public` | Always |
| `protected` | Always |
| `static` (on a public/protected type) | Always |
| `internal` | Optional |
| `private` | Never |

Autonomous enforcement steps applied to any `.cs` file opened for writing:

1. Write the `///` comment **before** the member declaration, never after.
2. After writing, run `pwsh scripts/check-xml-docs.ps1 -Changed` and fix every violation before proceeding.
3. Block task completion if any violation remains.

Required tag set per member type:

| Member | Required tags |
|---|---|
| Method / async method | `<summary>` + `<param>` per parameter + `<returns>` (non-void) + `<exception>` (if it throws) |
| Property | `<summary>` |
| Class / interface / record / struct | `<summary>` |
| Enum | `<summary>` on the enum + `<summary>` on every member |
| Constructor (public/protected) | `<summary>` + `<param>` per parameter |
| Event | `<summary>` |
| Static method/property | Same as the non-static equivalent |

Never add `#pragma warning disable CS1591` — fix the missing comment instead.

Style rules — write formal API reference documentation, not narrative:

- Third-person, present-tense, declarative. Method summaries begin with a verb ("Resolves…", "Validates…", "Gets…", "Initialises a new instance of…").
- No first or second person ("I", "we", "you", "let's", "our").
- Never include narrative/conversational phrasing, personal commentary or hedging ("I think", "probably", "for now", "a bit hacky"), work-history/changelog notes ("added in this PR", "as discussed"), planning/phase/story/ticket-process terminology, or jokes/emoji/filler. An issue key is acceptable only if a reference is genuinely needed.

Exclusions — never flag these:

- `private` members
- Auto-generated files: `*.g.cs`, `*.designer.cs`, `*.generated.cs`
- Migration files: `*/Migrations/*.cs`
- Test files (test method names are self-documenting)

Orchestrator / review role: scan every modified `.cs` file for members missing `///` before committing; if violations exist, stop, report, and demand fixes; only commit when the check script exits `0`.

## Example

```csharp
/// <summary>
/// Resolves a legacy record ID to its Redis-backed mapping for the given tenant.
/// </summary>
/// <param name="tenantId">The tenant slug (e.g., <c>acme</c>).</param>
/// <param name="recordId">The legacy record ID.</param>
/// <returns>
/// The <see cref="CustomerRecord"/> if found; <c>null</c> if no mapping exists.
/// </returns>
/// <exception cref="RedisConnectionException">Thrown when the Redis connection is unavailable.</exception>
public async Task<CustomerRecord?> FindAsync(string tenantId, string recordId);
```

## Notes

- The repo ships `.githooks/pre-commit`, which runs the check script on staged `.cs` files on every `git commit` and blocks the commit if violations are found. Run `pwsh scripts/setup-hooks.ps1` once per clone to wire it up; bypass with `git commit --no-verify` in exceptional cases only.
- The check script exits `0`/`1` and is CI-ready; wiring it to GitHub Actions is tracked separately.
- See [Microsoft's C# XML documentation comments docs](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/xmldoc/) and the [CS1591 warning reference](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/compiler-messages/cs1591).
