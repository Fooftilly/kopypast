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
        name: "ClipboardPeerReader"
        when: windowShown

        TextEdit {
            id: receiver
            textFormat: TextEdit.PlainText
        }

        function test_externalSelection() {
            if (Qt.platform.pluginName.startsWith("wayland")) {
                root.Window.window.showFullScreen()
                tryVerify(function() {
                    return root.Window.window.visibility === Window.FullScreen
                        && root.Window.window.width >= 1000
                }, 10000)
                root.width = root.Window.window.width
                root.height = root.Window.window.height
                console.warn("KOPYPAST_PEER_READER_WAITING")
                tryCompare(root, "clicked", true, 15000)
                verify(root.Window.window.active)
                console.warn("KOPYPAST_PEER_READER_CLICKED")
            }
            const expected = "    Kopypast cross-process clipboard\n<b>literal</b>\tčćž 日本語 😀\n\n"
            tryVerify(function() {
                receiver.clear()
                if (!receiver.canPaste)
                    return false
                receiver.paste()
                return receiver.text === expected
            }, 10000)
            compare(receiver.text, expected)
        }
    }
}
