/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Window
import QtTest

TestCase {
    id: test
    name: "ClipboardPeerWriter"
    when: windowShown

    Component {
        id: sourceComponent
        TextEdit {
            visible: false
            textFormat: TextEdit.PlainText
            Component.onDestruction: test.sourceDestroyed = true
        }
    }

    property bool sourceDestroyed: false

    function test_holdSelection() {
        const source = sourceComponent.createObject(test)
        verify(source !== null)
        source.text = "    Kopypast cross-process clipboard\n<b>literal</b>\tčćž 日本語 😀\n\n"
        source.selectAll()
        source.copy()
        source.clear()
        source.destroy()
        tryCompare(test, "sourceDestroyed", true)
        console.warn("KOPYPAST_PEER_READY")
        // Remain alive to own the selection while the reader starts.
        // The shell terminates the writer after the reader finishes.
        wait(65000)
    }
}
