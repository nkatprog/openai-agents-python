# Dependency Update Skill

This skill automates the process of checking for outdated dependencies and creating pull requests with updates.

## Overview

The dependency update skill scans the project's dependency files, identifies outdated packages, checks for breaking changes, and proposes updates with appropriate changelogs.

## Trigger

This skill can be triggered:
- On a schedule (weekly/monthly)
- Manually via workflow dispatch
- When a security advisory is published for a dependency

## What It Does

1. **Scan dependencies** — Reads `pyproject.toml`, `requirements*.txt`, and other dependency manifests
2. **Check for updates** — Queries PyPI for latest versions of each dependency
3. **Assess compatibility** — Checks for major version bumps that may indicate breaking changes
4. **Run tests** — Executes the test suite against updated dependencies
5. **Generate report** — Summarizes what changed, including links to changelogs/release notes
6. **Create PR** — Opens a pull request with the updates if tests pass

## Inputs

| Variable | Description | Default |
|---|---|---|
| `UPDATE_STRATEGY` | `patch`, `minor`, or `major` | `minor` |
| `EXCLUDE_PACKAGES` | Comma-separated list of packages to skip | `` |
| `DRY_RUN` | If `true`, report only without making changes | `false` |
| `AUTO_MERGE` | Auto-merge PR if CI passes | `false` |

## Outputs

- A markdown report listing all checked packages and their update status
- A pull request (unless `DRY_RUN=true`) with dependency bumps
- Exit code `0` on success, non-zero on failure

## Supported Manifest Files

- `pyproject.toml` (PEP 517/518)
- `requirements.txt`
- `requirements-dev.txt`
- `setup.cfg`

## Example Report

```
## Dependency Update Report

| Package       | Current | Latest | Update Type | Status  |
|---------------|---------|--------|-------------|----------|
| openai        | 1.30.0  | 1.35.2 | minor       | ✅ updated |
| pytest        | 8.1.0   | 8.2.1  | patch       | ✅ updated |
| pydantic      | 2.6.0   | 2.8.0  | minor       | ✅ updated |
| httpx         | 0.26.0  | 0.27.0 | minor       | ✅ updated |
```

## Notes

- Major version updates are flagged for manual review and are not auto-merged
- The skill respects version pins and constraints defined in `pyproject.toml`
- Security updates bypass the `UPDATE_STRATEGY` setting and are always included
