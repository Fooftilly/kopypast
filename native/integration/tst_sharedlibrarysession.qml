/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import io.github.fooftilly.kopypast.fileio 1.0
import "../../package/contents/ui" as Local

TestCase {
    id: test
    name: "SharedLibrarySession"
    property string libraryId: "session-" + Date.now() + "-" + Math.random().toString(36).slice(2)
    SharedLibrary { id: backendA }
    SharedLibrary { id: backendB }
    Local.SnippetModel {
        id: a
        beforeCommit: function(records) { return sessionA.commitRecords(records) }
    }
    Local.SnippetModel {
        id: b
        beforeCommit: function(records) { return sessionB.commitRecords(records) }
    }
    Local.SharedLibrarySession { id: sessionA; store: a; backend: backendA }
    Local.SharedLibrarySession { id: sessionB; store: b; backend: backendB }
    Local.BackupFormat { id: codec }
    Local.LibraryStorageRouter { id: routerA; backend: backendA }
    Local.LibraryStorageRouter { id: routerB; backend: backendB }
    Local.LibraryStorageRouter { id: unavailableRouter }
    SharedLibrary { id: sharedBackend }
    Local.LibrarySelection {
        id: settingsSelection
        backend: backendA
        localRecords: [{id:"x", title:"From settings", text:"body", category:"", tags:[]}]
    }
    Local.LibrarySelection { id: otherSelection; backend: backendB }

    function test_deleteAfterRemoteEditNeedsConfirmation() {
        // Widget A asks to confirm a deletion; widget B edits the record and
        // A refreshes automatically. A's deletion must not remove B's edit.
        const name = test.libraryId + "-delete"
        routerA.leaveLibrary()
        routerB.leaveLibrary()
        routerA.localConfig = '[{"id":"d","title":"Shared","text":"body"}]'
        verify(routerA.createLibrary(name))
        verify(routerB.joinLibrary(name))
        const confirmed = routerA.activeStore.editableFields(routerA.activeStore.get(0))
        verify(routerB.activeStore.set(0, {title:"Shared", text:"edited by B"}))
        tryVerify(function() { return routerA.activeStore.get(0).text === "edited by B" })
        compare(routerA.activeStore.removeConfirmed("d", confirmed).status, "changed")
        verify(routerA.refresh())
        compare(routerA.activeStore.count, 1)
        compare(routerA.activeStore.get(0).text, "edited by B")
        routerA.leaveLibrary()
        routerB.leaveLibrary()
    }

    function test_settingsCreateAndJoin() {
        // The settings page creates a library file, then another widget
        // joins it; the widget router opens it by the saved name.
        const name = test.libraryId + "-settings"
        verify(settingsSelection.createLibrary(name))
        verify(!settingsSelection.createLibrary(name))
        compare(settingsSelection.errorStatus, "exists")
        verify(otherSelection.joinLibrary(name))
        verify(!otherSelection.joinLibrary(name + "-absent"))
        compare(otherSelection.errorStatus, "missing")
        routerB.leaveLibrary()
        verify(routerB.restoreSelection(name))
        compare(routerB.activeStore.get(0).title, "From settings")
        verify(routerB.writable)
        routerB.leaveLibrary()
    }
    Local.LibraryStorageRouter { id: routerC; backend: sharedBackend }
    Local.LibraryStorageRouter { id: routerD; backend: sharedBackend }

    function test_replacedWatchIsReported() {
        // One backend holds one watch. A router whose watch is replaced must
        // stop claiming synchronization, and must not stop the new owner.
        const first = test.libraryId + "-watch-c"
        const second = test.libraryId + "-watch-d"
        routerC.localConfig = '[{"id":"c","title":"C","text":"body"}]'
        routerD.localConfig = '[{"id":"d","title":"D","text":"body"}]'
        verify(routerC.createLibrary(first))
        verify(routerC.watching)
        verify(routerD.createLibrary(second))
        verify(routerD.watching)
        verify(!routerC.watching)
        routerC.leaveLibrary()
        compare(sharedBackend.watchedLibrary, second)
        verify(routerD.watching)
        verify(routerC.joinLibrary(first))
        verify(routerC.watching)
        verify(!routerD.watching)
        routerD.leaveLibrary()
        compare(sharedBackend.watchedLibrary, first)
        verify(routerD.joinLibrary(second))
        verify(!routerC.watching)
        verify(routerC.refresh())
        verify(routerC.watching)
        routerC.leaveLibrary()
        routerD.leaveLibrary()
        compare(sharedBackend.watchedLibrary, "")
    }

    function test_autoRefreshAndLeave() {
        // Dedicated backends avoid replacing another router's watch.
        const name = test.libraryId + "-auto"
        routerA.leaveLibrary()
        routerB.leaveLibrary()
        routerA.localConfig = '[{"id":"a","title":"Original","text":"body"}]'
        routerB.localConfig = '[{"id":"b","title":"Private","text":"body"}]'
        verify(routerA.createLibrary(name))
        verify(routerB.joinLibrary(name))
        verify(routerA.watching)
        verify(routerB.watching)
        verify(routerA.activeStore.set(0,{title:"First update",text:"body"}))
        tryVerify(function() { return routerB.activeStore.get(0).title === "First update" })
        verify(routerA.activeStore.set(0,{title:"Second update",text:"body"}))
        tryVerify(function() { return routerB.activeStore.get(0).title === "Second update" })
        // A failed synchronous CAS stays blocked, even after notifications.
        verify(routerA.activeStore.set(0,{title:"New revision",text:"body"}))
        verify(!routerB.activeStore.set(0,{title:"Stale",text:"body"}))
        compare(routerB.status,"conflict")
        wait(200)
        compare(routerB.status,"conflict")
        compare(routerB.activeStore.get(0).title,"Second update")
        verify(routerB.refresh())
        compare(routerB.activeStore.get(0).title,"New revision")
        routerB.leaveLibrary()
        verify(!routerB.watching)
        verify(routerA.activeStore.set(0,{title:"After leave",text:"body"}))
        wait(200)
        compare(routerB.activeStore.get(0).title,"Private")
        routerA.leaveLibrary()
    }

    function test_localSharedIsolation() {
        const name = test.libraryId + "-router"
        const localA = '[{"id":"local-a","title":"Local A","text":"body"}]'
        const localB = '[{"id":"local-b","title":"Local B","text":"other"}]'
        routerA.localConfig = localA
        routerB.localConfig = localB
        verify(!routerA.shared)
        verify(routerA.createLibrary(name))
        compare(routerA.selectedLibrary, name)
        compare(routerA.activeStore.get(0).id, "local-a")
        compare(routerA.localConfig, localA)
        verify(routerB.joinLibrary(name))
        compare(routerB.activeStore.snippets, routerA.activeStore.snippets)
        compare(routerB.localConfig, localB)
        verify(routerA.activeStore.set(0,{title:"Shared edit",text:"body"}))
        verify(!routerB.activeStore.set(0,{title:"Stale",text:"body"}))
        compare(routerB.status,"conflict")
        verify(!routerB.writable)
        compare(routerB.localConfig,localB)
        verify(routerB.refresh())
        compare(routerB.activeStore.get(0).title,"Shared edit")
        routerB.leaveLibrary()
        verify(!routerB.shared)
        compare(routerB.activeStore.get(0).title,"Local B")
        compare(routerB.localConfig,localB)
        verify(routerB.restoreSelection(name))
        compare(routerB.activeStore.get(0).title,"Shared edit")
        compare(routerB.localConfig,localB)
        routerA.leaveLibrary()
        compare(routerA.activeStore.get(0).title,"Local A")
        compare(routerA.localConfig,localA)
        verify(!routerA.createLibrary(name))
        compare(routerA.status,"exists")
        verify(!routerA.shared)
        compare(routerA.localConfig,localA)
    }

    function test_failedSelection() {
        const name = test.libraryId + "-missing-router"
        const local = '[{"id":"local","title":"Local","text":"body"}]'
        routerA.leaveLibrary()
        routerA.localConfig = local
        verify(!routerA.joinLibrary(name))
        verify(!routerA.shared)
        compare(routerA.activeStore.get(0).title,"Local")
        verify(!routerA.restoreSelection(name))
        verify(routerA.shared)
        compare(routerA.status,"missing")
        compare(routerA.activeStore.count,0)
        verify(!routerA.activeStore.append({title:"Do not save",text:"body"}))
        verify(!routerA.writable)
        compare(routerA.localConfig,local)
        routerA.leaveLibrary()
        compare(routerA.activeStore.get(0).title,"Local")

        unavailableRouter.localConfig = local
        verify(!unavailableRouter.joinLibrary(name))
        verify(!unavailableRouter.shared)
        verify(!unavailableRouter.restoreSelection(name))
        compare(unavailableRouter.status,"unavailable")
        verify(!unavailableRouter.writable)
        compare(unavailableRouter.activeStore.count,0)
        compare(unavailableRouter.localConfig,local)
        unavailableRouter.leaveLibrary()
        compare(unavailableRouter.activeStore.get(0).id,"local")
    }

    function test_twoSessions() {
        verify(sessionA.createLibrary(test.libraryId,[{id:"a",title:"Original",text:"body"}]))
        verify(sessionB.openLibrary(test.libraryId))
        compare(a.snippets,b.snippets)
        verify(a.set(0,{title:"Updated",text:"body"}))
        const stale = b.configValue
        verify(!b.set(0,{title:"Stale",text:"body"}))
        compare(sessionB.status,"conflict")
        compare(b.configValue,stale)
        verify(!b.recordUse("a"))
        compare(b.configValue,stale)
        verify(sessionB.refresh())
        compare(b.get(0).title,"Updated")
        verify(b.setFavorite("a",true))
        verify(sessionA.refresh())
        verify(a.get(0).favorite)
        verify(!sessionB.createLibrary(test.libraryId,[]))
        compare(sessionB.status,"exists")
        verify(!b.remove(0))
        verify(sessionB.openLibrary(test.libraryId))
        compare(a.snippets,b.snippets)
    }

    function test_invalidRecordsBlockWrites() {
        const name = test.libraryId + "-bad"
        compare(backendA.create(name,codec.encode([{id:"a",title:"Valid",text:"body"},null])).status,"ok")
        verify(!sessionA.openLibrary(name))
        compare(sessionA.status,"invalid-record")
        verify(sessionA.recoveryText.length > 0)
        verify(!a.append({title:"New",text:"body"}))
        compare(backendA.readSnapshot(name).text,sessionA.recoveryText)
        verify(!sessionA.openLibrary(test.libraryId + "-missing"))
        compare(sessionA.status,"missing")
        verify(!a.append({title:"New",text:"body"}))
    }
}
