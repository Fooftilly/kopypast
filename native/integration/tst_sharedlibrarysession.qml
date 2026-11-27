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
