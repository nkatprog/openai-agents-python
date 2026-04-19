#!/bin/bash
# Dependency Update Skill
# Checks for outdated dependencies and creates update PRs

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
BRANCH_PREFIX="deps/update"
COMMIT_PREFIX="chore(deps): update"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Helpers ──────────────────────────────────────────────────────────────────
check_requirements() {
    local missing=()
    for cmd in python3 pip git; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing[*]}"
        exit 1
    fi
    log_success "All required tools present"
}

get_current_branch() {
    git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD
}

# ── Outdated detection ────────────────────────────────────────────────────────
check_outdated_pip() {
    log_info "Checking for outdated pip packages..."
    cd "$REPO_ROOT"

    # Collect outdated packages as JSON
    OUTDATED=$(pip list --outdated --format=json 2>/dev/null || echo '[]')
    COUNT=$(echo "$OUTDATED" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

    if [[ "$COUNT" -eq 0 ]]; then
        log_success "All pip packages are up to date"
        return 0
    fi

    log_warn "Found $COUNT outdated package(s):"
    echo "$OUTDATED" | python3 -c "
import sys, json
for p in json.load(sys.stdin):
    print(f\"  {p['name']}: {p['version']} -> {p['latest_version']}\")
"
    echo "$OUTDATED"
}

# ── Update logic ──────────────────────────────────────────────────────────────
update_pyproject_deps() {
    local package="$1"
    local new_version="$2"
    local pyproject="$REPO_ROOT/pyproject.toml"

    if [[ ! -f "$pyproject" ]]; then
        log_warn "pyproject.toml not found, skipping $package"
        return 1
    fi

    # Update version constraint — replaces patterns like `package>=x.y` or `package==x.y`
    if grep -qiE "${package}[[:space:]]*[><=!~]" "$pyproject"; then
        sed -i.bak -E \
            "s|(${package}[[:space:]]*[><=!~]+[[:space:]]*)[0-9]+[0-9.]*|\1${new_version}|Ig" \
            "$pyproject" && rm -f "${pyproject}.bak"
        log_success "Updated $package to $new_version in pyproject.toml"
        return 0
    fi
    log_warn "$package not found as a direct dependency in pyproject.toml"
    return 1
}

create_update_branch() {
    local package="$1"
    local new_version="$2"
    local base_branch
    base_branch=$(get_current_branch)
    local branch_name="${BRANCH_PREFIX}-${package}-${new_version}"

    log_info "Creating branch: $branch_name"
    git -C "$REPO_ROOT" checkout -b "$branch_name" 2>/dev/null || {
        log_warn "Branch $branch_name already exists, checking it out"
        git -C "$REPO_ROOT" checkout "$branch_name"
    }

    if update_pyproject_deps "$package" "$new_version"; then
        git -C "$REPO_ROOT" add pyproject.toml
        git -C "$REPO_ROOT" commit -m "${COMMIT_PREFIX} ${package} to ${new_version}"
        log_success "Committed update for $package"
    fi

    git -C "$REPO_ROOT" checkout "$base_branch"
    echo "$branch_name"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    log_info "Starting dependency update check for openai-agents-python"
    check_requirements

    OUTDATED_JSON=$(check_outdated_pip)
    if [[ -z "$OUTDATED_JSON" || "$OUTDATED_JSON" == '[]' ]]; then
        log_success "Nothing to update. Exiting."
        exit 0
    fi

    # Iterate over outdated packages and create per-package branches
    BRANCHES=()
    while IFS= read -r line; do
        pkg=$(echo "$line" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d['name'])")
        ver=$(echo "$line" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d['latest_version'])")
        branch=$(create_update_branch "$pkg" "$ver") && BRANCHES+=("$branch")
    done < <(echo "$OUTDATED_JSON" | python3 -c "
import sys, json
for p in json.load(sys.stdin): print(json.dumps(p))
")

    echo ""
    log_success "Dependency update branches created:"
    for b in "${BRANCHES[@]}"; do
        echo "  - $b"
    done
    echo ""
    log_info "Open PRs for each branch to complete the update process."
}

main "$@"
