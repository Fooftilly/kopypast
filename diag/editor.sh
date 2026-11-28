#!/usr/bin/env bash
# Temporary diagnostic: open the editor in a panel popup and record geometry.
set -uo pipefail
root=$(pwd)
out="$root/diag-out"; mkdir -p "$out"
export XDG_RUNTIME_DIR=$(mktemp -d); chmod 700 "$XDG_RUNTIME_DIR"
export QT_FORCE_STDERR_LOGGING=1
home=$(mktemp -d)
mkdir -p "$home/data" "$home/config" "$home/cache"
XDG_DATA_HOME="$home/data" kpackagetool6 -t Plasma/Applet --install "$root/package" >/dev/null
main="$home/data/plasma/plasmoids/io.github.fooftilly.kopypast/contents/ui/main.qml"
OUT="$out" perl -0pi -e '
s/^    id: root\n/    id: root\n    Timer { running: true; interval: 1500; onTriggered: root.expanded = true }\n/m;
s/^(        Component\.onCompleted: Qt\.callLater\(focusOnOpen\)\n)/$1        Timer { running: true; interval: 2000; onTriggered: editor.createSnippet() }\n        Timer { running: true; interval: 4000; onTriggered: { const w = popupContent.Window.window; const c = w.contentItem; function g(n, it) { if (!it) { console.warn("DIAG " + n + " null"); return } const p = it.mapToItem(c, 0, 0); console.warn("DIAG " + n + " at " + p.x + "," + p.y + " size " + it.width + "x" + it.height + " implicit " + it.implicitWidth + "x" + it.implicitHeight) } console.warn("DIAG window " + w.width + "x" + w.height + " dpr " + w.devicePixelRatio + " gridUnit " + Kirigami.Units.gridUnit + " class " + w); g("content", c); g("popupContent", popupContent); g("popupParent", popupContent.parent); g("popupParent2", popupContent.parent ? popupContent.parent.parent : null); g("editorItem", editor.contentItem ? editor.contentItem.parent : null); g("editorContent", editor.contentItem); g("editorHeader", editor.header); g("editorFooter", editor.footer); g("editorBackground", editor.background); console.warn("DIAG editor x,y " + editor.x + "," + editor.y + " size " + editor.width + "x" + editor.height + " implicit " + editor.implicitWidth + "x" + editor.implicitHeight + " padding " + editor.leftPadding + "," + editor.topPadding + "," + editor.rightPadding + "," + editor.bottomPadding + " insets " + editor.leftInset + "," + editor.topInset + "," + editor.rightInset + "," + editor.bottomInset + " margins " + editor.margins + " availH " + editor.availableHeight + " clip " + editor.clip); const ch = editor.footer.contentChildren; for (let i = 0; i < ch.length; ++i) g("footerChild" + i, ch[i]); g("footerContent", editor.footer.contentItem); console.warn("DIAG footer padding " + editor.footer.leftPadding + "," + editor.footer.rightPadding + "," + editor.footer.topPadding + "," + editor.footer.bottomPadding + " style " + editor.background) } }\n/m;
' "$main"
grep -c DIAG "$main"
env | grep -E "^QT_"
XDG_DATA_HOME="$home/data" XDG_CONFIG_HOME="$home/config" XDG_CACHE_HOME="$home/cache" \
    plasmoidviewer -a io.github.fooftilly.kopypast -f horizontal -l bottomedge >"$out/viewer.log" 2>&1 &
viewer=$!
status=1
for _ in $(seq 1 60); do
    if grep -q "DIAG footer padding" "$out/viewer.log"; then
        import -window root "$out/root.png" && status=0
        break
    fi
    kill -0 "$viewer" 2>/dev/null || break
    sleep 0.5
done
kill "$viewer" 2>/dev/null; wait "$viewer" 2>/dev/null
grep -E "DIAG|qml:|Error|error|style|Style" "$out/viewer.log" | head -80
ls -la "$out"
[[ $status == 0 && -s "$out/root.png" ]] || { echo "Missing editor geometry marker or screenshot"; exit 1; }
