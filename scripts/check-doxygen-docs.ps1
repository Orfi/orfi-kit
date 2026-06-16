<#
.SYNOPSIS
    Detects public/protected/static C++ declarations in HEADER files missing a
    Doxygen comment.

.DESCRIPTION
    Scans .h/.hpp/.hh/.hxx files for exposed declarations (functions, methods,
    classes, structs, enums, templates) not preceded by a Doxygen block —
    either a /** ... */ block or one or more /// lines. Reports violations and
    exits with code 1 if any are found, 0 if all exposed declarations are
    documented. Behavioural twin of check-doxygen-docs.sh — keep the two in sync.

    Scope: HEADER FILES ONLY (.h .hpp .hh .hxx). .cpp/.cc are skipped — the API
    surface lives in headers (linkage-correct). Within a class/struct, only
    public: and protected: sections are checked; private: is never checked.
    Namespace-scope declarations default to documentable. Either /** */ or ///
    is accepted — style is NOT enforced (the skill owns style consistency).
    Exclusions: *.generated.* files; obj/ bin/ build/ path segments.

    HONEST LIMITATION: C++ access-section tracking in regex is harder than C#'s
    per-member access modifiers. This script is good-enough for CI — it catches
    undocumented public/protected declarations in normal headers — but it does
    NOT perfectly parse pathological cases: deeply-nested classes, macro-obscured
    declarations, or heavy template metaprogramming. The always-active
    /orfi-kit-doxygen-docs skill is the real enforcer; this script is the CI
    backstop.

.PARAMETER Files
    Explicit list of header file paths to scan.

.PARAMETER Staged
    Scan all header files currently staged in git (git diff --cached).

.PARAMETER Changed
    Scan all header files changed since the last commit (git diff HEAD + staged).

.EXAMPLE
    pwsh scripts/check-doxygen-docs.ps1 -Changed
    pwsh scripts/check-doxygen-docs.ps1 -Staged
    pwsh scripts/check-doxygen-docs.ps1 -Files @("include/Widget.hpp")
#>

param(
    [string[]]$Files,
    [switch]$Staged,
    [switch]$Changed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Header extensions only. .cpp/.cc are never scanned.
$HeaderExtRegex = '\.(h|hpp|hh|hxx)$'

# Matches exposed declarations: class/struct/enum/union/template preamble.
$TypePattern = '^\s*(template\s*<|class\s|struct\s|enum(\s|$)|union\s)'
# Pragmatic function/method matcher: an identifier followed by '('.
$FuncPattern = '[A-Za-z_][A-Za-z0-9_:<>~&*\s]*\('

$ExcludeFilePatterns = @('*.generated.*')
$ExcludePathSegments = @('obj', 'bin', 'build')

function Test-ShouldExclude([string]$Path) {
    $fileName = [System.IO.Path]::GetFileName($Path)
    # Header-only: skip anything that is not a .h/.hpp/.hh/.hxx (incl. .cpp/.cc).
    if ($fileName -notmatch $HeaderExtRegex) { return $true }
    foreach ($pattern in $ExcludeFilePatterns) {
        if ($fileName -like $pattern) { return $true }
    }
    $normalized = $Path -replace '\\', '/'
    foreach ($segment in $ExcludePathSegments) {
        if ($normalized -match "/$segment/") { return $true }
    }
    return $false
}

function Get-RepoRoot {
    $root = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) { return (Get-Location).Path }
    return $root.Trim()
}

# Resolve files to scan
if ($Staged) {
    $Files = git diff --cached --name-only --diff-filter=ACM 2>$null |
             Where-Object { $_ -match $HeaderExtRegex }
}
elseif ($Changed) {
    # Note: avoid a local named $staged — PowerShell vars are case-insensitive
    # so it would collide with the [switch]$Staged parameter.
    $committed   = git diff --name-only HEAD 2>$null | Where-Object { $_ -match $HeaderExtRegex }
    $stagedFiles = git diff --cached --name-only --diff-filter=ACM 2>$null | Where-Object { $_ -match $HeaderExtRegex }
    $Files       = ($committed + $stagedFiles) | Sort-Object -Unique
}

if (-not $Files -or $Files.Count -eq 0) {
    Write-Host "ℹ️  No header files to check." -ForegroundColor Cyan
    exit 0
}

