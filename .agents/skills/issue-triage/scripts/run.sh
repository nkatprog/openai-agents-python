#!/bin/bash
# Issue Triage Skill - Automatically triages new GitHub issues
# Analyzes issue content, applies labels, and routes to appropriate team members

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
GITHUB_REPO="${GITHUB_REPO:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
ISSUE_NUMBER="${ISSUE_NUMBER:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"

if [[ -z "$GITHUB_REPO" || -z "$GITHUB_TOKEN" || -z "$ISSUE_NUMBER" ]]; then
  echo "ERROR: GITHUB_REPO, GITHUB_TOKEN, and ISSUE_NUMBER must be set."
  exit 1
fi

API_BASE="https://api.github.com/repos/${GITHUB_REPO}"
AUTH_HEADER="Authorization: Bearer ${GITHUB_TOKEN}"
ACCEPT_HEADER="Accept: application/vnd.github+json"

# ── Helpers ──────────────────────────────────────────────────────────────────
gh_get() {
  curl -sSf -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" "${API_BASE}${1}"
}

gh_post() {
  local endpoint="$1"
  local body="$2"
  curl -sSf -X POST -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" \
    -H "Content-Type: application/json" \
    -d "$body" "${API_BASE}${endpoint}"
}

gh_patch() {
  local endpoint="$1"
  local body="$2"
  curl -sSf -X PATCH -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" \
    -H "Content-Type: application/json" \
    -d "$body" "${API_BASE}${endpoint}"
}

# ── Fetch issue details ───────────────────────────────────────────────────────
echo "Fetching issue #${ISSUE_NUMBER}..."
ISSUE_JSON=$(gh_get "/issues/${ISSUE_NUMBER}")
ISSUE_TITLE=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['title'])")
ISSUE_BODY=$(echo "$ISSUE_JSON"  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('body','') or '')")
ISSUE_AUTHOR=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['user']['login'])")

echo "Issue: $ISSUE_TITLE (by $ISSUE_AUTHOR)"

# ── Classify with OpenAI ─────────────────────────────────────────────────────
if [[ -n "$OPENAI_API_KEY" ]]; then
  echo "Classifying issue with OpenAI..."
  PROMPT="You are a triage assistant for the openai-agents-python SDK repository.\n\nAnalyze the following GitHub issue and respond with a JSON object containing:\n- labels: array of applicable labels from [bug, enhancement, documentation, question, good first issue, help wanted, performance, security, breaking-change]\n- priority: one of [critical, high, medium, low]\n- summary: one-sentence summary of the issue\n- suggested_assignee_team: one of [core, docs, devex, security] or null\n\nIssue Title: ${ISSUE_TITLE}\nIssue Body: ${ISSUE_BODY}"

  CLASSIFICATION=$(python3 - <<EOF
import os, json, urllib.request

prompt = """${PROMPT}"""

payload = json.dumps({
    "model": "gpt-4o-mini",
    "messages": [{"role": "user", "content": prompt}],
    "response_format": {"type": "json_object"},
    "temperature": 0.2,
}).encode()

req = urllib.request.Request(
    "https://api.openai.com/v1/chat/completions",
    data=payload,
    headers={
        "Authorization": f"Bearer ${OPENAI_API_KEY}",
        "Content-Type": "application/json",
    },
)
with urllib.request.urlopen(req) as resp:
    data = json.load(resp)
print(data["choices"][0]["message"]["content"])
EOF
  )

  LABELS=$(echo "$CLASSIFICATION" | python3 -c "import sys,json; d=json.load(sys.stdin); print(' '.join(d.get('labels',[])))")
  PRIORITY=$(echo "$CLASSIFICATION" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('priority','medium'))")
  SUMMARY=$(echo "$CLASSIFICATION"  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('summary',''))")

  echo "Detected labels : $LABELS"
  echo "Priority        : $PRIORITY"
  echo "Summary         : $SUMMARY"
else
  echo "OPENAI_API_KEY not set — skipping AI classification, applying 'needs-triage' label only."
  LABELS="needs-triage"
  PRIORITY="medium"
  SUMMARY=""
fi

# ── Apply labels ─────────────────────────────────────────────────────────────
LABEL_ARRAY=$(python3 -c "
import json, sys
labels = '${LABELS}'.split()
labels.append('priority:${PRIORITY}')
print(json.dumps(labels))
")

echo "Applying labels: $LABEL_ARRAY"
gh_post "/issues/${ISSUE_NUMBER}/labels" "{\"labels\":${LABEL_ARRAY}}" > /dev/null

# ── Post triage comment ───────────────────────────────────────────────────────
if [[ -n "$SUMMARY" ]]; then
  COMMENT_BODY="Thanks for filing this issue, @${ISSUE_AUTHOR}! 🤖\n\n**Triage summary:** ${SUMMARY}\n\n**Priority:** ${PRIORITY}\n\nA maintainer will review this shortly."
else
  COMMENT_BODY="Thanks for filing this issue, @${ISSUE_AUTHOR}! 🤖 A maintainer will review and triage this shortly."
fi

COMMENT_JSON=$(python3 -c "import json; print(json.dumps({'body': '${COMMENT_BODY//\'/\'\"\'\'\"\'}'}))")
gh_post "/issues/${ISSUE_NUMBER}/comments" "$COMMENT_JSON" > /dev/null
echo "Triage comment posted."

echo "✅ Issue #${ISSUE_NUMBER} triaged successfully."
