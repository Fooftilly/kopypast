/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

// Runs with Kirigami and without the optional native module, as for a
// widget installed only with kpackagetool6.
TestCase {
    name: "ClipboardWriterFallback"
    when: windowShown

    Local.ClipboardWriter { id: writer }
    TextEdit { id: receiver; textFormat: TextEdit.PlainText }

    function test_fallbackCopies_data() {
        return [
            { tag: "multiline", value: "First line\nSecond line\n" },
            { tag: "literal-markup", value: "<b>literal</b> & <escape>" },
            { tag: "unicode", value: "čćž šđ — 日本語 😀" }
        ]
    }

    function test_fallbackCopies(data) {
        compare(writer.backendName, "kirigami-private")
        receiver.clear()
        verify(writer.copyText(data.value))
        tryVerify(function() { return receiver.canPaste })
        receiver.paste()
        compare(receiver.text, data.value)
    }
}
