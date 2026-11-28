/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    id: test
    name: "LibrarySelection"

    function i18n(text) { return text }

    Local.BackupFormat { id: codec }

    // In-memory stand-in for the optional native backend.
    QtObject {
        id: fake
        property var files: ({})
        function readSnapshot(name) {
            if (!/^[a-z0-9][a-z0-9_-]{0,63}$/.test(name))
                return {status:"invalid-name"}
            if (files[name] === undefined)
                return {status:"missing"}
            return {status:"ok", text:files[name], revision:"r-" + files[name].length}
        }
        function create(name, content) {
            if (!/^[a-z0-9][a-z0-9_-]{0,63}$/.test(name))
                return {status:"invalid-name"}
            if (files[name] !== undefined)
                return {status:"exists"}
            files[name] = content
            return {status:"ok", revision:"r-" + content.length}
        }
    }

    Local.LibrarySelection {
        id: selection
        backend: fake
        localRecords: [{id:"a", title:"Local", text:"body", category:"", tags:[]}]
    }
    Local.LibrarySelection { id: unavailable }
    Local.LibraryStatusText { id: statusText }
    SignalSpy { id: requested; target: selection; signalName: "selectionRequested" }

    function init() {
        fake.files = {}
        selection.localRecordsValid = true
        selection.errorStatus = ""
        requested.clear()
    }

    function test_createCopiesLocalRecords() {
        verify(selection.createLibrary("team"))
        compare(requested.count, 1)
        compare(requested.signalArguments[0][0], "team")
        compare(selection.errorStatus, "")
        const decoded = codec.decode(fake.files["team"])
        compare(decoded.status, "ok")
        compare(JSON.parse(decoded.content)[0].title, "Local")
        compare(selection.localRecords[0].title, "Local")
    }

    function test_createNeverReplaces() {
        fake.files["team"] = "existing"
        verify(!selection.createLibrary("team"))
        compare(selection.errorStatus, "exists")
        compare(fake.files["team"], "existing")
        compare(requested.count, 0)
    }

    function test_createRequiresValidLocalData() {
        selection.localRecordsValid = false
        verify(!selection.createLibrary("team"))
        compare(selection.errorStatus, "invalid-local")
        compare(fake.files["team"], undefined)
    }

    function test_joinValidatesExistingLibrary() {
        verify(!selection.joinLibrary("team"))
        compare(selection.errorStatus, "missing")
        fake.files["team"] = '{"format":"io.github.fooftilly.kopypast","version":1,"snippets":[{"title":"No id"}]}'
        verify(!selection.joinLibrary("team"))
        compare(selection.errorStatus, "invalid-record")
        fake.files["team"] = codec.encode([{id:"s", title:"Shared", text:"body", category:"", tags:[]}])
        verify(selection.joinLibrary("team"))
        compare(requested.signalArguments[0][0], "team")
        compare(selection.errorStatus, "")
    }

    function test_invalidNameAndUnavailable() {
        verify(!selection.joinLibrary("../escape"))
        compare(selection.errorStatus, "invalid-name")
        verify(!unavailable.createLibrary("team"))
        compare(unavailable.errorStatus, "unavailable")
        verify(!unavailable.joinLibrary("team"))
        compare(unavailable.errorStatus, "unavailable")
    }

    function test_leave() {
        selection.errorStatus = "missing"
        selection.leaveLibrary()
        compare(requested.signalArguments[0][0], "")
        compare(selection.errorStatus, "")
    }

    function test_statusMessages() {
        compare(statusText.message("ready"), "")
        compare(statusText.message("loading"), "")
        for (const status of ["unavailable", "missing", "exists", "invalid-name", "conflict",
                              "busy", "invalid-format", "invalid-record", "too-large", "write-failed"])
            verify(statusText.message(status) !== "", status)
    }
}
