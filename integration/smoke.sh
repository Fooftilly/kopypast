#!/usr/bin/env bash
set -euo pipefail

# Keep all package/config changes inside a disposable test environment.
sandbox=$(mktemp -d)
viewer=""
cleanup() {
    if [[ -n "$viewer" ]]; then
        kill "$viewer" 2>/dev/null || true
        wait "$viewer" 2>/dev/null || true
    fi
    if [[ -f "$sandbox/viewer.log" ]]; then
        cat "$sandbox/viewer.log"
    fi
    rm -rf "$sandbox"
}
trap cleanup EXIT

export XDG_DATA_HOME="$sandbox/data"
export XDG_CONFIG_HOME="$sandbox/config"
export XDG_CACHE_HOME="$sandbox/cache"
export XDG_RUNTIME_DIR="$sandbox/runtime"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

namespace=$(jq -er '.KPlugin.Id' package/metadata.json)
kpackagetool6 -t Plasma/Applet --install package
installed="$XDG_DATA_HOME/plasma/plasmoids/$namespace"
test -f "$installed/contents/ui/main.qml"
test "$(jq -er '.KPlugin.Id' "$installed/metadata.json")" = "$namespace"

# The Plasma SDK must load the actual installed widget, not just parse QML.
QML_IMPORT_TRACE=1 plasmoidviewer -a "$namespace" -f planar -l floating >"$sandbox/viewer.log" 2>&1 &
viewer=$!
timeout 30 xdotool search --sync --onlyvisible --pid "$viewer" >/dev/null
# Allow component creation and bindings to run after the window is mapped.
sleep 3
kill -0 "$viewer"
grep -F "$namespace/contents/ui/main.qml" "$sandbox/viewer.log" >/dev/null
if grep -E 'QQmlComponent: Component is not ready|Error loading QML|Failed to load applet|Type .* unavailable|module ".*" is not installed|io\.github\.fooftilly\.kopypast/.*(ReferenceError|TypeError|SyntaxError|Cannot assign|Unable to assign)' "$sandbox/viewer.log"; then
    echo "Plasma widget load failed"
    exit 1
fi
echo "Installed Plasma widget loaded under Xvfb"

kill "$viewer"
wait "$viewer" || true
viewer=""

/usr/lib/qt6/bin/qmltestrunner -input integration
