<#
.SYNOPSIS
    Detects public/protected/static C# members missing /// XML doc comments.

.DESCRIPTION
    Scans .cs files for public or protected member declarations not preceded
    by a /// XML doc comment block. Reports violations and exits with code 1
    if any are found, 0 if all members are documented.

    Scope: public and protected members only. private members are never checked.
    Exclusions: auto-generated files, Migrations/, test projects.

.PARAMETER Files
    Explicit list of .cs file paths to scan.

.PARAMETER Staged
    Scan all .cs files currently staged in git (git diff --cached).

.PARAMETER Changed
    Scan all .cs files changed since the last commit (git diff HEAD + staged).

.EXAMPLE
    pwsh scripts/check-xml-docs.ps1 -Changed
    pwsh scripts/check-xml-docs.ps1 -Staged
    pwsh scripts/check-xml-docs.ps1 -Files @("src/Services/PublicApi/Domain/ContainerLegacyMap.cs")
#>

param(
    [string[]]$Files,
    [switch]$Staged,
    [switch]$Changed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Matches public/protected member declarations (classes, interfaces, methods, properties, enums, etc.)
$MemberPattern = '^\s*(public|protected)(\s+(static|virtual|override|abstract|async|sealed|readonly|new|extern|partial))*\s+\S'

$ExcludeFilePatterns = @('*.g.cs', '*.designer.cs', '*.generated.cs')
$ExcludePathSegments = @('Migrations', 'obj', 'bin')

function Test-ShouldExclude([string]$Path) {
    $fileName = [System.IO.Path]::GetFileName($Path)
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
             Where-Object { $_ -match '\.cs$' }
}
elseif ($Changed) {
    $committed = git diff --name-only HEAD 2>$null | Where-Object { $_ -match '\.cs$' }
    $staged    = git diff --cached --name-only --diff-filter=ACM 2>$null | Where-Object { $_ -match '\.cs$' }
    $Files     = ($committed + $staged) | Sort-Object -Unique
}

if (-not $Files -or $Files.Count -eq 0) {
    Write-Host "ℹ️  No .cs files to check." -ForegroundColor Cyan
    exit 0
}

$repoRoot  = Get-RepoRoot
$violations = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($file in $Files) {
    $fullPath = if ([System.IO.Path]::IsPathRooted($file)) { $file }
                else { Join-Path $repoRoot $file }

    if (-not (Test-Path $fullPath))    { continue }
    if (Test-ShouldExclude $fullPath)  { continue }

    $lines = Get-Content $fullPath -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $lines) { continue }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        if ($line -notmatch $MemberPattern) { continue }

        # Skip plain field declarations (end with semicolon, no property body)
        if ($line.TrimEnd() -match ';\s*$' -and $line -notmatch '\{') { continue }

        # Walk backward through attributes and blank lines looking for ///
        $hasDoc = $false
        $j = $i - 1
        while ($j -ge 0) {
            $prev = $lines[$j].Trim()
            if ($prev -match '^///') { $hasDoc = $true; break }
            if ($prev -match '^\[' -or $prev -eq '' -or $prev -match '^#') { $j--; continue }
            break
        }

        if (-not $hasDoc) {
            $violations.Add([PSCustomObject]@{
                File   = $file
                Line   = $i + 1
                Member = $line.Trim().Substring(0, [Math]::Min(120, $line.Trim().Length))
            })
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Host ""
    Write-Host "❌ Missing /// XML doc comments — $($violations.Count) violation(s):" -ForegroundColor Red
    Write-Host ""
    foreach ($v in $violations) {
        Write-Host "  $($v.File):$($v.Line)" -ForegroundColor Yellow
        Write-Host "  → $($v.Member)" -ForegroundColor Gray
        Write-Host ""
    }
    Write-Host "Fix: add a /// <summary>...</summary> block above each flagged member." -ForegroundColor Cyan
    Write-Host "See: /orfi-kit-xml-docs skill for the full tag reference." -ForegroundColor Cyan
    exit 1
}

Write-Host "✅ All public/protected members are documented." -ForegroundColor Green
exit 0
