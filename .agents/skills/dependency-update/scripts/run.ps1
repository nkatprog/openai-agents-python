# Dependency Update Script for Windows
# Checks for outdated dependencies and creates a PR with updates

param(
    [string]$BranchPrefix = "deps/update",
    [switch]$DryRun = $false,
    [switch]$MajorUpdates = $false
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

# Check required tools
function Check-Prerequisites {
    $missing = @()
    foreach ($tool in @("python", "pip", "git")) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            $missing += $tool
        }
    }
    if ($missing.Count -gt 0) {
        Write-Err "Missing required tools: $($missing -join ', ')"
        exit 1
    }
    Write-Info "All prerequisites found."
}

# Get outdated packages
function Get-OutdatedPackages {
    Write-Info "Checking for outdated packages..."
    $output = pip list --outdated --format=json 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to list outdated packages."
        exit 1
    }
    $packages = $output | ConvertFrom-Json
    if (-not $MajorUpdates) {
        # Filter out major version bumps
        $packages = $packages | Where-Object {
            $current = [version]($_.version -replace '[^0-9.]', '')
            $latest  = [version]($_.latest_version -replace '[^0-9.]', '')
            $current.Major -eq $latest.Major
        }
    }
    return $packages
}

# Update pyproject.toml or requirements files
function Update-Dependencies {
    param($Packages)

    if ($Packages.Count -eq 0) {
        Write-Success "All dependencies are up to date."
        return $false
    }

    Write-Info "Updating $($Packages.Count) package(s)..."
    foreach ($pkg in $Packages) {
        Write-Info "  $($pkg.name): $($pkg.version) -> $($pkg.latest_version)"
        if (-not $DryRun) {
            pip install "$($pkg.name)==$($pkg.latest_version)" --quiet
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to update $($pkg.name), skipping."
            }
        }
    }
    return $true
}

# Create a git branch and commit changes
function Commit-Changes {
    param($Packages)

    $date = Get-Date -Format "yyyyMMdd"
    $branchName = "$BranchPrefix-$date"

    Write-Info "Creating branch: $branchName"
    git checkout -b $branchName 2>&1 | Out-Null

    # Freeze updated deps
    pip freeze | Out-File -Encoding utf8 requirements-updated.txt

    git add -A
    $pkgList = ($Packages | ForEach-Object { "$($_.name) $($_.latest_version)" }) -join ", "
    $commitMsg = "chore(deps): update dependencies - $pkgList"
    git commit -m $commitMsg

    Write-Success "Changes committed on branch '$branchName'."
    Write-Info "Push with: git push origin $branchName"
}

# Main
Check-Prerequisites
$outdated = Get-OutdatedPackages

if ($DryRun) {
    Write-Warning "Dry-run mode: no changes will be made."
    $outdated | ForEach-Object {
        Write-Host "  Would update: $($_.name) $($_.version) -> $($_.latest_version)"
    }
    exit 0
}

$updated = Update-Dependencies -Packages $outdated
if ($updated) {
    Commit-Changes -Packages $outdated
}
