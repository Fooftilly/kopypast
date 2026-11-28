/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Controls
import QtTest
import "../package/contents/ui" as Local

// A panel popup window of 368 x 512 whose applet content is inset by 4
// pixels, as measured in a Plasma panel popup with the org.kde.desktop
// style, which gives dialogs 18 pixel window margins.
Item {
    id: fixture
    width: 368
    height: 512

    function i18n(text) { return text }

    Item {
        id: popupContent
        x: 4
        y: 4
        width: 360
        height: 504
    }

    Local.SnippetModel { id: store }

    Local.SnippetDialog {
        id: editor
        parent: popupContent
        margins: 18
        preferredWidth: Math.min(parent.width, 504)
        preferredHeight: Math.min(parent.height, 540)
        store: store
        maximumSnippets: 10
    }

    Local.FittedDialog {
        id: plain
        parent: popupContent
        preferredWidth: 600
        title: "Plain"
        standardButtons: Dialog.Ok | Dialog.Cancel
        contentItem: Label { text: "Body"; wrapMode: Text.Wrap }
    }

    TestCase {
        name: "FittedDialog"
        when: windowShown

        function verifyInsideWindow(item, margin, what) {
            const p = item.mapToItem(null, 0, 0)
            verify(item.width > 0 && item.height > 0, what + " has a size")
            verify(p.x >= margin && p.y >= margin, what + " starts inside the window margins")
            verify(p.x + item.width <= fixture.width - margin + 0.5
                   && p.y + item.height <= fixture.height - margin + 0.5,
                   what + " ends inside the window margins: " + p.x + "," + p.y + " "
                   + item.width + "x" + item.height)
        }

        function test_editorFitsInsideStyleMargins() {
            editor.createSnippet()
            tryCompare(editor, "opened", true)
            waitForItemPolished(editor.footer)
            verifyInsideWindow(editor.background, 18, "editor")
            verifyInsideWindow(findChild(editor.footer, "saveSnippetButton"), 18, "Save button")
            const buttons = editor.footer.contentChildren
            verify(buttons.length >= 2)
            for (let i = 0; i < buttons.length; ++i)
                verifyInsideWindow(buttons[i], 18, "footer button " + i)
            editor.reject()
            tryCompare(editor, "visible", false)
        }

        function test_wideDialogShrinksToWindow() {
            plain.open()
            tryCompare(plain, "opened", true)
            const margin = Math.max(0, plain.leftMargin)
            verifyInsideWindow(plain.background, margin, "dialog")
            compare(plain.width, fixture.width - Math.max(0, plain.leftMargin) - Math.max(0, plain.rightMargin))
            plain.reject()
            tryCompare(plain, "visible", false)
        }

        function test_smallDialogKeepsPreferredWidth() {
            plain.preferredWidth = 200
            plain.open()
            tryCompare(plain, "opened", true)
            compare(plain.width, 200)
            verifyInsideWindow(plain.background, Math.max(0, plain.leftMargin), "dialog")
            plain.reject()
            tryCompare(plain, "visible", false)
            plain.preferredWidth = 600
        }
    }
}
