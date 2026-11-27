/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick

Item {
    id: session
    visible: false
    required property var store
    required property var backend
    property string libraryName: ""
    property string revision: ""
    property string status: "closed"
    property string recoveryText: ""
    readonly property bool writable: status === "ready"

    BackupFormat { id: codec }

    // This store is dedicated to the shared session. Its owner must bind
    // store.beforeCommit to commitRecords and not mirror it into local config.
    function validatedRecords(text) {
        const decoded = codec.decode(text)
        if (decoded.status !== "ok" || !decoded.preserveIdentity)
            return null
        const records = store.normalizeRecords(JSON.parse(decoded.content))
        if (records === null)
            return null
        const ids = new Set()
        for (const record of records) {
            if (!record.id || ids.has(record.id))
                return null
            ids.add(record.id)
        }
        return records
    }

    function fail(result) {
        status = result.status
        recoveryText = typeof result.text === "string" ? result.text : ""
        return false
    }

    function openLibrary(name) {
        libraryName = name
        revision = ""
        status = "loading"
        recoveryText = ""
        return refresh()
    }

    function refresh() {
        if (!libraryName)
            return fail({status:"invalid-name"})
        status = "loading"
        if (!backend)
            return fail({status:"unavailable"})
        const result = backend.readSnapshot(libraryName)
        if (result.status !== "ok")
            return fail(result)
        const records = validatedRecords(result.text)
        if (records === null)
            return fail({status:"invalid-record", text:result.text})
        // Do not publish an invalid or partially normalized snapshot.
        store.loadFromConfig(JSON.stringify(records))
        revision = result.revision
        recoveryText = ""
        status = "ready"
        return true
    }

    // Explicit creation from a validated local snapshot. Do not replace an
    // existing library, even if it is empty or damaged.
    function createLibrary(name, records) {
        libraryName = name
        revision = ""
        status = "loading"
        recoveryText = ""
        if (!backend)
            return fail({status:"unavailable"})
        const text = codec.encode(records)
        const normalized = validatedRecords(text)
        if (normalized === null)
            return fail({status:"invalid-record"})
        const result = backend.create(name, codec.encode(normalized))
        if (result.status !== "ok")
            return fail(result)
        store.loadFromConfig(JSON.stringify(normalized))
        revision = result.revision
        status = "ready"
        return true
    }

    function commitRecords(records) {
        if (!writable || !backend)
            return false
        const result = backend.commit(libraryName, revision, codec.encode(records))
        if (result.status !== "ok")
            return fail(result)
        revision = result.revision
        return true
    }
}
