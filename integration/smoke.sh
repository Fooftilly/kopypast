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

# Add completion probes only to the disposable installed copy. Import tracing
# is not reliable evidence of successful component creation.
main="$installed/contents/ui/main.qml"
sed -i '/^    id: root$/a\    Component.onCompleted: console.warn("KOPYPAST_SMOKE_ROOT_READY")' "$main"
sed -i '/^    fullRepresentation: ColumnLayout {$/a\        Component.onCompleted: console.warn("KOPYPAST_SMOKE_CONTENT_READY")' "$main"
grep -Fq 'Component.onCompleted: console.warn("KOPYPAST_SMOKE_ROOT_READY")' "$main"
grep -Fq 'Component.onCompleted: console.warn("KOPYPAST_SMOKE_CONTENT_READY")' "$main"

# Qt built with journald support may send logs to a journal that is absent
# in the container. Force all diagnostics into the captured stderr stream.
export QT_FORCE_STDERR_LOGGING=1
export QT_LOGGING_RULES="*.warning=true;*.critical=true;qml.debug=true"
plasmoidviewer -a "$namespace" -f planar -l floating >"$sandbox/viewer.log" 2>&1 &
viewer=$!
timeout 30 xdotool search --sync --onlyvisible --pid "$viewer" >/dev/null

# Require successful creation of both the applet and its full representation.
for attempt in {1..30}; do
    kill -0 "$viewer"
    if grep -Fq 'KOPYPAST_SMOKE_ROOT_READY' "$sandbox/viewer.log" &&
       grep -Fq 'KOPYPAST_SMOKE_CONTENT_READY' "$sandbox/viewer.log"; then
        break
    fi
    sleep 1
done
if ! grep -Fq 'KOPYPAST_SMOKE_ROOT_READY' "$sandbox/viewer.log" ||
   ! grep -Fq 'KOPYPAST_SMOKE_CONTENT_READY' "$sandbox/viewer.log"; then
    echo "Plasma applet did not complete component creation (see viewer diagnostics below)"
    exit 1
fi
if grep -E 'QQmlComponent: Component is not ready|Error loading QML|Failed to load applet|Type .* unavailable|module ".*" is not installed|io\.github\.fooftilly\.kopypast/.*(ReferenceError|TypeError|SyntaxError|Cannot assign|Unable to assign)' "$sandbox/viewer.log"; then
    echo "Plasma widget load failed"
    exit 1
fi
echo "Installed Plasma widget loaded under Xvfb"

kill "$viewer"
wait "$viewer" || true
viewer=""

/usr/lib/qt6/bin/qmltestrunner -input integration
