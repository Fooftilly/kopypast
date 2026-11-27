#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
peer=$(realpath "$1")
scratch=$(mktemp -d)
writer=""
reader=""
compositor=""
cleanup() {
    for pid in "$reader" "$writer" "$compositor"; do
        if [[ -n "$pid" ]]; then
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
        fi
    done
    cat "$scratch"/*.log 2>/dev/null || true
    rm -rf "$scratch"
}
trap cleanup EXIT
export XDG_RUNTIME_DIR="$scratch/runtime"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
case "$QT_QPA_PLATFORM" in
    xcb)
        export XDG_SESSION_TYPE=x11
        ;;
    wayland)
        export XDG_SESSION_TYPE=wayland
        export WAYLAND_DISPLAY=kopypast-native-clipboard
        weston --backend=x11 --renderer=pixman --socket="$WAYLAND_DISPLAY" \
            --width=1280 --height=800 --idle-time=0 --no-config >"$scratch/weston.log" 2>&1 &
        compositor=$!
        for attempt in {1..30}; do
            kill -0 "$compositor"
            [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]] && break
            sleep 1
        done
        test -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
        output_display="$DISPLAY"
        unset DISPLAY
        ;;
    *) exit 2 ;;
esac

wait_marker() {
    local pid=$1 log=$2 marker=$3 input=$4
    for attempt in {1..30}; do
        if grep -Fq "$marker" "$log"; then
            return 0
        fi
        kill -0 "$pid"
        if [[ "$input" == yes ]]; then
            DISPLAY="$output_display" xdotool mousemove 640 400 click 1
        fi
        sleep 1
    done
    echo "Missing native clipboard marker: $marker"
    return 1
}

for kind in text empty; do
    "$peer" writer "$kind" >"$scratch/writer-$kind.log" 2>&1 &
    writer=$!
    if [[ "$QT_QPA_PLATFORM" == wayland ]]; then
        wait_marker "$writer" "$scratch/writer-$kind.log" KOPYPAST_NATIVE_WRITER_WAITING no
        wait_marker "$writer" "$scratch/writer-$kind.log" KOPYPAST_NATIVE_WRITER_READY yes
    else
        wait_marker "$writer" "$scratch/writer-$kind.log" KOPYPAST_NATIVE_WRITER_READY no
    fi
    timeout 40 "$peer" reader "$kind" >"$scratch/reader-$kind.log" 2>&1 &
    reader=$!
    if [[ "$QT_QPA_PLATFORM" == wayland ]]; then
        wait_marker "$reader" "$scratch/reader-$kind.log" KOPYPAST_NATIVE_READER_WAITING no
        # Reader may finish immediately after the click, so accept the
        # ready marker even if its process has already exited.
        wait_marker "$reader" "$scratch/reader-$kind.log" KOPYPAST_NATIVE_READER_READY yes
    fi
    wait "$reader"
    reader=""
    grep -Fq KOPYPAST_NATIVE_TRANSFER_OK "$scratch/reader-$kind.log"
    kill -0 "$writer"
    kill "$writer"
    wait "$writer" || true
    writer=""
done
