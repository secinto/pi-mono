#!/usr/bin/env bash
#
# Build the pi coding-agent locally and ensure the global `pi` command
# resolves to this repository's build (via `npm link`).
#
# Usage:
#   ./scripts/build-pi-local.sh [--clean] [--skip-install] [--skip-link] [--no-deps]
#
# Options:
#   --clean         Run `npm run clean` before building.
#   --skip-install  Skip `npm install --ignore-scripts`.
#   --skip-link     Skip the global npm link step.
#   --no-deps       Build only packages/coding-agent (skip tui/ai/agent).
#                   Use after a prior full build when only coding-agent src changed.
#
# Build order matches root package.json: tui -> ai -> agent -> coding-agent.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT_DIR="$(pwd)"

CLEAN=false
SKIP_INSTALL=false
SKIP_LINK=false
NO_DEPS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)        CLEAN=true; shift ;;
        --skip-install) SKIP_INSTALL=true; shift ;;
        --skip-link)    SKIP_LINK=true; shift ;;
        --no-deps)      NO_DEPS=true; shift ;;
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

if [[ "$SKIP_INSTALL" != true ]]; then
    step "Installing workspace dependencies (npm install --ignore-scripts)"
    npm install --ignore-scripts
fi

if [[ "$CLEAN" == true ]]; then
    step "Cleaning previous build output"
    npm run clean
fi

build_pkg() {
    local pkg="$1"
    step "Building packages/${pkg}"
    npm --prefix "packages/${pkg}" run build
}

if [[ "$NO_DEPS" != true ]]; then
    build_pkg tui
    build_pkg ai
    build_pkg agent
fi
build_pkg coding-agent

if [[ "$SKIP_LINK" != true ]]; then
    step "Ensuring global \`pi\` resolves to this repo via \`npm link\`"
    PI_BIN="$(command -v pi || true)"
    LINK_TARGET=""
    if [[ -n "$PI_BIN" ]]; then
        LINK_TARGET="$(readlink -f "$PI_BIN" 2>/dev/null || true)"
    fi
    EXPECTED="${ROOT_DIR}/packages/coding-agent/dist/cli.js"
    if [[ "$LINK_TARGET" != "$EXPECTED" ]]; then
        ( cd packages/coding-agent && npm link )
    else
        echo "Already linked: $PI_BIN -> $LINK_TARGET"
    fi
fi

step "Done"
"${ROOT_DIR}/scripts/pi-status.sh"
