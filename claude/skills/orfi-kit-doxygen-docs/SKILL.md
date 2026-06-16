---
name: orfi-kit-doxygen-docs
description: "Enforce Doxygen documentation comments on C++ public, protected, and static header declarations. Trigger phrases: doxygen docs, doxygen comments, missing documentation, document this, add doxygen, @brief, check doxygen docs, enforce docs, document members."
---

# orfi-kit-doxygen-docs — C++ Doxygen Documentation Enforcement

This skill is **always active**. It enforces Doxygen documentation on all C++ public, protected, and exposed header declarations — automatically, without being invoked, and without relying on the pre-commit hook.

C++ only. C#, TypeScript, and Python are covered by separate skills.

Doxygen is the official C++ documentation generator (<https://www.doxygen.nl/>, v1.17.0). Tags use the `@tag` prefix (the `\tag` form is equivalent).

---

## The rule — absolute, no exceptions

Documentation is tied to the **API surface**, which in C++ means **declarations in header files**, keyed on *linkage*, not on file extension.

| Surface | Document? |
|---|---|
| `public:` members (in headers) | ✅ Always |
| `protected:` members (in headers) | ✅ Always |
| `static` members on exposed types (declared in headers) | ✅ Always |
| Free functions, classes/structs, enums, templates at namespace scope (in headers) | ✅ Always |
| `private:` members | ❌ Never |
| `.cpp` / `.cc` implementation files | ❌ Not the API surface (API lives in headers) |

**A C++ task is not done until every changed exposed declaration in a header has a Doxygen block. No exceptions.**

---

## Autonomous enforcement

Do not wait to be asked. Do not wait for the hook. Apply these rules the moment any `.h` / `.hpp` / `.hh` / `.hxx` file is opened for writing:

1. **Write the Doxygen comment before the declaration** — never after (except trailing `///<` on enumerators / data members).
2. **After writing**, run `pwsh scripts/check-doxygen-docs.ps1 -Changed` (or `bash scripts/check-doxygen-docs.sh --changed`) and fix every violation before proceeding.
3. **Block yourself** from marking a task complete if any violation remains.

---

## Comment style policy — follow the file, then ask

Doxygen accepts multiple comment styles (`/** */`, `///`, `/*! */`, `//!`). This skill standardizes **per file** by following what is already there, rather than imposing one style globally.

1. **Before writing**, detect the existing style — first within the current file, then in sibling files (the same directory, or the header's `.cpp` pair). **Follow it**, and **notify the user** which style was detected (e.g. "Following the `///` style already used in this header").
2. If **no existing Doxygen comments** exist to key off, **ask the user**: `/** */` or `///`? **Recommend `/** */`** — the most common C++ convention and the maintainer's stated preference.

The checker script does **not** enforce style; it accepts either a preceding `/** */` block or `///` lines as "documented". Style consistency is this skill's job.

---

## The `.cpp` anti-pattern — flag, do not silently document

The API surface lives in headers. When editing a `.cpp` / `.cc` file, do **not** silently add `@brief` to a definition there. Instead:

- **A genuinely-exposed symbol (external linkage) defined only in a `.cpp` with no header declaration** — this is a code smell. **Flag it**: tell the user the symbol should be **declared and documented in a header**, not annotated in the `.cpp`.
- **`static` class members** are *declared* in the header (document there) and merely *defined* in the `.cpp`. The header declaration carries the docs; the `.cpp` definition is never re-documented.
- **File-scope `static` / anonymous-namespace functions and globals in a `.cpp`** have **internal linkage** — implementation details, **not API**. They are **not required to carry `@brief`** (Doxygen itself defaults to `EXTRACT_STATIC = NO`, `EXTRACT_ANON_NSPACES = NO`).

---

## When writing C++ code — required tag set

```cpp
/**
 * @brief Resolves a legacy record ID to its cache-backed mapping for the given tenant.
 *
 * @param tenantId The tenant slug (e.g. @c acme).
 * @param recordId The legacy record ID.
 * @return The CustomerRecord if found; @c nullptr if no mapping exists.
 * @throws CacheConnectionException If the cache connection is unavailable.
 */
std::optional<CustomerRecord> Find(const std::string& tenantId, const std::string& recordId);
```

| Member | Required tags |
|---|---|
| Function / method | `@brief` + `@param` per parameter + `@return` (non-`void`) + `@throws` (if it throws) |
| Class / struct / interface | `@brief` |
| Enum | `@brief` on the enum + `@brief` (or a trailing `///<`) on every enumerator |
| Constructor | `@brief` + `@param` per parameter |
| Template | `@tparam` per template parameter (plus the above) |
| Static member | Same as the non-static equivalent |

**Never** suppress Doxygen warnings (e.g. `@cond`, `///@{`-hiding, or build-flag silencing) in place of writing the missing comment. Fix the missing comment.

---

## Tag mapping — for users coming from xml-docs

| C# XML doc | Doxygen |
|---|---|
| `<summary>` | `@brief` |
| `<param name>` | `@param name` |
| `<returns>` | `@return` |
| `<exception>` | `@throws` |
| `<typeparam>` | `@tparam` |

---

## Style — formal API documentation, never personal or narrative

Doxygen comments are **reference documentation for the API surface**, read by other developers and rendered into HTML/PDF reference docs. Write them as formal technical documentation, **not** as a personal narrative, a changelog, or a conversation.

**Voice and grammar:**
- Use the **third-person, present-tense, declarative** form describing *what the declaration does*. `@brief` summaries conventionally begin with a verb: "Resolves…", "Validates…", "Builds…", "Gets…", "Constructs a new instance of…".
- **No first or second person.** Never "I", "we", "you", "let's", "our".
- State behaviour as fact about the code, not as a story about the work or the author's intent.

**Never include:**
- Narrative / conversational phrasing — e.g. "This method basically just grabs the key…", "Here we loop through and…", "Now we check the deny-list first".
- Personal commentary, opinions, or hedging — "I think", "probably", "hopefully", "for now", "TODO-ish", "a bit hacky".
- Work-history / changelog notes — "added in this PR", "as discussed", "per the ticket", "refactored from the old version". (Use git/issue tracker for history, not doc comments.)
- Planning / phase / story / ticket-process terminology of any kind — e.g. phase numbers, sprint names, or a story nickname. (Reference behaviour, or an issue key if a reference is genuinely needed.)
- Jokes, emoji, or filler ("the ptr", "the ctx", "does stuff").

**Do / Don't:**

```cpp
// ❌ Narrative / personal — WRONG
/**
 * @brief Here we first check the deny-list (added in PROJ-123) and then, if we're good,
 * I look up the fingerprint. Basically returns nullptr if anything's off.
 */

// ✅ Formal API documentation — RIGHT
/**
 * @brief Validates a modern API key by checking the cache deny-list, then resolving the
 * key fingerprint to its cached metadata. Returns @c nullptr for any revoked, expired,
 * unknown, or unverifiable key (fail-closed).
 */
```

Keep descriptions accurate and specific to the declaration's contract: inputs (`@param`), result (`@return`), and failure modes (`@throws`). Meaningful, not filler — but formal, not chatty.

---

## When reviewing C++ output (orchestrator role)

1. Scan every modified header (`.h` / `.hpp` / `.hh` / `.hxx`) for exposed declarations missing a Doxygen block — immediately, before committing.
2. If violations exist: stop, report them, demand fixes. Do not proceed.
3. Only commit when the check script exits `0`.

---

## Exclusions — never flag these

- `private:` members
- Generated files: `*.generated.*`
- Build directories: `obj/`, `bin/`, `build/`
- Test files — test names are self-documenting

---

## Quick-reference patterns

```cpp
// Interface (abstract class)
/** @brief Provides read access to customer record mappings stored in the cache. */
class ICustomerRecordRepository { };

// Class
/** @brief Resolves and caches legacy-to-modern customer record mappings. */
class CustomerRecordRepository { };

// Enum (enum + every enumerator)
/** @brief Identifies the type of a document. */
enum class DocumentType {
    Procedure,  ///< A procedure document with ordered steps.
    Article     ///< An article document with free-form content.
};

// Static method
/**
 * @brief Builds the primary cache key for a customer record mapping.
 * @param tenantId The tenant slug.
 * @param recordId The legacy record ID.
 * @return The formatted cache key string.
 */
static std::string BuildKey(const std::string& tenantId, const std::string& recordId);

// Template function
/**
 * @brief Returns the larger of two comparable values.
 * @tparam T A type supporting operator<.
 * @param lhs The first value.
 * @param rhs The second value.
 * @return The greater of @p lhs and @p rhs.
 */
template <typename T>
const T& Max(const T& lhs, const T& rhs);

// Constructor
/**
 * @brief Constructs a new instance with the required cache connection.
 * @param cache The cache client.
 */
explicit CustomerRecordRepository(std::shared_ptr<ICacheClient> cache);
```

---

## Run the checker

The repo ships `scripts/check-doxygen-docs.ps1` and `scripts/check-doxygen-docs.sh`. The checker scans **header files only** (`.h` / `.hpp` / `.hh` / `.hxx`), is **presence-only** (accepts either a `/** */` block or `///` lines), and is **access-aware** (requires docs in `public:` / `protected:` sections, skips `private:`).

```powershell
# PowerShell
pwsh scripts/check-doxygen-docs.ps1 -Changed   # .h* changed since HEAD + staged
pwsh scripts/check-doxygen-docs.ps1 -Staged    # staged .h* only
pwsh scripts/check-doxygen-docs.ps1 -Files path/to/Header.hpp
```

```bash
# bash twin
bash scripts/check-doxygen-docs.sh --changed   # .h* changed since HEAD + staged
bash scripts/check-doxygen-docs.sh --staged    # staged .h* only
bash scripts/check-doxygen-docs.sh --files path/to/Header.hpp
```

The script exits `0` when clean and `1` when violations are found (CI-ready). **Block task completion until the checker exits `0`.** The script is the CI backstop; this always-active skill is the real enforcer.

---

## Pre-commit hook (repo tooling)

The repo ships `.githooks/pre-commit` — it runs the check script on staged header files automatically on every `git commit`, blocking the commit if violations are found.

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

- [Doxygen — official site](https://www.doxygen.nl/)
- [Doxygen — documenting the code (special comment blocks)](https://www.doxygen.nl/manual/docblocks.html)
- [Doxygen — special commands (`@brief`, `@param`, `@return`, `@throws`, `@tparam`)](https://www.doxygen.nl/manual/commands.html)
- [Doxygen — configuration (`EXTRACT_STATIC`, `EXTRACT_ANON_NSPACES`)](https://www.doxygen.nl/manual/config.html)
