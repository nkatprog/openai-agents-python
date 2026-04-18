# PR Review Skill

This skill automates pull request review by analyzing code changes, checking for common issues, and providing structured feedback.

## What it does

- Analyzes diffs for potential bugs, style issues, and security concerns
- Checks that tests are included for new functionality
- Verifies documentation is updated when public APIs change
- Summarizes changes and provides an overall assessment
- Posts review comments directly to the PR

## Inputs

| Variable | Description | Required |
|----------|-------------|----------|
| `PR_NUMBER` | Pull request number to review | Yes |
| `GITHUB_TOKEN` | GitHub token with PR read/write access | Yes |
| `REPO` | Repository in `owner/repo` format | Yes |
| `OPENAI_API_KEY` | OpenAI API key for analysis | Yes |
| `REVIEW_LEVEL` | `light`, `standard`, or `thorough` (default: `standard`) | No |
| `POST_COMMENT` | Whether to post review comment (`true`/`false`, default: `true`) | No |

## Outputs

- Review summary printed to stdout
- Optional comment posted to the PR on GitHub
- Exit code `0` for approved, `1` for changes requested, `2` for error

## Usage

### Linux/macOS

```bash
export PR_NUMBER=42
export GITHUB_TOKEN=ghp_...
export REPO=myorg/myrepo
export OPENAI_API_KEY=sk-...
bash .agents/skills/pr-review/scripts/run.sh
```

### Windows (PowerShell)

```powershell
$env:PR_NUMBER = "42"
$env:GITHUB_TOKEN = "ghp_..."
$env:REPO = "myorg/myrepo"
$env:OPENAI_API_KEY = "sk-..."
.agents/skills/pr-review/scripts/run.ps1
```

## Review Criteria

The skill evaluates PRs against the following criteria:

1. **Correctness** — Does the logic appear sound? Are edge cases handled?
2. **Tests** — Are new features and bug fixes covered by tests?
3. **Documentation** — Are docstrings and docs updated for public API changes?
4. **Security** — Are there obvious security issues (e.g., secrets in code, injection risks)?
5. **Style** — Does the code follow project conventions?

## Notes

- Requires `curl` and `jq` on Linux/macOS
- Requires PowerShell 7+ on Windows
- Large PRs (>500 changed lines) may take longer to analyze
- Set `REVIEW_LEVEL=light` for quick checks on large PRs
