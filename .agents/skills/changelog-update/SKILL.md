# Changelog Update Skill

Automatically maintains the project CHANGELOG.md by analyzing merged PRs, commits, and version bumps to generate structured changelog entries following Keep a Changelog conventions.

## Overview

This skill monitors repository activity and generates or updates CHANGELOG.md entries when:
- A new version tag is pushed
- A PR is merged into the main branch
- A release is being prepared

## Trigger Conditions

- New git tag matching `v*` pattern is created
- PR merged with label `changelog` or `release`
- Manual invocation via workflow dispatch

## Behavior

### Entry Categorization

The skill analyzes PR titles and commit messages to categorize changes:

| Category | Keywords / Conventional Commit Types |
|----------|--------------------------------------|
| Added | `feat:`, `add`, `new` |
| Changed | `refactor:`, `change`, `update`, `improve` |
| Deprecated | `deprecate` |
| Removed | `remove`, `delete`, `drop` |
| Fixed | `fix:`, `bug`, `patch` |
| Security | `security`, `vuln`, `cve` |

### Output Format

Follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format:

```markdown
## [1.2.0] - 2024-01-15

### Added
- New feature description (#123)

### Fixed
- Bug fix description (#124)
```

## Configuration

The skill reads optional configuration from `.agents/skills/changelog-update/config.yaml`:

```yaml
changelog_file: CHANGELOG.md
version_source: pyproject.toml   # or package.json, setup.py
include_authors: false
group_by_type: true
max_entries_per_section: 20
```

## Scripts

- `scripts/run.sh` — Linux/macOS implementation
- `scripts/run.ps1` — Windows PowerShell implementation

## Outputs

- Updated `CHANGELOG.md` committed to the repository
- Summary comment posted to the triggering PR (if applicable)
- GitHub Release notes populated from the same content

## Requirements

- `gh` CLI authenticated with repo write permissions
- `git` available in PATH
- Python 3.8+ (for version parsing helpers)
