/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtTest
import org.kde.kirigami.private as KirigamiPrivate

TestCase {
    name: "PlasmaClipboard"
    when: windowShown

    TextEdit {
        id: receiver
        textFormat: TextEdit.PlainText
    }

    function test_clipboard_data() {
        return [
            { tag: "plain", value: "A reusable snippet" },
            { tag: "multiline", value: "First line\nSecond line\n" },
            { tag: "literal-markup", value: "<b>literal</b> & <escape>" },
            { tag: "unicode", value: "čćž šđ — 日本語 😀" },
            { tag: "indentation", value: "    indented\ttext\n\nlast" }
        ]
    }

    function test_clipboard(data) {
        receiver.clear()
        KirigamiPrivate.CopyHelperPrivate.copyTextToClipboard(data.value)
        tryVerify(function() { return receiver.canPaste })
        receiver.paste()
        compare(receiver.text, data.value)
    }
}
