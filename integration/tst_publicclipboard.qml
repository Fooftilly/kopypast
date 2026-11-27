/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtTest

TestCase {
    id: tests
    name: "PublicClipboardCandidate"
    when: windowShown

    Component {
        id: sourceComponent
        TextEdit {
            textFormat: TextEdit.PlainText
            visible: false
        }
    }

    TextEdit {
        id: receiver
        textFormat: TextEdit.PlainText
    }

    function test_copyAfterSourceDestruction_data() {
        return [
            {tag: "plain", value: "A reusable snippet"},
            {tag: "multiline", value: "First line\nSecond line\n"},
            {tag: "literal-markup", value: "<b>literal</b> & <escape>"},
            {tag: "unicode", value: "čćž šđ — 日本語 😀"},
            {tag: "indentation", value: "    indented\ttext\n\nlast"}
        ]
    }

    function test_copyAfterSourceDestruction(data) {
        const source = sourceComponent.createObject(tests)
        verify(source !== null)
        // Seed a different value so stale clipboard content cannot pass.
        source.text = "sentinel: " + data.tag
        source.selectAll()
        source.copy()
        source.deselect()
        source.text = data.value
        source.selectAll()
        source.copy()
        source.deselect()
        source.clear()
        source.destroy()
        // The QML object is disposed at the end of this event-loop turn.
        wait(0)
        receiver.clear()
        tryVerify(function() { return receiver.canPaste })
        receiver.paste()
        compare(receiver.text, data.value)
    }
}
