# Examples Auto-Run Script for Windows
# Automatically discovers and runs all examples in the repository,
# capturing output and reporting success/failure for each.

param(
    [string]$ExamplesDir = "examples",
    [int]$TimeoutSeconds = 30,
    [switch]$StopOnFailure,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "../../..")

$PassCount = 0
$FailCount = 0
$SkipCount = 0
$Results = @()

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
}

function Write-Result {
    param([string]$Status, [string]$Example, [string]$Detail = "")
    switch ($Status) {
        "PASS" { Write-Host "  [PASS] $Example" -ForegroundColor Green }
        "FAIL" { Write-Host "  [FAIL] $Example" -ForegroundColor Red }
        "SKIP" { Write-Host "  [SKIP] $Example" -ForegroundColor Yellow }
    }
    if ($Detail -and $Verbose) {
        Write-Host "         $Detail" -ForegroundColor Gray
    }
}

Write-Header "Examples Auto-Run"
Write-Host "Repository: $RepoRoot"
Write-Host "Examples directory: $ExamplesDir"
Write-Host "Timeout: ${TimeoutSeconds}s per example"

# Verify examples directory exists
$ExamplesPath = Join-Path $RepoRoot $ExamplesDir
if (-not (Test-Path $ExamplesPath)) {
    Write-Host "ERROR: Examples directory not found: $ExamplesPath" -ForegroundColor Red
    exit 1
}

# Discover all Python example files
$ExampleFiles = Get-ChildItem -Path $ExamplesPath -Filter "*.py" -Recurse |
    Where-Object { $_.Name -notlike "__*" } |
    Sort-Object FullName

Write-Host "Found $($ExampleFiles.Count) example file(s)"

if ($ExampleFiles.Count -eq 0) {
    Write-Host "No examples found. Exiting." -ForegroundColor Yellow
    exit 0
}

# Check for required environment variables
$RequiredEnvVars = @("OPENAI_API_KEY")
$MissingVars = $RequiredEnvVars | Where-Object { -not [System.Environment]::GetEnvironmentVariable($_) }
if ($MissingVars.Count -gt 0) {
    Write-Host "WARNING: Missing environment variables: $($MissingVars -join ', ')" -ForegroundColor Yellow
    Write-Host "Some examples may be skipped or fail."
}

Write-Header "Running Examples"

foreach ($File in $ExampleFiles) {
    $RelativePath = $File.FullName.Replace($RepoRoot.ToString(), "").TrimStart("\", "/")

    # Check for skip marker in file
    $Content = Get-Content $File.FullName -Raw -ErrorAction SilentlyContinue
    if ($Content -match "# agents:skip" -or $Content -match "# noqa: agents-skip") {
        $SkipCount++
        Write-Result "SKIP" $RelativePath "skip marker found"
        $Results += [PSCustomObject]@{ Status = "SKIP"; File = $RelativePath; Reason = "skip marker" }
        continue
    }

    # Run the example with timeout
    try {
        $Process = Start-Process -FilePath "python" `
            -ArgumentList $File.FullName `
            -WorkingDirectory $RepoRoot `
            -PassThru -NoNewWindow `
            -RedirectStandardOutput ([System.IO.Path]::GetTempFileName()) `
            -RedirectStandardError ([System.IO.Path]::GetTempFileName())

        $Completed = $Process.WaitForExit($TimeoutSeconds * 1000)

        if (-not $Completed) {
            $Process.Kill()
            $FailCount++
            Write-Result "FAIL" $RelativePath "timed out after ${TimeoutSeconds}s"
            $Results += [PSCustomObject]@{ Status = "FAIL"; File = $RelativePath; Reason = "timeout" }
        } elseif ($Process.ExitCode -eq 0) {
            $PassCount++
            Write-Result "PASS" $RelativePath
            $Results += [PSCustomObject]@{ Status = "PASS"; File = $RelativePath; Reason = "" }
        } else {
            $FailCount++
            Write-Result "FAIL" $RelativePath "exit code $($Process.ExitCode)"
            $Results += [PSCustomObject]@{ Status = "FAIL"; File = $RelativePath; Reason = "exit code $($Process.ExitCode)" }
        }
    } catch {
        $FailCount++
        Write-Result "FAIL" $RelativePath $_.Exception.Message
        $Results += [PSCustomObject]@{ Status = "FAIL"; File = $RelativePath; Reason = $_.Exception.Message }
    }

    if ($StopOnFailure -and $FailCount -gt 0) {
        Write-Host "
Stopping on first failure (--StopOnFailure set)." -ForegroundColor Red
        break
    }
}

# Summary
Write-Header "Summary"
Write-Host "  Passed:  $PassCount" -ForegroundColor Green
Write-Host "  Failed:  $FailCount" -ForegroundColor $(if ($FailCount -gt 0) { "Red" } else { "Green" })
Write-Host "  Skipped: $SkipCount" -ForegroundColor Yellow
Write-Host "  Total:   $($PassCount + $FailCount + $SkipCount)"

if ($FailCount -gt 0) {
    Write-Host "
Failed examples:" -ForegroundColor Red
    $Results | Where-Object { $_.Status -eq "FAIL" } | ForEach-Object {
        Write-Host "  - $($_.File): $($_.Reason)" -ForegroundColor Red
    }
    exit 1
}

Write-Host "
All examples passed!" -ForegroundColor Green
exit 0
