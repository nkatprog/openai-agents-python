#!/usr/bin/env bash
# Release Notes Generation Script
# Generates structured release notes from git history and changelog entries

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
CHANGELOG_FILE="${REPO_ROOT}/CHANGELOG.md"
OUTPUT_FILE="${REPO_ROOT}/RELEASE_NOTES.md"

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()  { echo "[release-notes] $*"; }
error() { echo "[release-notes] ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || error "Required command not found: $1"
}

# ─── Validate environment ─────────────────────────────────────────────────────
require_cmd git
require_cmd grep
require_cmd sed
require_cmd awk

cd "${REPO_ROOT}"

# ─── Determine version ────────────────────────────────────────────────────────
VERSION="${RELEASE_VERSION:-}"
if [[ -z "${VERSION}" ]]; then
  # Try to read from pyproject.toml
  if [[ -f pyproject.toml ]]; then
    VERSION=$(grep -E '^version\s*=' pyproject.toml | head -1 | sed 's/.*=\s*"\(.*\)"/\1/')
  fi
fi

if [[ -z "${VERSION}" ]]; then
  # Fall back to latest git tag
  VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "unreleased")
fi

log "Generating release notes for version: ${VERSION}"

# ─── Determine commit range ───────────────────────────────────────────────────
PREV_TAG=$(git tag --sort=-version:refname | grep -v "^v\?${VERSION}$" | head -1 || true)
if [[ -z "${PREV_TAG}" ]]; then
  COMMIT_RANGE="HEAD"
  log "No previous tag found; using full history"
else
  COMMIT_RANGE="${PREV_TAG}..HEAD"
  log "Commit range: ${COMMIT_RANGE}"
fi

# ─── Collect categorised commits ──────────────────────────────────────────────
declare -a BREAKING=() FEATURES=() FIXES=() DOCS=() CHORES=()

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  case "$line" in
    *"BREAKING CHANGE"*|*"!:"*)  BREAKING+=("$line") ;;
    feat*|"feat("*)              FEATURES+=("$line") ;;
    fix*|"fix("*)                FIXES+=("$line") ;;
    docs*|"docs("*)              DOCS+=("$line") ;;
    *)                           CHORES+=("$line") ;;
  esac
done < <(git log "${COMMIT_RANGE}" --pretty=format:"%s" 2>/dev/null)

# ─── Extract changelog section for this version ───────────────────────────────
CHANGELOG_SECTION=""
if [[ -f "${CHANGELOG_FILE}" ]]; then
  CHANGELOG_SECTION=$(
    awk "/^## \[?${VERSION}\]?/,/^## \[?[0-9]/ { if (/^## \[?[0-9]/ && !/^## \[?${VERSION}\]?/) exit; print }" \
      "${CHANGELOG_FILE}" | tail -n +2
  )
fi

# ─── Write release notes ──────────────────────────────────────────────────────
DATE=$(date +%Y-%m-%d)

{
  echo "# Release Notes — v${VERSION} (${DATE})"
  echo ""

  if [[ -n "${CHANGELOG_SECTION}" ]]; then
    echo "${CHANGELOG_SECTION}"
    echo ""
  else
    # Build from git commits when no changelog section exists
    if [[ ${#BREAKING[@]} -gt 0 ]]; then
      echo "## ⚠️ Breaking Changes"
      for entry in "${BREAKING[@]}"; do echo "- ${entry}"; done
      echo ""
    fi

    if [[ ${#FEATURES[@]} -gt 0 ]]; then
      echo "## ✨ New Features"
      for entry in "${FEATURES[@]}"; do echo "- ${entry}"; done
      echo ""
    fi

    if [[ ${#FIXES[@]} -gt 0 ]]; then
      echo "## 🐛 Bug Fixes"
      for entry in "${FIXES[@]}"; do echo "- ${entry}"; done
      echo ""
    fi

    if [[ ${#DOCS[@]} -gt 0 ]]; then
      echo "## 📚 Documentation"
      for entry in "${DOCS[@]}"; do echo "- ${entry}"; done
      echo ""
    fi

    if [[ ${#CHORES[@]} -gt 0 ]]; then
      echo "## 🔧 Maintenance"
      for entry in "${CHORES[@]}"; do echo "- ${entry}"; done
      echo ""
    fi
  fi

  # Contributor list
  echo "## 👥 Contributors"
  git log "${COMMIT_RANGE}" --pretty=format:"%aN" 2>/dev/null \
    | sort -u \
    | while IFS= read -r name; do echo "- ${name}"; done
  echo ""

  # Full diff link placeholder
  REPO_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's/git@github\.com:/https:\/\/github.com\//' || true)
  if [[ -n "${REPO_URL}" && -n "${PREV_TAG}" ]]; then
    echo "**Full diff:** [${PREV_TAG}...v${VERSION}](${REPO_URL}/compare/${PREV_TAG}...v${VERSION})"
  fi
} > "${OUTPUT_FILE}"

log "Release notes written to: ${OUTPUT_FILE}"
cat "${OUTPUT_FILE}"
