#!/bin/bash
# Changelog Update Skill
# Automatically updates CHANGELOG.md based on commits since last release

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
CHANGELOG_FILE="${CHANGELOG_FILE:-PO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
CHANGELOG_PATH="${REPO_ROOT}/${CHANGELOG_FILE}"

# ── Helpers ──────────────────────────────────────────────────────────────────
log()  { echo "[changelog-update] $*"; }
err()  { echo "[changelog-update] ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || err "Required command not found: $1"
}

# ── Detect last release tag ───────────────────────────────────────────────────
get_last_tag() {
  git tag --sort=-version:refname | grep -E '^v?[0-9]+\.[0-9]+' | head -n1 || true
}

# ── Collect commits since tag ─────────────────────────────────────────────────
get_commits_since() {
  local since_tag="$1"
  if [[ -z "$since_tag" ]]; then
    git log --pretty=format:"%H %s" --no-merges
  else
    git log "${since_tag}..HEAD" --pretty=format:"%H %s" --no-merges
  fi
}

# ── Categorise a commit subject ───────────────────────────────────────────────
categorise() {
  local subject="$1"
  case "$subject" in
    feat*|feature*)   echo "Added" ;;
    fix*|bug*)        echo "Fixed" ;;
    docs*)            echo "Documentation" ;;
    refactor*)        echo "Changed" ;;
    perf*)            echo "Performance" ;;
    chore*|ci*|build*) echo "Maintenance" ;;
    revert*)          echo "Reverted" ;;
    test*)            echo "Testing" ;;
    *)                echo "Changed" ;;
  esac
}

# ── Build changelog entry ─────────────────────────────────────────────────────
build_entry() {
  local version="$1"
  local date_str
  date_str="$(date +%Y-%m-%d)"

  declare -A sections
  local order=("Added" "Fixed" "Changed" "Performance" "Documentation" "Testing" "Maintenance" "Reverted")

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local hash subject category
    hash="$(echo "$line" | cut -d' ' -f1)"
    subject="$(echo "$line" | cut -d' ' -f2-)"
    category="$(categorise "$subject")"
    local short_hash="${hash:0:7}"
    sections["$category"]+="- ${subject} (${short_hash})\n"
  done < <(get_commits_since "$(get_last_tag)")

  local entry="## [${version}] - ${date_str}\n"
  for cat in "${order[@]}"; do
    if [[ -n "${sections[$cat]:-}" ]]; then
      entry+="\n### ${cat}\n"
      entry+="${sections[$cat]}"
    fi
  done

  printf '%s' "$entry"
}

# ── Insert entry into changelog ───────────────────────────────────────────────
insert_entry() {
  local entry="$1"
  local tmp
  tmp="$(mktemp)"

  if [[ ! -f "$CHANGELOG_PATH" ]]; then
    log "Creating new ${CHANGELOG_FILE}"
    printf '# Changelog\n\nAll notable changes to this project will be documented in this file.\n\n' > "$CHANGELOG_PATH"
  fi

  # Insert after the first heading / preamble block
  awk -v entry="$entry" '
    /^## \[/ && !inserted {
      print entry
      print ""
      inserted=1
    }
    { print }
    END { if (!inserted) { print ""; print entry } }
  ' "$CHANGELOG_PATH" > "$tmp"

  mv "$tmp" "$CHANGELOG_PATH"
  log "Updated ${CHANGELOG_PATH}"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  require_cmd git

  local version="${1:-Unreleased}"

  log "Collecting commits for version: ${version}"
  local last_tag
  last_tag="$(get_last_tag)"
  if [[ -n "$last_tag" ]]; then
    log "Last release tag: ${last_tag}"
  else
    log "No previous release tag found — including all commits"
  fi

  local commit_count
  commit_count="$(get_commits_since "$last_tag" | wc -l | tr -d ' ')"
  log "Found ${commit_count} commit(s) to process"

  if [[ "$commit_count" -eq 0 ]]; then
    log "Nothing to add — changelog unchanged"
    exit 0
  fi

  local entry
  entry="$(build_entry "$version")"
  insert_entry "$entry"
  log "Done."
}

main "$@"
