/*
    SPDX-FileCopyrightText: 2025 Vladimir Kosolapov
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

QtObject {
    property bool processingEnabled: true

    function processVariables(text, now = new Date(), locale = Qt.locale()) {
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

        // Leave double-braced placeholders untouched for custom templates.
        return text.replace(/\{\{[^{}]*\}\}|\{[A-Z0-9_]+\}/g, function(token) {
            return replacements.hasOwnProperty(token) ? replacements[token] : token
        })
    }
}