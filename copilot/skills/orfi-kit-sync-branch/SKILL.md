---
name: orfi-kit-sync-branch
description: Sync feature branch with parent epic and master before push.
disable-model-invocation: true
---

# orfi-kit-sync-branch (Copilot version)

Sync chain:
`origin/master -> epic/* -> feature/*`

Run from a `feature/*` branch.

## 1. Verify current feature branch

```powershell
$featureBranch = git branch --show-current
if ($featureBranch -notmatch '^feature/') { throw "ABORTED: must run on feature/* (current: $featureBranch)" }
$featureWorktree = (Get-Location).Path
```

## 2. Resolve parent epic branch

Use state file first:

```powershell
$stateFile = '.claude\hooks\state\parent-epic'
$epicBranch = if (Test-Path $stateFile) { (Get-Content $stateFile -Raw).Trim() } else { '' }
```

If missing, discover:

```powershell
git fetch origin --prune
$candidates = git branch -r | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^origin/epic/' } | ForEach-Object { $_ -replace '^origin/' }
```

If multiple candidates exist, pick nearest ancestor:

```powershell
$head = git rev-parse HEAD
$scored = foreach ($c in $candidates) {
  $mb = git merge-base $head "origin/$c"
  if ($mb) {
    $distance = git rev-list --count "$mb..$head"
    [PSCustomObject]@{ Branch = $c; Distance = [int]$distance }
  }
}
$epicBranch = ($scored | Sort-Object Distance | Select-Object -First 1).Branch
if (-not $epicBranch) { throw "ABORTED: Could not resolve parent epic branch automatically." }
```

## 3. Locate epic worktree

```powershell
$worktrees = git worktree list --porcelain
$epicWorktree = $null
for ($i = 0; $i -lt $worktrees.Count; $i++) {
  if ($worktrees[$i] -like "branch refs/heads/$epicBranch") {
    $epicWorktree = ($worktrees[$i - 1] -replace '^worktree ', '')
    break
  }
}
if (-not $epicWorktree) { throw "ABORTED: Epic worktree for $epicBranch not found." }
```

## 4. Fetch latest

```powershell
git fetch origin --prune
```

## 5. Sync epic with master (detect strategy)

```powershell
Set-Location $epicWorktree
$hasMergeHistory = [bool](git log --oneline --merges -5 "origin/$epicBranch")
$parentCount = (git cat-file -p "origin/$epicBranch" | Select-String '^parent').Count
$strategy = if ($hasMergeHistory -or $parentCount -eq 2) { 'merge' } else { 'rebase' }
```

If merge strategy:

```powershell
git merge origin/master
git push origin $epicBranch
```

If rebase strategy:

```powershell
git rebase origin/master
git push --force-with-lease origin $epicBranch
```

If conflicts happen, stop and resolve in epic worktree, then re-run this command.

## 6. Rebase feature on epic

```powershell
Set-Location $featureWorktree
git rebase $epicBranch
```

If conflicts happen, stop and resolve in feature worktree, then re-run this command.

## 7. Record sync state

```powershell
New-Item -ItemType Directory -Force -Path '.claude\hooks\state' | Out-Null
Set-Content -Path '.claude\hooks\state\parent-epic' -Value $epicBranch
Set-Content -Path '.claude\hooks\state\last-sync-timestamp' -Value ([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))
```

## 8. Completion message

Report:
- Feature branch
- Epic branch
- Sync strategy (`merge` or `rebase`)
- Ready command:

```powershell
git push --force-with-lease origin $featureBranch
```
