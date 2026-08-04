<#
.SYNOPSIS
    Wires this clone's git hooks to the repo's .githooks directory.

.DESCRIPTION
    Runs `git config core.hooksPath .githooks` so .githooks/pre-commit fires on
    every commit, and marks the hook executable.

    Also sets this clone's commit identity. This is a personal repo, and a machine
    whose GLOBAL git config carries a work identity would otherwise stamp it on
    every commit here. Both author AND committer are covered: the committer is
    read from config independently and is the one that leaks unnoticed, since only
    the author is usually displayed.

    One-time per clone. Git does not share hook config across clones or
    worktrees, so each needs this once. .git/config is not a tracked file — it
    cannot be committed — which is why this belongs in a script that ships.
    Behavioural twin of setup-hooks.sh — keep the two in sync.

    The hook it wires runs the doc-presence checkers on staged files:
    *.cs via check-xml-docs, and headers via check-doxygen-docs.

.PARAMETER Unset
    Reverts core.hooksPath to git's default (.git/hooks), disabling the hook.
    Leaves the commit identity alone on purpose: unsetting it would silently
    restore a work identity on a personal repo, which is the failure this guards
    against. Remove it by hand if you ever need to.

.EXAMPLE
    pwsh scripts/setup-hooks.ps1
    pwsh scripts/setup-hooks.ps1 -Unset
#>

param(
    [switch]$Unset
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# This clone's commit identity. Edit these two if you fork the kit.
$CommitName  = 'Orfi'
$CommitEmail = 'waelorfi@aucegypt.edu'

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

# Repo-local identity, overriding whatever the global config says. Reported rather
# than applied silently: a changed commit identity is something you should see.
git config user.name  $CommitName
git config user.email $CommitEmail
Write-Host "Set commit identity = $CommitName <$CommitEmail>" -ForegroundColor Green

# Verify it resolves, and say so if something still outranks it. `git var` reports
# the identity git would actually use, which is the only check that matters here.
$expected       = "$CommitName <$CommitEmail>"
$actualAuthor   = ((git var GIT_AUTHOR_IDENT)    -replace ' \d+ [+-]\d+$','').Trim()
$actualCommitter= ((git var GIT_COMMITTER_IDENT) -replace ' \d+ [+-]\d+$','').Trim()
if ($actualAuthor -eq $expected -and $actualCommitter -eq $expected) {
    Write-Host "Verified: author and committer both resolve to $expected" -ForegroundColor Green
} else {
    Write-Host "warning: identity did not take as expected." -ForegroundColor Yellow
    Write-Host "  author:    $actualAuthor"
    Write-Host "  committer: $actualCommitter"
    Write-Host "  expected:  $expected"
    Write-Host "  Check for GIT_AUTHOR_* / GIT_COMMITTER_* env vars, which outrank config."
}

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
