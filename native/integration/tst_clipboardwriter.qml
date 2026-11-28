/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../../package/contents/ui" as Local

// With the native module installed, the widget uses the public API.
TestCase {
    name: "ClipboardWriterNative"
    when: windowShown

    Local.ClipboardWriter { id: writer }
    TextEdit { id: receiver; textFormat: TextEdit.PlainText }
    TextEdit { id: sentinel; textFormat: TextEdit.PlainText; text: "previous clipboard contents" }

    function pasted() {
        receiver.clear()
        receiver.paste()
        return receiver.text
    }

    function test_publicApiCopies() {
        compare(writer.backendName, "native")
        const value = "    indented\ttext\n<b>literal</b> čćž 日本語 😀\n\n"
        verify(writer.copyText(value))
        tryVerify(function() { return receiver.canPaste })
        compare(pasted(), value)
    }

    function test_emptyTextReplacesPreviousContents() {
        sentinel.selectAll()
        sentinel.copy()
        compare(pasted(), "previous clipboard contents")
        verify(writer.copyText(""))
        compare(pasted(), "")
    }
}
