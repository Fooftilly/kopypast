#!/usr/bin/env bash
set -euo pipefail

scratch=$(mktemp -d)
writer=""
reader=""
cleanup() {
    for pid in "$reader" "$writer"; do
        if [[ -n "$pid" ]]; then
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
        fi
    done
    cat "$scratch/writer.log" "$scratch/reader.log" 2>/dev/null || true
    rm -rf "$scratch"
}
trap cleanup EXIT

wait_marker() {
    local pid=$1 log=$2 marker=$3 input=$4
    for attempt in {1..30}; do
        if grep -Fq "$marker" "$log"; then
            return 0
        fi
        kill -0 "$pid"
        if [[ "$input" == yes ]]; then
            # The nested compositor has a 1280x800 output. Send a real
            # pointer event, not a synthetic event inside the Qt client.
            DISPLAY="$KOPYPAST_TEST_OUTPUT_DISPLAY" xdotool mousemove 640 400 click 1
        fi
        sleep 1
    done
    echo "Missing clipboard peer marker: $marker"
    return 1
}

runner=/usr/lib/qt6/bin/qmltestrunner
"$runner" -input integration/clipboard-peer/Writer.qml >"$scratch/writer.log" 2>&1 &
writer=$!
if [[ "$QT_QPA_PLATFORM" == wayland ]]; then
    wait_marker "$writer" "$scratch/writer.log" KOPYPAST_PEER_WRITER_WAITING no
    wait_marker "$writer" "$scratch/writer.log" KOPYPAST_PEER_READY yes
else
    wait_marker "$writer" "$scratch/writer.log" KOPYPAST_PEER_READY no
fi

timeout 30 "$runner" -input integration/clipboard-peer/Reader.qml >"$scratch/reader.log" 2>&1 &
reader=$!
if [[ "$QT_QPA_PLATFORM" == wayland ]]; then
    wait_marker "$reader" "$scratch/reader.log" KOPYPAST_PEER_READER_WAITING no
    wait_marker "$reader" "$scratch/reader.log" KOPYPAST_PEER_READER_CLICKED yes
fi
wait "$reader"
reader=""
kill -0 "$writer"
