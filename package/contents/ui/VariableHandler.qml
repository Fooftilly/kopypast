/*
    SPDX-FileCopyrightText: 2025 Vladimir Kosolapov
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

QtObject {
    property bool processingEnabled: true

    // Recognize escaped tokens first, then complete double-braced placeholders.
    function tokenPattern() {
        return /\\(?:\{\{[^{}]*\}\}|\{[A-Z0-9_]+\})|\{\{[^{}]*\}\}|\{[A-Z0-9_]+\}/g
    }

    function placeholderName(token) {
        return /^\{\{[A-Z][A-Z0-9_]*\}\}$/.test(token) ? token.slice(2, -2) : ""
    }

    function placeholderNames(text) {
        if (!processingEnabled)
            return []
        var names = []
        var seen = new Set()
        text.replace(tokenPattern(), function(token) {
            var name = placeholderName(token)
            if (name && !seen.has(name)) {
                seen.add(name)
                names.push(name)
            }
            return token
        })
        return names
    }

    function processVariables(text, now = new Date(), locale = Qt.locale(), values = {}) {
        if (!processingEnabled)
            return text

        var replacements = {
            "{DATE}"           : now.toLocaleDateString(locale, Locale.ShortFormat),
            "{TIME}"           : now.toLocaleTimeString(locale, Locale.ShortFormat),
            "{DATETIME}"       : now.toLocaleString(locale, Locale.ShortFormat),
            "{ISO_DATE}"       : Qt.formatDate(now, "yyyy-MM-dd"),
            "{ISO_TIME}"       : Qt.formatTime(now, "HH:mm:ss"),
            "{ISO_TIME_DASHED}": Qt.formatTime(now, "HH-mm-ss"),
            "{ISO_DATETIME}"   : Qt.formatDateTime(now, "yyyy-MM-dd HH:mm:ss"),
            "{YEAR}"           : Qt.formatDate(now, "yyyy"),
            "{MONTH}"          : Qt.formatDate(now, "MM"),
            "{DAY}"            : Qt.formatDate(now, "dd"),
            "{HOUR}"           : Qt.formatTime(now, "HH"),
            "{HOUR12}"         : ((now.getHours() % 12) || 12).toString().padStart(2, '0'),
            "{MINUTE}"         : Qt.formatTime(now, "mm"),
            "{SECOND}"         : Qt.formatTime(now, "ss"),
            "{AMPM}"           : Qt.formatTime(now, "AP")
        }

        // A single pass prevents user-entered text from being interpreted as a token.
        return text.replace(tokenPattern(), function(token) {
            if (token.startsWith("\\")) {
                var literal = token.slice(1)
                if (placeholderName(literal) || replacements.hasOwnProperty(literal))
                    return literal
                return token
            }
            var name = placeholderName(token)
            if (name && Object.prototype.hasOwnProperty.call(values, name))
                return String(values[name])
            return replacements.hasOwnProperty(token) ? replacements[token] : token
        })
    }
}