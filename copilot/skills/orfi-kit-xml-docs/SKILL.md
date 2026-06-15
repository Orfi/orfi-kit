---
name: orfi-kit-xml-docs
description: "Enforce /// XML documentation comments on C# public, protected, and static members. Trigger phrases: xml docs, xml comments, missing documentation, document members, add comments, check xml docs, enforce docs, document this, add xml docs."
---

# orfi-kit-xml-docs — C# XML Documentation Enforcement

This skill is **always active**. It enforces `///` XML documentation on all C# public and protected members — automatically, without being invoked, and without relying on the pre-commit hook.

C# only. TypeScript, Python, and C++ are covered by separate skills.

---

## The rule — absolute, no exceptions

| Visibility | Document? |
|---|---|
| `public` | ✅ Always |
| `protected` | ✅ Always |
| `static` (on public/protected type) | ✅ Always |
| `internal` | Optional |
| `private` | ❌ Never |

**A C# task is not done until every changed public and protected member has a `///` block. No exceptions.**

---

## Autonomous enforcement (orchestrator role)

Do not wait to be asked. Do not wait for the hook. Apply these rules the moment any `.cs` work is delegated or received:

1. **Before spawning a sub-agent**: inject the XML doc rule into the agent prompt — it is a hard constraint, not a suggestion.
2. **After receiving C# output**: run the check script immediately. Do not commit or proceed until it exits `0`.
3. **Block yourself** from marking a task complete if any violation remains.

---

## Orchestrator — reviewing C# output from sub-agents

1. Run `pwsh scripts/check-xml-docs.ps1 -Changed` against all modified `.cs` files immediately upon receiving output.
2. If violations exist: stop, report them to the executor, demand fixes. Do not proceed.
3. Only commit when the check script exits `0`.

---

## Check script (repo tooling)

The repo ships `scripts/check-xml-docs.ps1` — a deterministic scanner that exits `1` on violations and `0` when clean.

```powershell
# Scan staged files only (used by pre-commit hook)
pwsh scripts/check-xml-docs.ps1 -Staged

# Scan all changed files since last commit
pwsh scripts/check-xml-docs.ps1 -Changed

# Scan specific files
pwsh scripts/check-xml-docs.ps1 -Files @("src/Services/PublicApi/Domain/CustomerRecord.cs")
```

---

## Pre-commit hook

The repo ships `.githooks/pre-commit` — runs `-Staged` automatically on every `git commit`. Blocks the commit if violations are found, like a VSTS check-in policy.

**One-time setup per clone:**
```powershell
pwsh scripts/setup-hooks.ps1
```

This runs `git config core.hooksPath .githooks`. After setup, the hook fires automatically — no manual action needed.

**Bypass (exceptional cases only):**
```bash
git commit --no-verify
```

---

## Minimum tag set per member type

| Member | Required tags |
|---|---|
| Method / async method | `<summary>` + `<param>` per parameter + `<returns>` (non-void) + `<exception>` (if throws) |
| Property | `<summary>` |
| Class / interface / record / struct | `<summary>` |
| Enum | `<summary>` on enum + `<summary>` on every member |
| Constructor (public/protected) | `<summary>` + `<param>` per parameter |
| Event | `<summary>` |
| Static method/property | Same as equivalent non-static |

---

## Style — formal API documentation, never personal or narrative

XML doc comments are **reference documentation for the API surface**, read by other developers and by IntelliSense/DocFX. Write them as formal technical documentation, **not** as a personal narrative, a changelog, or a conversation.

**Voice and grammar:**
- Use the **third-person, present-tense, declarative** form describing *what the member does*. Summaries of methods conventionally begin with a verb: "Resolves…", "Validates…", "Builds…", "Gets…", "Initialises a new instance of…".
- **No first or second person.** Never "I", "we", "you", "let's", "our".
- State behaviour as fact about the code, not as a story about the work or the author's intent.

**Never include:**
- Narrative / conversational phrasing — e.g. "This method basically just grabs the key…", "Here we loop through and…", "Now we check the deny-list first".
- Personal commentary, opinions, or hedging — "I think", "probably", "hopefully", "for now", "TODO-ish", "a bit hacky".
- Work-history / changelog notes — "added in this PR", "as discussed", "per the ticket", "refactored from the old version". (Use git/issue tracker for history, not doc comments.)
- Planning / phase / story / ticket-process terminology of any kind — e.g. phase numbers, sprint names, or a story nickname. (Reference behaviour, or an issue key if a reference is genuinely needed.)
- Jokes, emoji, or filler ("the evt", "the ct", "does stuff").

**Do / Don't:**

```csharp
// ❌ Narrative / personal — WRONG
/// <summary>
/// Here we first check the deny-list (added in PROJ-123) and then, if we're good,
/// I look up the fingerprint. Basically returns null if anything's off.
/// </summary>

// ✅ Formal API documentation — RIGHT
/// <summary>
/// Validates a modern API key by checking the Redis deny-list, then resolving the
/// key fingerprint to its cached metadata. Returns <c>null</c> for any revoked,
/// expired, unknown, or unverifiable key (fail-closed).
/// </summary>
```

Keep descriptions accurate and specific to the member's contract: inputs (`<param>`), result (`<returns>`), and failure modes (`<exception>`). Meaningful, not filler — but formal, not chatty.

---

## Exclusions — never flag these

- `private` members
- Auto-generated files: `*.g.cs`, `*.designer.cs`, `*.generated.cs`
- Migration files: `*/Migrations/*.cs`
- Test files — test method names are self-documenting; XML docs are not required

---

## CI integration (future)

The check script is CI-ready by design (`exit 0` / `exit 1`). Wiring it into GitHub Actions to block PRs is tracked as a separate task.

---

## References

- [C# XML documentation comments — Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/xmldoc/)
- [GenerateDocumentationFile — MSBuild property](https://learn.microsoft.com/en-us/dotnet/core/project-sdk/msbuild-props#generatedocumentationfile)
- [CS1591 warning](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/compiler-messages/cs1591)
- [DocFX v2 — documentation generation](https://dotnet.github.io/docfx/)
