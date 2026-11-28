/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick

// Copies text with the public QClipboard API from the optional native module
// when it is installed. Otherwise it uses Kirigami's private copy helper,
// which the widget has always used. Both are loaded at runtime, so neither
// missing module prevents the widget from loading.
QtObject {
    id: writer

    // Objects with copyText(text) returning true on success. Owners and
    // tests may supply them; otherwise they are created on first use.
    property var preferred: null
    property var fallback: null
    property bool loaded: false
    readonly property string backendName: preferred !== null ? "native"
        : fallback !== null ? "kirigami-private" : ""

    function createOptional(source, name) {
        try {
            return Qt.createQmlObject(source, writer, name)
        } catch (error) {
            return null
        }
    }

    function load() {
        if (loaded)
            return
        loaded = true
        if (preferred === null)
            preferred = createOptional(
                "import io.github.fooftilly.kopypast.fileio 1.0; Clipboard {}",
                "OptionalPublicClipboard")
        if (preferred === null && fallback === null)
            fallback = createOptional(
                "import QtQml; import org.kde.kirigami.private as P; QtObject {"
                + " function copyText(text) { P.CopyHelperPrivate.copyTextToClipboard(text); return true } }",
                "KirigamiClipboard")
    }

    // Returns false when no clipboard helper is available or the copy fails.
    function copyText(text) {
        load()
        if (preferred !== null)
            return preferred.copyText(text) === true
        if (fallback !== null)
            return fallback.copyText(text) === true
        return false
    }

    Component.onCompleted: load()
}
