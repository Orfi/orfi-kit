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

## Autonomous enforcement

Do not wait to be asked. Do not wait for the hook. Apply these rules the moment any `.cs` file is opened for writing:

1. **Write the `///` comment before the member declaration** — never after.
2. **After writing**, run `pwsh scripts/check-xml-docs.ps1 -Changed` and fix every violation before proceeding.
3. **Block yourself** from marking a task complete if any violation remains.

---

## When writing C# code — required tag set

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

| Member | Required tags |
|---|---|
| Method / async method | `<summary>` + `<param>` per parameter + `<returns>` (non-void) + `<exception>` (if throws) |
| Property | `<summary>` |
| Class / interface / record / struct | `<summary>` |
| Enum | `<summary>` on enum + `<summary>` on every member |
| Constructor (public/protected) | `<summary>` + `<param>` per parameter |
| Event | `<summary>` |
| Static method/property | Same as non-static equivalent |

**Never** add `#pragma warning disable CS1591`. Fix the missing comment.

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

## When reviewing C# output (orchestrator role)

1. Scan every modified `.cs` file for members missing `///` — immediately, before committing.
2. If violations exist: stop, report them, demand fixes. Do not proceed.
3. Only commit when the check script exits `0`.

---

## Exclusions — never flag these

- `private` members
- Auto-generated files: `*.g.cs`, `*.designer.cs`, `*.generated.cs`
- Migration files: `*/Migrations/*.cs`
- Test files — test method names are self-documenting

---

## Quick-reference patterns

```csharp
// Interface
/// <summary>Provides read access to customer record mappings stored in Redis.</summary>
public interface ICustomerRecordRepository { }

// Property
/// <summary>Gets the tenant-specific Redis key prefix for this mapping.</summary>
public string KeyPrefix { get; }

// Enum
/// <summary>Identifies the type of a document.</summary>
public enum DocumentType
{
    /// <summary>A procedure document with ordered steps.</summary>
    Procedure,
    /// <summary>An article document with free-form content.</summary>
    Article
}

// Static method
/// <summary>Builds the primary Redis key for a customer record mapping.</summary>
/// <param name="tenantId">The tenant slug.</param>
/// <param name="recordId">The legacy record ID.</param>
/// <returns>The formatted Redis key string.</returns>
public static string BuildKey(string tenantId, string recordId) => ...;

// Constructor
/// <summary>Initialises a new instance with the required Redis connection.</summary>
/// <param name="redis">The Redis connection multiplexer.</param>
public CustomerRecordRepository(IConnectionMultiplexer redis) { }
```

---

## Pre-commit hook (repo tooling)

The repo ships `.githooks/pre-commit` — runs the check script on staged `.cs` files automatically on every `git commit`. Blocks the commit if violations are found, like a VSTS check-in policy.

**One-time setup per clone:**
```powershell
pwsh scripts/setup-hooks.ps1
```

This runs `git config core.hooksPath .githooks`. After setup, the hook fires automatically.

**Bypass (exceptional cases only):**
```bash
git commit --no-verify
```

**CI integration (future):** The check script exits `0`/`1` and is CI-ready. Wiring it to GitHub Actions is tracked separately.

---

## References

- [C# XML documentation comments — Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/xmldoc/)
- [GenerateDocumentationFile — MSBuild property](https://learn.microsoft.com/en-us/dotnet/core/project-sdk/msbuild-props#generatedocumentationfile)
- [CS1591 warning](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/compiler-messages/cs1591)
- [DocFX v2 — documentation generation](https://dotnet.github.io/docfx/)
