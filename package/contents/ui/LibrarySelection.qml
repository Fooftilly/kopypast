/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick

// Checks an explicit create or join request before a widget selects a
// shared library. It never changes the widget's own snippets.
Item {
    id: selection
    visible: false

    // Optional native SharedLibrary instance; null when not installed.
    property var backend: null
    // Validated local records copied into a newly created library.
    property var localRecords: []
    property bool localRecordsValid: true
    // Last failure: a session status, "invalid-local" or empty.
    property string errorStatus: ""
    signal selectionRequested(string name)

    SnippetModel { id: probeStore }
    SharedLibrarySession {
        id: probe
        store: probeStore
        backend: selection.backend
    }

    function finish(success, name) {
        errorStatus = success ? "" : probe.status
        probe.closeLibrary()
        if (success)
            selectionRequested(name)
        return success
    }

    // Create a new library file from a copy of the local snippets. An
    // existing library is never replaced.
    function createLibrary(name) {
        if (!localRecordsValid) {
            errorStatus = "invalid-local"
            return false
        }
        return finish(probe.createLibrary(name, localRecords), name)
    }

    // Join only an existing library whose records pass full validation.
    function joinLibrary(name) {
        return finish(probe.openLibrary(name), name)
    }

    function leaveLibrary() {
        errorStatus = ""
        selectionRequested("")
    }
}
