/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "SnippetCommitGate"
    property bool permit: false
    property int attempts: 0
    Local.SnippetModel {
        id: store
        beforeCommit: function(records) {
            attempts++
            return permit
        }
    }
    SignalSpy { id: changes; target: store; signalName: "configValueChanged" }

    function init() {
        permit = false
        store.loadFromConfig('[{"id":"a","title":"One","text":"body","isNew":true},{"id":"b","title":"Two","text":"two"}]')
        attempts = 0
        changes.clear()
    }

    function test_rejectMutations() {
        const before = store.configValue
        verify(!store.append({title:"New",text:"body"}))
        verify(!store.set(0,{title:"Edited",text:"body"}))
        verify(!store.remove(0))
        compare(store.removeForUndo(0), null)
        verify(!store.move(0,1))
        verify(!store.recordUse("a"))
        verify(!store.markAsUsed(0))
        verify(!store.setFavorite("a",true))
        compare(store.restoreBackup('[{"title":"Restored","text":"body"}]',50).status,"write-failed")
        compare(attempts,9)
        compare(changes.count,0)
        compare(store.configValue,before)
        compare(store.get(0).title,"One")
        compare(store.count,2)
    }

    function test_undoRejectionCanBeRetried() {
        permit = true
        const deletion = store.removeForUndo(0)
        verify(deletion !== null)
        compare(store.count,1)
        permit = false
        verify(!store.undoRemoval(deletion))
        verify(!deletion.undone)
        compare(store.count,1)
        permit = true
        verify(store.undoRemoval(deletion))
        compare(store.get(0).id,"a")
        verify(deletion.undone)
    }

    function test_externalLoadDoesNotCommit() {
        store.loadFromConfig('[{"id":"new","title":"New","text":"body"}]')
        compare(attempts,0)
        compare(store.get(0).id,"new")
        store.loadFromConfig("[null]")
        verify(!store.resetInvalidConfiguration())
        compare(store.configValue,"[null]")
    }
}
