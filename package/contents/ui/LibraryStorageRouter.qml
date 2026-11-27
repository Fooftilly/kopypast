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
    // A backend holds one watch. Give each router its own backend; if another
    // owner replaces the watch, this router reports watching=false instead
    // of claiming synchronization it no longer receives.
    readonly property bool watching: watchState.owned && shared && backend !== null
        && backend.watchedLibrary === selectedLibrary

    Connections {
        target: router.backend
        ignoreUnknownSignals: true
        function onSnapshotChanged(name) {
            // Never auto-resolve a failed commit or corrupt snapshot.
            if (router.shared && router.watching && name === router.selectedLibrary && session.writable)
                session.refresh()
        }
    }

    QtObject {
        id: watchState
        property bool owned: false
    }

    function startWatching() {
        watchState.owned = shared && backend !== null
            && typeof backend.watchLibrary === "function"
            && backend.watchLibrary(selectedLibrary)
    }

    function stopWatching() {
        // Leave a watch that another owner has since replaced untouched.
        if (watching && typeof backend.stopWatching === "function")
            backend.stopWatching()
        watchState.owned = false
    }

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
        stopWatching()
        if (selectedLibrary !== name)
            session.closeLibrary()
        selection.name = name
        const opened = session.openLibrary(name)
        if (opened)
            startWatching()
        return opened
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
        startWatching()
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
        startWatching()
        return true
    }

    function leaveLibrary() {
        stopWatching()
        selection.name = ""
        session.closeLibrary()
    }

    function refresh() {
        if (!shared)
            return false
        const refreshed = session.refresh()
        // Reattach even after a failed read, so a removed directory reports
        // watching=false and a restored file is noticed again.
        startWatching()
        return refreshed
    }
}
