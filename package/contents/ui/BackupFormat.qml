/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick

QtObject {
    readonly property string format: "io.github.fooftilly.kopypast"
    readonly property int version: 1

    function encode(snippets) {
        return JSON.stringify({
            format: format,
            version: version,
            snippets: snippets
        }, null, 2)
    }

    function decode(content) {
        var data
        try {
            data = JSON.parse(content)
        } catch (error) {
            return { status: "invalid-format" }
        }

        // Accept legacy array backups from this fork and the original widget.
        if (Array.isArray(data))
            return { status: "ok", content: content, preserveIdentity: false }
        if (!data || typeof data !== "object" || data.format !== format)
            return { status: "invalid-format" }
        if (!Number.isSafeInteger(data.version) || data.version < 1)
            return { status: "invalid-format" }
        if (data.version !== version)
            return { status: "unsupported-version" }
        if (!Array.isArray(data.snippets))
            return { status: "invalid-format" }
        // The model validates the complete record set before it mutates data.
        return { status: "ok", content: JSON.stringify(data.snippets), preserveIdentity: true }
    }
}