$repoRoot   = Get-RepoRoot
$violations = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($file in $Files) {
    $fullPath = if ([System.IO.Path]::IsPathRooted($file)) { $file }
                else { Join-Path $repoRoot $file }

    if (-not (Test-Path $fullPath))   { continue }
    if (Test-ShouldExclude $fullPath) { continue }

    $lines = Get-Content $fullPath -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $lines) { continue }

    # --- access-section + class-depth tracking (good-enough for CI) ----------
    # depth 0 == namespace scope (documentable). Inside a class/struct body the
    # current section starts at the type's default: private for class, public
    # for struct. public:/protected:/private: labels flip it.
    $depth        = 0
    $sectionStack = [System.Collections.Generic.List[string]]::new()
    $sectionStack.Add('ns')   # namespace-scope sentinel at depth 0
    # Non-type ("plain") open braces — function bodies, initializers, namespaces,
    # enum bodies — that are NOT class/struct type levels. Tracked separately so a
    # multi-line inline method body does not pop the enclosing class's section
    # depth one line early (which previously corrupted access-section tracking).
    $plainBraces  = 0

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lt   = $line.Trim()

        # --- track access-section labels (public:/protected:/private:) ------
        # Access specifiers are only meaningful INSIDE a class/struct body
        # (depth>0). At depth 0 (namespace scope) such a label is spurious —
        # usually the symptom of a brace-tracking desync (e.g. a multi-line
        # inline method body popped depth one line early). Ignoring it here
        # protects the namespace-scope 'ns' sentinel from being corrupted into
        # 'private', which would otherwise silently suppress every later
        # namespace-scope declaration.
        if ($lt -match '^(public|protected|private)\s*:') {
            if ($depth -gt 0) { $sectionStack[$depth] = $Matches[1] }
            continue
        }

        # --- detect entering a class/struct body ----------------------------
        $isType = ($lt -match $TypePattern)

        # A bare template<...> preamble line is NOT itself flagged — the type
        # or function on the following line is the real declaration, and the
        # doc-walk skips back over template lines. (Avoids double-counting.)
        $isTemplatePreamble = ($lt -like 'template*')

        # --- decide if this line is an exposed declaration we must check ----
        $curSection   = $sectionStack[$depth]
        $documentable = ($curSection -eq 'ns' -or $curSection -eq 'public' -or $curSection -eq 'protected')

        $candidate = $false
        if ($isTemplatePreamble) {
            $candidate = $false
        }
        elseif ($isType) {
            $candidate = $true
        }
        elseif ($lt -match $FuncPattern) {
            $candidate = $true
        }

        # Skip obvious non-declarations.
        if ($lt -eq '' -or
            $lt.StartsWith('}') -or $lt.StartsWith('{') -or
            $lt.StartsWith('//') -or $lt.StartsWith('/*') -or $lt.StartsWith('*') -or
            $lt.StartsWith('#') -or
            $lt -match '^(using|typedef|friend)\s' -or
            $lt -match '^(return|else|for|while|if|switch|case)\b') {
            $candidate = $false
        }

        # A non-type candidate must look like a declaration: contain no '=' and
        # contain a ';' or ')'.
        if ($candidate -and -not $isType) {
            if ($lt -match '=') { $candidate = $false }
            if ($lt -notmatch ';' -and $lt -notmatch '\)') { $candidate = $false }
        }

        if ($candidate -and $documentable) {
            # Walk backward through attributes/blank/preproc/template lines
            # looking for a Doxygen block (/// lines OR /** ... */ block).
            $hasDoc = $false
            $j = $i - 1
            while ($j -ge 0) {
                $prev = $lines[$j].Trim()
                if ($prev -match '^///') { $hasDoc = $true; break }
                # closing */ of a /** ... */ block, or a one-line /** ... */
                if ($prev -match '\*/$' -or $prev -match '^/\*\*') { $hasDoc = $true; break }
                if ($prev -match '^\[\[' -or $prev -eq '' -or $prev -match '^#' -or $prev -like 'template*') { $j--; continue }
                break
            }

            if (-not $hasDoc) {
                $snippet = if ($lt.Length -gt 120) { $lt.Substring(0, 120) } else { $lt }
                $violations.Add([PSCustomObject]@{
                    File   = $file
                    Line   = $i + 1
                    Member = $snippet
                })
            }
        }

        # --- update nesting depth based on braces on this line --------------
        # All non-type braces (function bodies, initializers, namespaces, enum
        # bodies) accumulate into $plainBraces so their closers unwind THEM first,
        # before any type level is popped. This stops a multi-line inline method
        # body from prematurely popping the enclosing class section.
        $nOpen  = ($line.Length - ($line -replace '\{', '').Length)
        $nClose = ($line.Length - ($line -replace '\}', '').Length)

        if ($isType -and $nOpen -gt 0) {
            # entering a type body: default section depends on class vs struct
            $newDefault = if ($lt -match '^(struct|union)\b') { 'public' } else { 'private' }
            $depth++
            if ($sectionStack.Count -le $depth) { $sectionStack.Add($newDefault) }
            else { $sectionStack[$depth] = $newDefault }
            $nOpen--
        }

        # Remaining opens on this line are plain (non-type) opens.
        $plainBraces += $nOpen

        # Each close first unwinds a plain brace; only when none remain does a
        # close pop a type-section level.
        for ($c = 0; $c -lt $nClose; $c++) {
            if ($plainBraces -gt 0) {
                $plainBraces--
            }
            elseif ($depth -gt 0) {
                $sectionStack.RemoveAt($depth)
                $depth--
            }
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Host ""
    Write-Host "❌ Missing Doxygen comments — $($violations.Count) violation(s):" -ForegroundColor Red
    Write-Host ""
    foreach ($v in $violations) {
        Write-Host "  $($v.File):$($v.Line)" -ForegroundColor Yellow
        Write-Host "  → $($v.Member)" -ForegroundColor Gray
        Write-Host ""
    }
    Write-Host "Fix: add a /** @brief ... */ (or /// ...) Doxygen block above each flagged declaration." -ForegroundColor Cyan
    Write-Host "See: /orfi-kit-doxygen-docs skill for the full tag reference." -ForegroundColor Cyan
    exit 1
}

Write-Host "✅ All public/protected declarations are documented." -ForegroundColor Green
exit 0
