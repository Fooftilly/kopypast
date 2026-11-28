/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "ConfirmedDelete"
    Local.SnippetModel { id: store }

    function init() {
        store.loadFromConfig('[{"id":"a","title":"One","text":"body","tags":["x"]},{"id":"b","title":"Two","text":"two"}]')
    }

    function test_deletesConfirmedRecord() {
        const fields = store.editableFields(store.get(0))
        const result = store.removeConfirmed("a", fields)
        compare(result.status, "ok")
        compare(store.count, 1)
        verify(store.undoRemoval(result.deletion))
        compare(store.get(0).id, "a")
    }

    function test_changedRecordNeedsNewConfirmation() {
        const fields = store.editableFields(store.get(0))
        verify(store.set(0, {title:"One", text:"edited elsewhere"}))
        compare(store.removeConfirmed("a", fields).status, "changed")
        compare(store.count, 2)
        compare(store.get(0).text, "edited elsewhere")
    }

    function test_usageAndFavoriteDoNotBlockDeletion() {
        const fields = store.editableFields(store.get(0))
        verify(store.recordUse("a"))
        verify(store.setFavorite("a", true))
        compare(store.removeConfirmed("a", fields).status, "ok")
    }

    function test_missingRecord() {
        const fields = store.editableFields(store.get(0))
        verify(store.remove(0))
        compare(store.removeConfirmed("a", fields).status, "missing")
        compare(store.count, 1)
    }
}
