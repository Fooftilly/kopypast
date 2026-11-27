/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick

QtObject {
    function escapeText(value) {
        return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    function escapePattern(word) {
        return word.split("").map(function(character) {
            return "\\^$.*+?()[]{}|".includes(character) ? "\\" + character : character
        }).join("")
    }

    function highlight(value, query) {
        var search = query.trim().normalize("NFC")
        if (!search)
            return { text: value, highlighted: false }

        var display = value.normalize("NFC")
        var words = Array.from(new Set(search.split(/\s+/)))
        // Match longer words first at a shared start position.
        words.sort(function(a, b) { return b.length - a.length })
        var pattern
        try {
            pattern = new RegExp(words.map(escapePattern).join("|"), "gi")
        } catch (error) {
            return { text: value, highlighted: false }
        }

        var match
        var end = 0
        var parts = []
        while ((match = pattern.exec(display)) !== null) {
            parts.push(escapeText(display.slice(end, match.index)))
            parts.push("<b>" + escapeText(match[0]) + "</b>")
            end = match.index + match[0].length
        }
        if (parts.length === 0)
            return { text: value, highlighted: false }

        parts.push(escapeText(display.slice(end)))
        // Only generated bold tags may reach the styled-text renderer.
        return { text: parts.join(""), highlighted: true }
    }
}
