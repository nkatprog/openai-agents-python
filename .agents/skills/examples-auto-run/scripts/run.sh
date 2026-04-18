#!/bin/bash
# examples-auto-run skill: Discovers and runs all examples, reporting pass/fail status.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
EXAMPLES_DIR="${ROOT_DIR}/examples"
REPORT_FILE="${ROOT_DIR}/.agents/skills/examples-auto-run/report.md"
TIMEOUT=${TIMEOUT:-60}
PYTHON=${PYTHON:-python}

passed=0
failed=0
skipped=0
errors=()

log() {
  echo "[examples-auto-run] $*"
}

if [ ! -d "$EXAMPLES_DIR" ]; then
  log "ERROR: examples directory not found at $EXAMPLES_DIR"
  exit 1
fi

# Collect all example Python files
mapfile -t example_files < <(find "$EXAMPLES_DIR" -name '*.py' | sort)

if [ ${#example_files[@]} -eq 0 ]; then
  log "No example files found in $EXAMPLES_DIR"
  exit 0
fi

log "Found ${#example_files[@]} example file(s). Running with timeout=${TIMEOUT}s each."

# Initialize report
mkdir -p "$(dirname "$REPORT_FILE")"
cat > "$REPORT_FILE" << EOF
# Examples Auto-Run Report

Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')

| Example | Status | Notes |
|---------|--------|-------|
EOF

for filepath in "${example_files[@]}"; do
  rel="${filepath#$ROOT_DIR/}"

  # Skip files that require interactive input or external credentials unless mocked
  if grep -qE 'input\(|getpass\.' "$filepath" 2>/dev/null; then
    log "SKIP $rel (requires interactive input)"
    echo "| \`$rel\` | ⏭ Skipped | Requires interactive input |" >> "$REPORT_FILE"
    ((skipped++)) || true
    continue
  fi

  log "RUN  $rel"
  set +e
  output=$(cd "$ROOT_DIR" && timeout "$TIMEOUT" "$PYTHON" "$filepath" 2>&1)
  exit_code=$?
  set -e

  if [ $exit_code -eq 0 ]; then
    log "PASS $rel"
    echo "| \`$rel\` | ✅ Pass | |" >> "$REPORT_FILE"
    ((passed++)) || true
  elif [ $exit_code -eq 124 ]; then
    log "TIMEOUT $rel"
    echo "| \`$rel\` | ⏱ Timeout | Exceeded ${TIMEOUT}s |" >> "$REPORT_FILE"
    errors+=("TIMEOUT: $rel")
    ((failed++)) || true
  else
    short_err=$(echo "$output" | tail -3 | tr '\n' ' ' | cut -c1-120)
    log "FAIL $rel — $short_err"
    echo "| \`$rel\` | ❌ Fail | \`${short_err}\` |" >> "$REPORT_FILE"
    errors+=("FAIL: $rel")
    ((failed++)) || true
  fi
done

# Summary
cat >> "$REPORT_FILE" << EOF

## Summary

- **Passed:** $passed
- **Failed:** $failed
- **Skipped:** $skipped
- **Total:** ${#example_files[@]}
EOF

log "---"
log "Results: $passed passed, $failed failed, $skipped skipped out of ${#example_files[@]} examples."
log "Report written to $REPORT_FILE"

if [ ${#errors[@]} -gt 0 ]; then
  log "Failures:"
  for e in "${errors[@]}"; do
    log "  - $e"
  done
  exit 1
fi

exit 0
