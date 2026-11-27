/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Window
import QtTest

Item {
    id: root
    width: 640
    height: 480
    property bool clicked: false

    Rectangle {
        anchors.fill: parent
        color: "white"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked = true
    }

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
            if (Qt.platform.pluginName.startsWith("wayland")) {
                root.Window.window.showFullScreen()
                tryVerify(function() {
                    return root.Window.window.visibility === Window.FullScreen
                        && root.Window.window.width >= 1000
                }, 10000)
                root.width = root.Window.window.width
                root.height = root.Window.window.height
                console.warn("KOPYPAST_PEER_WRITER_WAITING")
                tryCompare(root, "clicked", true, 15000)
                verify(root.Window.window.active)
            }
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
}
