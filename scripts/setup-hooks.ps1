<#
.SYNOPSIS
    Wires this clone's git hooks to the repo's .githooks directory.

.DESCRIPTION
    Runs `git config core.hooksPath .githooks` so .githooks/pre-commit fires on
    every commit, and marks the hook executable.

    One-time per clone. Git does not share hook config across clones or
    worktrees, so each needs this once. Behavioural twin of setup-hooks.sh —
    keep the two in sync.

    The hook it wires runs the doc-presence checkers on staged files:
    *.cs via check-xml-docs, and headers via check-doxygen-docs.

.PARAMETER Unset
    Reverts core.hooksPath to git's default (.git/hooks), disabling the hook.

.EXAMPLE
    pwsh scripts/setup-hooks.ps1
    pwsh scripts/setup-hooks.ps1 -Unset
#>

param(
    [switch]$Unset
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

git rev-parse --show-toplevel *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "error: not inside a git repository." -ForegroundColor Red
    exit 1
}
$repoRoot = (git rev-parse --show-toplevel).Trim()

if ($Unset) {
    git config --unset core.hooksPath *> $null
    Write-Host "Unset core.hooksPath — git hooks revert to .git/hooks (hook disabled)." -ForegroundColor Yellow
    exit 0
}

$hooksDir = Join-Path $repoRoot '.githooks'
if (-not (Test-Path $hooksDir)) {
    Write-Host "error: $hooksDir not found. Run this from a repo that ships .githooks/." -ForegroundColor Red
    exit 1
}

git config core.hooksPath .githooks
Write-Host "Set core.hooksPath = .githooks" -ForegroundColor Green

# The executable bit only means anything on POSIX, but git tracks it in the index
# on every platform — so set it here too, or a clone on Linux/macOS gets a hook
# git refuses to run.
$hook = Join-Path $hooksDir 'pre-commit'
if (Test-Path $hook) {
    git update-index --chmod=+x .githooks/pre-commit *> $null
    if ($IsLinux -or $IsMacOS) { chmod +x $hook 2>$null }
    Write-Host "Marked .githooks/pre-commit executable." -ForegroundColor Green
} else {
    Write-Host "warning: .githooks/pre-commit is missing — nothing will run on commit." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done. The pre-commit hook now runs on every commit in this clone."
Write-Host "It checks staged .cs files for /// XML docs and staged headers for Doxygen blocks."
Write-Host "Bypass in exceptional cases with: git commit --no-verify"
