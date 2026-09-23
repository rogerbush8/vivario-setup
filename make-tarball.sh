#!/usr/bin/env bash
#
# Build the distributable tarball.
#
# Packages by NAMING what ships rather than excluding what does not, so a new
# file added to the repo cannot leak into the payload by accident. Nothing is
# staged, copied or renamed: the two entries are already laid out the way they
# extract.
#
# Usage: ./make-tarball.sh [OUTPUT_DIR]

set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$HERE/dist}
VERSION=$(cat "$HERE/vivario-internal/VERSION")
TARBALL="$OUT/vivario-setup-$VERSION.tar.gz"

# Exactly what ships. Anything not listed here is repo-only by construction.
PAYLOAD="vivario-setup vivario-internal"

for entry in $PAYLOAD; do
    if [ ! -e "$HERE/$entry" ]; then
        printf 'make-tarball: missing %s\n' "$entry" >&2
        exit 1
    fi
done

if [ ! -x "$HERE/vivario-setup" ]; then
    printf 'make-tarball: vivario-setup is not executable; the archive must carry the bit\n' >&2
    exit 1
fi

mkdir -p "$OUT"
tar czf "$TARBALL" -C "$HERE" $PAYLOAD

printf '%s\n' "$TARBALL"
printf '  %s bytes, %s entries\n' \
    "$(wc -c < "$TARBALL" | tr -d ' ')" \
    "$(tar tzf "$TARBALL" | wc -l | tr -d ' ')"
