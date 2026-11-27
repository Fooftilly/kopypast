#!/usr/bin/env bash
set -euo pipefail

scratch=$(mktemp -d)
writer=""
cleanup() {
    if [[ -n "$writer" ]]; then
        kill "$writer" 2>/dev/null || true
        wait "$writer" 2>/dev/null || true
    fi
    cat "$scratch/writer.log" 2>/dev/null || true
    rm -rf "$scratch"
}
trap cleanup EXIT

runner=/usr/lib/qt6/bin/qmltestrunner
"$runner" -input integration/clipboard-peer/Writer.qml >"$scratch/writer.log" 2>&1 &
writer=$!
for attempt in {1..30}; do
    kill -0 "$writer"
    if grep -Fq 'KOPYPAST_PEER_READY' "$scratch/writer.log"; then
        break
    fi
    sleep 1
done
grep -Fq 'KOPYPAST_PEER_READY' "$scratch/writer.log"
timeout 30 "$runner" -input integration/clipboard-peer/Reader.qml
kill -0 "$writer"
