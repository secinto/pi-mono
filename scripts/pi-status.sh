#!/usr/bin/env bash
#
# Report which `pi` binary is in use and whether it resolves to this repo's
# local build. Also flags when the local dist/ is older than src/.
#
# Usage:
#   ./scripts/pi-status.sh

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT_DIR="$(pwd)"
EXPECTED_CLI="${ROOT_DIR}/packages/coding-agent/dist/cli.js"

PI_BIN="$(command -v pi || true)"

if [[ -z "$PI_BIN" ]]; then
    echo "pi: not found on PATH"
    echo "Run: ./scripts/build-pi-local.sh"
    exit 1
fi

RESOLVED="$(readlink -f "$PI_BIN" 2>/dev/null || echo "$PI_BIN")"

echo "pi on PATH : $PI_BIN"
echo "resolves to: $RESOLVED"

if [[ "$RESOLVED" == "$EXPECTED_CLI" ]]; then
    echo "source     : LOCAL build (this repo)"
else
    echo "source     : NOT this repo's local build"
    echo "expected   : $EXPECTED_CLI"
    echo "Run: ./scripts/build-pi-local.sh"
fi

if [[ -f "$EXPECTED_CLI" ]]; then
    VERSION="$(node -e "console.log(require('${ROOT_DIR}/packages/coding-agent/package.json').version)" 2>/dev/null || echo "?")"
    BUILT_AT="$(date -r "$EXPECTED_CLI" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || stat -c '%y' "$EXPECTED_CLI" 2>/dev/null || echo "?")"
    echo "version    : $VERSION"
    echo "built at   : $BUILT_AT"

    SRC_DIR="${ROOT_DIR}/packages/coding-agent/src"
    if [[ -d "$SRC_DIR" ]]; then
        NEWEST_SRC="$(find "$SRC_DIR" -type f \( -name '*.ts' -o -name '*.tsx' \) -printf '%T@\n' 2>/dev/null | sort -nr | head -1)"
        DIST_MTIME="$(stat -c '%Y' "$EXPECTED_CLI" 2>/dev/null || echo 0)"
        if [[ -n "$NEWEST_SRC" ]] && awk -v s="$NEWEST_SRC" -v d="$DIST_MTIME" 'BEGIN{exit !(s>d)}'; then
            echo "warning    : src files are newer than dist/cli.js -- rebuild needed"
        fi
    fi
else
    echo "warning    : ${EXPECTED_CLI} does not exist -- nothing built yet"
fi
