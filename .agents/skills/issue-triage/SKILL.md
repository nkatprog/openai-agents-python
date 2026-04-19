# Issue Triage Skill

Automatically triages new GitHub issues by analyzing content, applying labels, assigning priority, and routing to appropriate team members.

## What This Skill Does

1. **Analyzes issue content** — reads title, body, and any attached logs or code snippets
2. **Classifies issue type** — bug, feature request, documentation, question, or enhancement
3. **Assigns labels** — applies relevant labels based on classification and affected components
4. **Sets priority** — determines priority (P0–P3) based on severity signals in the issue
5. **Routes to owners** — suggests or assigns the appropriate maintainer or team
6. **Posts triage comment** — leaves a structured comment summarizing the triage decision

## Trigger

This skill runs when:
- A new issue is opened in the repository
- An issue is reopened
- Manually triggered via workflow dispatch with an issue number

## Labels Applied

### Type Labels
- `bug` — something is broken or not working as expected
- `feature-request` — request for new functionality
- `documentation` — docs are missing, incorrect, or unclear
- `question` — user needs help or clarification
- `enhancement` — improvement to existing functionality

### Priority Labels
- `P0-critical` — production breakage, data loss, security issue
- `P1-high` — major functionality broken, no workaround
- `P2-medium` — functionality impaired, workaround exists
- `P3-low` — minor issue, cosmetic, or nice-to-have

### Component Labels
- `comp:agents` — core agent runtime
- `comp:tools` — tool/function calling
- `comp:tracing` — tracing and observability
- `comp:streaming` — streaming responses
- `comp:handoffs` — agent handoff logic
- `comp:docs` — documentation site
- `comp:examples` — example scripts

## Priority Signals

The agent looks for these signals when determining priority:

| Signal | Priority Bump |
|--------|---------------|
| "crash", "panic", "data loss" | → P0 |
| "broken", "not working", "regression" | → P1 |
| "unexpected behavior", "incorrect" | → P2 |
| "typo", "minor", "cosmetic" | → P3 |

## Triage Comment Format

The skill posts a comment in this format:

```
## 🏷️ Automated Triage

**Type:** Bug
**Priority:** P2-medium
**Components:** comp:agents, comp:tools

**Summary:** <one-sentence summary of the issue>

**Suggested assignee:** @username

**Next steps:**
- [ ] Reproduce the issue
- [ ] Identify root cause
- [ ] Fix and add regression test

_This triage was performed automatically. A maintainer will review shortly._
```

## Configuration

Set these repository variables to customize behavior:
- `TRIAGE_DEFAULT_ASSIGNEE` — fallback assignee if no owner matched
- `TRIAGE_SKIP_LABELS` — comma-separated labels that skip auto-triage (e.g. `wontfix,duplicate`)
- `TRIAGE_POST_COMMENT` — set to `false` to disable triage comments (default: `true`)
