# Issue Triage Skill - PowerShell Script
# Triages GitHub issues by applying labels, assigning owners, and posting initial responses

param(
    [Parameter(Mandatory=$true)]
    [string]$IssueNumber,
    
    [Parameter(Mandatory=$false)]
    [string]$Repo = $env:GITHUB_REPOSITORY,
    
    [Parameter(Mandatory=$false)]
    [string]$GithubToken = $env:GITHUB_TOKEN
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

function Invoke-GitHubApi {
    param(
        [string]$Endpoint,
        [string]$Method = "GET",
        [hashtable]$Body = $null
    )
    
    $headers = @{
        "Authorization" = "Bearer $GithubToken"
        "Accept" = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    
    $uri = "https://api.github.com/repos/$Repo/$Endpoint"
    
    $params = @{
        Uri = $uri
        Headers = $headers
        Method = $Method
    }
    
    if ($Body) {
        $params["Body"] = ($Body | ConvertTo-Json -Depth 10)
        $params["ContentType"] = "application/json"
    }
    
    return Invoke-RestMethod @params
}

function Get-IssueDetails {
    param([string]$Number)
    Write-Log "Fetching issue #$Number details"
    return Invoke-GitHubApi -Endpoint "issues/$Number"
}

function Apply-Labels {
    param([string]$Number, [string[]]$Labels)
    if ($Labels.Count -eq 0) { return }
    Write-Log "Applying labels: $($Labels -join ', ') to issue #$Number"
    Invoke-GitHubApi -Endpoint "issues/$Number/labels" -Method "POST" -Body @{ labels = $Labels } | Out-Null
}

function Post-Comment {
    param([string]$Number, [string]$Comment)
    Write-Log "Posting triage comment on issue #$Number"
    Invoke-GitHubApi -Endpoint "issues/$Number/comments" -Method "POST" -Body @{ body = $Comment } | Out-Null
}

function Classify-Issue {
    param([string]$Title, [string]$Body)
    
    $labels = @()
    $combined = "$Title $Body".ToLower()
    
    if ($combined -match "bug|error|exception|crash|traceback|fail") {
        $labels += "bug"
    }
    if ($combined -match "feature|enhancement|request|add support|would be nice") {
        $labels += "enhancement"
    }
    if ($combined -match "doc|documentation|readme|example|tutorial") {
        $labels += "documentation"
    }
    if ($combined -match "question|how to|how do|help|unclear") {
        $labels += "question"
    }
    if ($combined -match "performance|slow|latency|speed|memory") {
        $labels += "performance"
    }
    
    if ($labels.Count -eq 0) {
        $labels += "needs-triage"
    }
    
    return $labels
}

# Main
Write-Log "Starting issue triage for issue #$IssueNumber in $Repo"

if (-not $GithubToken) {
    Write-Log "GITHUB_TOKEN is not set" "ERROR"
    exit 1
}

$issue = Get-IssueDetails -Number $IssueNumber
Write-Log "Issue title: $($issue.title)"

$existingLabels = $issue.labels | ForEach-Object { $_.name }
if ($existingLabels -contains "needs-triage" -or $existingLabels.Count -eq 0) {
    $newLabels = Classify-Issue -Title $issue.title -Body $issue.body
    Apply-Labels -Number $IssueNumber -Labels $newLabels
    
    $comment = @"
Thank you for opening this issue! It has been automatically triaged and labeled as: **$($newLabels -join ', ')**.

A maintainer will review it shortly. In the meantime, please ensure you have provided:
- A clear description of the problem or request
- Steps to reproduce (for bugs)
- Relevant code snippets or error messages
"@
    Post-Comment -Number $IssueNumber -Comment $comment
    Write-Log "Triage complete. Applied labels: $($newLabels -join ', ')"
} else {
    Write-Log "Issue #$IssueNumber already has labels, skipping auto-triage"
}

Write-Log "Issue triage finished successfully"
