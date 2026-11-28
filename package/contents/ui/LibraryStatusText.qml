/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick

// User-facing explanations for shared library session and backend states.
QtObject {
    function message(status) {
        switch (status) {
        case "ready":
        case "closed":
        case "loading":
            return ""
        case "unavailable":
            return i18n("Shared libraries need the optional native module. Install it, or stop sharing in the settings.")
        case "missing":
            return i18n("The shared library file was not found.")
        case "exists":
            return i18n("A shared library with this name already exists. Join it instead.")
        case "invalid-name":
            return i18n("Use 1–64 lowercase letters, digits, hyphens or underscores, starting with a letter or digit.")
        case "conflict":
            return i18n("Another widget changed this library first. Refresh to load the latest snippets; your change was not saved.")
        case "busy":
            return i18n("Another widget is saving this library. Try again.")
        case "invalid-format":
        case "invalid-record":
        case "invalid-utf16":
            return i18n("The shared library file is damaged. Changes are blocked; restore it from a backup.")
        case "too-large":
            return i18n("The shared library file is too large.")
        default:
            return i18n("The shared library could not be read or saved.")
        }
    }
}
