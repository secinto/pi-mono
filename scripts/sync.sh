#!/usr/bin/env bash
#
# Sync this fork with upstream, keep GitHub Actions disabled on the fork, and
# build. Follows the "Sync workflow" section of CLAUDE.md.
#
# Usage:
#   ./scripts/sync.sh [--push] [--skip-check]
#
# Steps:
#   1. Fetch origin and upstream; fast-forward local main to origin/main
#      (stops if they diverged).
#   2. Snapshot main as backup/main-presync-YYYYMMDD.
#   3. Rebase main onto upstream/main (stops on conflict, rebase left open).
#   4. Disable every active GitHub Actions workflow on secinto/pi-mono.
#   5. npm ci, npm run hydrate:model-data, npm run build, npm run check.
#   6. With --push: git push --force-with-lease origin main.
#
# Options:
#   --push        Force-push the rebased main to origin after a green build.
#   --skip-check  Skip `npm run check` (build only).

set -euo pipefail

cd "$(dirname "$0")/.."

FORK_REPO="secinto/pi-mono"
PUSH=false
SKIP_CHECK=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --push)       PUSH=true; shift ;;
        --skip-check) SKIP_CHECK=true; shift ;;
        -h|--help)
            awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

step() { printf '\n==> %s\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }

git_dir="$(git rev-parse --git-dir)"
[[ "$(git branch --show-current)" == "main" ]] || die "not on main"
[[ ! -e "$git_dir/MERGE_HEAD" && ! -d "$git_dir/rebase-merge" && ! -d "$git_dir/rebase-apply" ]] \
    || die "a merge or rebase is in progress; finish or abort it first"
if ! git diff --quiet || ! git diff --cached --quiet; then
    die "uncommitted changes; commit or stash first"
fi
git remote get-url upstream >/dev/null 2>&1 \
    || die "remote 'upstream' missing; see CLAUDE.md"
gh auth status >/dev/null 2>&1 || die "gh is not authenticated (gh auth login)"

step "Fetching origin and upstream"
git fetch origin
git fetch upstream

if ! git merge-base --is-ancestor origin/main main; then
    if git merge-base --is-ancestor main origin/main; then
        step "Fast-forwarding main to origin/main"
        git merge --ff-only origin/main
    else
        die "main and origin/main diverged; inspect with: git range-diff upstream/main..origin/main upstream/main..main"
    fi
fi
LEASE="$(git rev-parse origin/main)"

if git merge-base --is-ancestor upstream/main main; then
    step "main already contains upstream/main; no rebase needed"
else
    backup="backup/main-presync-$(date +%Y%m%d)"
    step "Snapshot: $backup"
    git branch -f "$backup" main

    step "Rebasing main onto upstream/main"
    if ! git rebase upstream/main; then
        echo
        echo "Rebase stopped on a conflict. Resolve per CLAUDE.md (generated files: take upstream),"
        echo "then 'git rebase --continue' and re-run this script. To undo: git rebase --abort"
        exit 1
    fi
    git log --oneline upstream/main..main
fi

step "Disabling active GitHub Actions workflows on $FORK_REPO"
active="$(gh api "repos/$FORK_REPO/actions/workflows" --paginate \
    -q '.workflows[] | select(.state == "active") | .path')"
if [[ -z "$active" ]]; then
    echo "All workflows already disabled."
else
    while read -r path; do
        gh workflow disable "$(basename "$path")" -R "$FORK_REPO"
        echo "disabled $path"
    done <<< "$active"
fi

step "Installing dependencies (npm ci)"
npm ci

step "Regenerating model data"
npm run hydrate:model-data

step "Building"
npm run build

if [[ "$SKIP_CHECK" != true ]]; then
    step "Checking"
    npm run check
fi

if [[ "$(git rev-parse main)" == "$LEASE" ]]; then
    step "Done; origin/main is already up to date"
elif [[ "$PUSH" == true ]]; then
    step "Force-pushing main to origin"
    git push --force-with-lease="main:$LEASE" origin main
    step "Done"
else
    step "Done; not pushed. To publish:"
    echo "  git push --force-with-lease=main:$LEASE origin main"
fi
