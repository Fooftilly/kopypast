/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    id: test
    name: "LibraryRouterWatch"

    // Minimal stand-in for the optional native backend.
    QtObject {
        id: fake
        property string watchedLibrary: ""
        property bool directoryPresent: true
        property bool fileReadable: true
        property int stops: 0
        readonly property string content: '{"format":"io.github.fooftilly.kopypast","version":1,"snippets":[{"id":"s","title":"Shared","text":"body"}]}'
        function readSnapshot(name) {
            return fileReadable ? {status:"ok", text:content, revision:"r1"} : {status:"missing"}
        }
        function watchLibrary(name) {
            watchedLibrary = directoryPresent ? name : ""
            return directoryPresent
        }
        function stopWatching() {
            stops++
            watchedLibrary = ""
        }
    }

    Local.LibraryStorageRouter { id: router; backend: fake }

    function init() {
        router.leaveLibrary()
        fake.directoryPresent = true
        fake.fileReadable = true
        fake.stops = 0
    }

    function test_failedRefreshStillReattaches() {
        verify(router.joinLibrary("team"))
        verify(router.watching)
        // The directory disappears: a failed read must not leave a stale
        // watching=true behind.
        fake.directoryPresent = false
        fake.fileReadable = false
        fake.watchedLibrary = ""
        verify(!router.refresh())
        verify(!router.watching)
        compare(router.status, "missing")
        // When the directory returns, a later failed read still reattaches,
        // and a successful refresh recovers the session.
        fake.directoryPresent = true
        verify(!router.refresh())
        verify(router.watching)
        fake.fileReadable = true
        verify(router.refresh())
        verify(router.writable)
        verify(router.watching)
    }

    function test_leaveDoesNotStopReplacedWatch() {
        verify(router.joinLibrary("team"))
        fake.watchedLibrary = "other"
        verify(!router.watching)
        router.leaveLibrary()
        compare(fake.stops, 0)
        compare(fake.watchedLibrary, "other")
    }
}
