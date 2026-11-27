/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick

Item {
    id: router
    visible: false

    // An owner supplies the optional native backend. The two models never
    // share a persistence target, including when a shared file is missing.
    property var backend: null
    property alias localConfig: localStore.configValue
    readonly property string selectedLibrary: selection.name
    readonly property bool shared: selectedLibrary !== ""
    readonly property var activeStore: shared ? sharedStore : localStore
    readonly property bool available: backend !== null
    readonly property bool writable: shared
        ? session.writable && sharedStore.configurationValid
        : localStore.configurationValid
    readonly property string status: session.status
    readonly property string recoveryText: session.recoveryText

    QtObject {
        id: selection
        property string name: ""
    }

    SnippetModel {
        id: localStore
    }

    SnippetModel {
        id: sharedStore
        beforeCommit: function(records) {
            return router.shared && session.commitRecords(records)
        }
    }

    SharedLibrarySession {
        id: session
        store: sharedStore
        backend: router.backend
    }

    // Restore the saved preference, not an attempted new join. If it cannot
    // be opened, remain in shared mode with writes blocked; never fall back.
    function restoreSelection(name) {
        if (name === "") {
            leaveLibrary()
            return true
        }
        if (selectedLibrary !== name)
            session.closeLibrary()
        selection.name = name
        return session.openLibrary(name)
    }

    // Explicitly join only from local mode. Failure preserves the active
    // local model and the saved selection.
    function joinLibrary(name) {
        if (shared)
            return false
        session.closeLibrary()
        if (!session.openLibrary(name))
            return false
        selection.name = name
        return true
    }

    // Create a copy, not a migration. Local data is retained unchanged.
    function createLibrary(name) {
        if (shared || !localStore.configurationValid)
            return false
        session.closeLibrary()
        if (!session.createLibrary(name, localStore.snippets))
            return false
        selection.name = name
        return true
    }

    function leaveLibrary() {
        selection.name = ""
        session.closeLibrary()
    }

    function refresh() {
        return shared && session.refresh()
    }
}
