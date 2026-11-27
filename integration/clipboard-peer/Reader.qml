/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest

TestCase {
    name: "ClipboardPeerReader"
    when: windowShown

    TextEdit {
        id: receiver
        textFormat: TextEdit.PlainText
    }

    function test_externalSelection() {
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
