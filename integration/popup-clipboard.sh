#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copy from the real popup with the native module installed, then read the
# clipboard from an independent Qt process. Usage: popup-clipboard.sh PEER
# where PEER is the native clipboard_peer test binary and QML_IMPORT_PATH
# contains the installed io.github.fooftilly.kopypast.fileio module.
set -euo pipefail
peer=$(realpath "$1")
root=$(pwd)
sandbox=$(mktemp -d)
pids=()
compositor=""
cleanup() {
    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    done
    if [[ -n "$compositor" ]]; then
        kill "$compositor" 2>/dev/null || true
        wait "$compositor" 2>/dev/null || true
    fi
    for log in "$sandbox"/*.log; do
        [[ -f "$log" ]] && { echo "== $(basename "$log")"; cat "$log"; }
    done
    rm -rf "$sandbox"
}
trap cleanup EXIT

export XDG_RUNTIME_DIR="$sandbox/runtime"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
export QT_FORCE_STDERR_LOGGING=1
export QT_LOGGING_RULES="*.warning=true;*.critical=true;qml.debug=true"
case "$QT_QPA_PLATFORM" in
    xcb)
        export XDG_SESSION_TYPE=x11
        output_display="$DISPLAY"
        ;;
    wayland)
        export XDG_SESSION_TYPE=wayland
        export WAYLAND_DISPLAY=kopypast-popup-clipboard
        weston --backend=x11 --renderer=pixman --socket="$WAYLAND_DISPLAY" \
            --width=1280 --height=800 --idle-time=0 --no-config >"$sandbox/weston.log" 2>&1 &
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

# Real input for each step. On X11 the viewer window is not resized by a
# window manager, so the popup is driven through its keyboard path: a click
# activates the window and Return copies the selected snippet. Under Weston
# the popup fills the output, so the first snippet is clicked with the mouse
# at the position the popup reports. The peer reader only needs a click.
send_input() {
    local kind=$1 log=$2
    case "$kind" in
        peer)
            DISPLAY="$output_display" xdotool mousemove 640 400 click 1
            ;;
        popup)
            if [[ "$QT_QPA_PLATFORM" == wayland ]]; then
                local target
                target=$(grep -o 'KOPYPAST_POPUP_TARGET [0-9]* [0-9]*' "$log" | tail -n 1)
                [[ -n "$target" ]] || return 0
                set -- $target
                DISPLAY="$output_display" xdotool mousemove "$2" "$3" click 1
            else
                DISPLAY="$output_display" xdotool mousemove 640 400 click 1 sleep 0.3 key Return
            fi
            ;;
    esac
}

# Wait for a marker, sending real input of the given kind (no, peer or
# popup) each second. The process may print the marker and exit.
wait_marker() {
    local pid=$1 log=$2 marker=$3 input=$4
    for attempt in {1..40}; do
        grep -Fq "$marker" "$log" && return 0
        if ! kill -0 "$pid" 2>/dev/null; then
            grep -Fq "$marker" "$log" && return 0
            echo "Process exited before marker: $marker"
            return 1
        fi
        [[ "$input" == no ]] || send_input "$input" "$log"
        sleep 1
    done
    echo "Missing marker: $marker"
    return 1
}

namespace=$(jq -er '.KPlugin.Id' package/metadata.json)
# The seeded text equals the native peer reader's expected "text" value.
text_snippet='{"title":"Text","text":"    Kopypast native clipboard\n<b>literal</b>\tčćž 日本語 😀\n\n"}'
empty_snippet='{"title":"Empty","text":"{{EMPTY}}"}'

# Start one fullscreen viewer whose list holds 20 copies of one snippet, with
# keyboard navigation on and the first snippet selected.
start_viewer() {
    local name=$1 snippet=$2
    local home="$sandbox/$name"
    mkdir -p "$home/data" "$home/config" "$home/cache"
    XDG_DATA_HOME="$home/data" kpackagetool6 -t Plasma/Applet --install "$root/package" >/dev/null
    local main="$home/data/plasma/plasmoids/$namespace/contents/ui/main.qml"
    local seed
    seed=$(jq -cn --argjson s "$snippet" '[range(20) as $i | $s + {id: ("s" + ($i|tostring))}]')
    # Test-only probes in the disposable installed copy: seed snippets, go
    # fullscreen, report the helper and first snippet position, and press OK
    # in the template dialog (the copy still follows real input).
    SEED="$seed" perl -0pi -e '
        s/^    id: root\n/    id: root\n    Component.onCompleted: {\n        const seed = JSON.stringify($ENV{SEED});\n        if (typeof libraryRouter !== "undefined") libraryRouter.localConfig = seed; else snippetModel.loadFromConfig(seed);\n        clipboardWriter.load();\n        console.warn("KOPYPAST_POPUP_BACKEND " + clipboardWriter.backendName)\n    }\n/m;
        s/^(        Component\.onCompleted: Qt\.callLater\(focusOnOpen\)\n)/$1        Connections { target: templateDialog; function onOpened() { Qt.callLater(templateDialog.accept) } }\n        Timer { running: true; repeat: true; interval: 1000; onTriggered: { const d = snippetList.itemAtIndex(0); if (d) { const g = d.mapToGlobal(d.width \/ 2, d.height \/ 2); console.warn("KOPYPAST_POPUP_TARGET " + Math.round(g.x) + " " + Math.round(g.y)) } } }\n        Timer { running: true; interval: 500; onTriggered: { popupContent.Window.window.showFullScreen(); plasmoid.configuration.useKbdNavigation = true; snippetList.currentIndex = 0; snippetList.forceActiveFocus(); console.warn("KOPYPAST_POPUP_READY") } }\n/m;
        s/^(            snippetModel\.recordUse\(snippetId\)\n)/$1            console.warn("KOPYPAST_POPUP_COPIED")\n/m;
    ' "$main"
    grep -Fq KOPYPAST_POPUP_BACKEND "$main"
    grep -Fq KOPYPAST_POPUP_READY "$main"
    grep -Fq KOPYPAST_POPUP_COPIED "$main"
    XDG_DATA_HOME="$home/data" XDG_CONFIG_HOME="$home/config" XDG_CACHE_HOME="$home/cache" \
        plasmoidviewer -a "$namespace" -f planar -l floating >"$sandbox/viewer-$name.log" 2>&1 &
    viewer=$!
    pids+=("$viewer")
    wait_marker "$viewer" "$sandbox/viewer-$name.log" KOPYPAST_POPUP_READY no
    grep -Fq "KOPYPAST_POPUP_BACKEND native" "$sandbox/viewer-$name.log"
    sleep 2
    wait_marker "$viewer" "$sandbox/viewer-$name.log" KOPYPAST_POPUP_COPIED popup
}

read_clipboard() {
    local kind=$1
    timeout 40 "$peer" reader "$kind" >"$sandbox/reader-$kind.log" 2>&1 &
    local reader=$!
    if [[ "$QT_QPA_PLATFORM" == wayland ]]; then
        wait_marker "$reader" "$sandbox/reader-$kind.log" KOPYPAST_NATIVE_READER_WAITING no
        wait_marker "$reader" "$sandbox/reader-$kind.log" KOPYPAST_NATIVE_READER_READY peer
    fi
    wait "$reader"
    grep -Fq KOPYPAST_NATIVE_TRANSFER_OK "$sandbox/reader-$kind.log"
}

# Text copied from the popup reaches another client while the widget runs.
start_viewer text "$text_snippet"
text_viewer=$viewer
read_clipboard text
kill -0 "$text_viewer"

# An empty resolved template replaces that nonempty selection.
start_viewer empty "$empty_snippet"
read_clipboard empty
echo "Popup clipboard transfer verified with $QT_QPA_PLATFORM"
