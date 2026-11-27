/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "VariableHandler"
    Local.VariableHandler { id: handler }

    function init() {
        handler.processingEnabled = true
    }

    function test_allTokens() {
        const now = new Date(2026, 10, 27, 13, 5, 9)
        const locale = Qt.locale("en_US")
        const input = "{DATE}|{TIME}|{DATETIME}|{ISO_DATE}|{ISO_TIME}|{ISO_TIME_DASHED}|{ISO_DATETIME}|{YEAR}|{MONTH}|{DAY}|{HOUR}|{HOUR12}|{MINUTE}|{SECOND}|{AMPM}"
        const expected = [
            now.toLocaleDateString(locale, Locale.ShortFormat),
            now.toLocaleTimeString(locale, Locale.ShortFormat),
            now.toLocaleString(locale, Locale.ShortFormat),
            "2026-11-27", "13:05:09", "13-05-09", "2026-11-27 13:05:09",
            "2026", "11", "27", "13", "01", "05", "09", Qt.formatTime(now, "AP")
        ].join("|")
        compare(handler.processVariables(input, now, locale), expected)
    }

    function test_locales() {
        const now = new Date(2026, 10, 27, 13, 5, 9)
        const en = Qt.locale("en_US")
        const de = Qt.locale("de_DE")
        compare(handler.processVariables("{DATE}", now, en), now.toLocaleDateString(en, Locale.ShortFormat))
        compare(handler.processVariables("{DATE}", now, de), now.toLocaleDateString(de, Locale.ShortFormat))
        verify(handler.processVariables("{DATE}", now, en) !== handler.processVariables("{DATE}", now, de))
    }

    function test_namedPlaceholders() {
        const now = new Date(2026, 0, 2)
        const text = "{{PROJECT}} {{PR_NUMBER}} {{PROJECT}} {ISO_DATE} {{bad}} \\{{LITERAL}} \\{DATE}"
        compare(handler.placeholderNames(text), ["PROJECT", "PR_NUMBER"])
        const values = {PROJECT: "α $& {YEAR} {{OTHER}}", PR_NUMBER: "37"}
        compare(handler.processVariables(text, now, Qt.locale("en_US"), values),
                "α $& {YEAR} {{OTHER}} 37 α $& {YEAR} {{OTHER}} 2026-01-02 {{bad}} {{LITERAL}} {DATE}")
        compare(handler.processVariables("{{EMPTY}}", now, Qt.locale(), {EMPTY: ""}), "")
        compare(handler.processVariables("{{MISSING}}", now), "{{MISSING}}")
        handler.processingEnabled = false
        compare(handler.placeholderNames(text), [])
        compare(handler.processVariables(text, now, Qt.locale(), values), text)
    }

    function test_literalAndRepeatedTokens() {
        const now = new Date(2026, 0, 2, 0, 0, 0)
        const input = "  <b>{ISO_DATE}</b>\n{ISO_DATE}\t{UNKNOWN} {{DATE}} {{PROJECT}} $1 čćž"
        compare(handler.processVariables(input, now), "  <b>2026-01-02</b>\n2026-01-02\t{UNKNOWN} {{DATE}} {{PROJECT}} $1 čćž")
        compare(handler.processVariables("{HOUR12}", now), "12")
        compare(handler.processVariables("{HOUR12}", new Date(2026, 0, 2, 12)), "12")
        handler.processingEnabled = false
        compare(handler.processVariables(input, now), input)
    }
}
