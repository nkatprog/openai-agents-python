# Release Notes Skill

Automatically generates structured release notes from merged pull requests, commit history, and changelog entries between two git references (tags, branches, or commits).

## Overview

This skill compiles release notes by:
1. Comparing git history between a base and target reference
2. Grouping changes by type (features, bug fixes, breaking changes, deprecations)
3. Cross-referencing with the CHANGELOG.md for additional context
4. Producing a formatted release notes document suitable for GitHub Releases or documentation sites

## Inputs

| Variable | Description | Required | Default |
|---|---|---|---|
| `BASE_REF` | Base git reference (tag, branch, or commit SHA) | Yes | — |
| `TARGET_REF` | Target git reference to generate notes up to | No | `HEAD` |
| `OUTPUT_FILE` | Path to write the release notes | No | `RELEASE_NOTES.md` |
| `REPO_URL` | Base URL of the repository for generating links | No | auto-detected |
| `INCLUDE_CONTRIBUTORS` | Whether to include a contributors section | No | `true` |
| `MIN_SEVERITY` | Minimum change severity to include (`patch`, `minor`, `major`) | No | `patch` |

## Outputs

- A markdown file at `OUTPUT_FILE` containing the formatted release notes
- Exit code `0` on success, non-zero on failure
- Summary printed to stdout

## Behavior

### Change Classification

Commits and PRs are classified using conventional commit prefixes:
- `feat:` / `feat!:` → Features / Breaking Changes
- `fix:` → Bug Fixes
- `docs:` → Documentation
- `chore:`, `build:`, `ci:` → Internal / Maintenance
- `perf:` → Performance Improvements
- `refactor:` → Refactoring
- `deprecate:` → Deprecations

### Deduplication

If a commit message references a PR number (e.g., `(#123)`), the PR title is preferred over the raw commit message to avoid duplicates from squash merges.

### CHANGELOG Cross-Reference

If `CHANGELOG.md` exists and contains a section matching the target version, that section's content is merged into the output to capture manually authored notes.

## Example Usage

```bash
export BASE_REF="v0.1.0"
export TARGET_REF="v0.2.0"
export OUTPUT_FILE="RELEASE_NOTES.md"
export INCLUDE_CONTRIBUTORS="true"
bash .agents/skills/release-notes/scripts/run.sh
```

## Notes

- Requires `git` to be available in the environment
- The script does not push or publish anything; it only writes a local file
- For GitHub Actions integration, pipe `OUTPUT_FILE` content into the `body` field of a `gh release create` or `gh release edit` command
