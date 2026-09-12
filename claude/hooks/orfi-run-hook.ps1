param(
    [Parameter(Mandatory = $true)]
    [string]$HookName
)

$ErrorActionPreference = 'Continue'

function Get-HookScript {
    $hook = "orfi-kit-$HookName.sh"
    $win = "$(( $env:USERPROFILE -replace '\\', '/' ))/.claude/hooks/$hook"
    $user = $env:USERNAME
    $candidates = @(
        $win,
        "/c/Users/$user/.claude/hooks/$hook",
        "/mnt/c/Users/$user/.claude/hooks/$hook"
    )
    foreach ($c in $candidates) {
        if ((bash -c "test -f $c && echo ORFI_FOUND") -match 'ORFI_FOUND') {
            return $c
        }
    }
    return $null
}

$resolved = Get-HookScript
if (-not $resolved) {
    Write-Host "orfi-run-hook: could not resolve orfi-kit-$HookName.sh under any candidate path" -ForegroundColor Yellow
    exit 0
}

& bash $resolved
exit $LASTEXITCODE