# Changelog Update Skill - PowerShell Script
# Updates CHANGELOG.md based on merged PRs and commits since last release

param(
    [string]$RepoPath = ".",
    [string]$ChangelogFile = "CHANGELOG.md",
    [string]$BaseBranch = "main",
    [string]$Version = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Get-LastReleaseTag {
    try {
        $tag = git describe --tags --abbrev=0 2>$null
        return $tag
    } catch {
        return $null
    }
}

function Get-CommitsSinceTag {
    param([string]$Tag)
    if ($Tag) {
        $commits = git log "$Tag..HEAD" --oneline --no-merges 2>$null
    } else {
        $commits = git log --oneline --no-merges -50 2>$null
    }
    return $commits
}

function Categorize-Commits {
    param([string[]]$Commits)

    $categories = @{
        "feat"     = @()
        "fix"      = @()
        "docs"     = @()
        "chore"    = @()
        "refactor" = @()
        "test"     = @()
        "other"    = @()
    }

    foreach ($commit in $Commits) {
        if ($commit -match '^[a-f0-9]+ (feat|fix|docs|chore|refactor|test)(\(.+\))?!?: (.+)$') {
            $type = $Matches[1]
            $msg  = $Matches[3]
            $categories[$type] += "- $msg"
        } else {
            $msg = ($commit -replace '^[a-f0-9]+ ', '')
            $categories["other"] += "- $msg"
        }
    }

    return $categories
}

function Build-ChangelogEntry {
    param(
        [string]$Version,
        [hashtable]$Categories
    )

    $date = Get-Date -Format "yyyy-MM-dd"
    $entry = "## [$Version] - $date`n`n"

    $sectionMap = @{
        "feat"     = "### Features"
        "fix"      = "### Bug Fixes"
        "docs"     = "### Documentation"
        "refactor" = "### Refactoring"
        "test"     = "### Tests"
        "chore"    = "### Chores"
        "other"    = "### Other Changes"
    }

    foreach ($key in @("feat", "fix", "docs", "refactor", "test", "chore", "other")) {
        if ($Categories[$key].Count -gt 0) {
            $entry += "$($sectionMap[$key])`n"
            $entry += ($Categories[$key] -join "`n") + "`n`n"
        }
    }

    return $entry
}

# --- Main ---

Set-Location $RepoPath

if (-not (Test-Path $ChangelogFile)) {
    Write-Warning "$ChangelogFile not found. Creating a new one."
    "# Changelog`n`nAll notable changes to this project will be documented in this file.`n" | Set-Content $ChangelogFile
}

$lastTag = Get-LastReleaseTag
if ($lastTag) {
    Write-Info "Last release tag: $lastTag"
} else {
    Write-Warning "No previous release tag found. Using last 50 commits."
}

if (-not $Version) {
    $Version = "Unreleased"
    Write-Warning "No version specified. Using 'Unreleased'."
}

$rawCommits = Get-CommitsSinceTag -Tag $lastTag
if (-not $rawCommits) {
    Write-Warning "No commits found since last tag. Nothing to update."
    exit 0
}

$commitLines = $rawCommits -split "`n" | Where-Object { $_ -ne "" }
Write-Info "Found $($commitLines.Count) commits to process."

$categories = Categorize-Commits -Commits $commitLines
$entry = Build-ChangelogEntry -Version $Version -Categories $categories

$existingContent = Get-Content $ChangelogFile -Raw
$marker = "# Changelog"
$updatedContent = $existingContent -replace [regex]::Escape($marker), "$marker`n`n$entry"

Set-Content $ChangelogFile $updatedContent
Write-Success "Changelog updated successfully at $ChangelogFile"
