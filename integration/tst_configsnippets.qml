/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Controls
import QtTest
import "../package/contents/ui" as Local

// The Snippets settings page lists the shared library it selects and writes
// each change to that library at once, leaving the widget's own snippets
// (saved on Apply) unchanged.
Item {
    id: fixture
    width: 800
    height: 600

    function i18n(text, arg) {
        return arg === undefined ? text : text.replace("%1", String(arg))
    }
    function i18np(singular, plural, count, arg) {
        return (count === 1 ? singular : plural).replace("%1", String(count)).replace("%2", String(arg))
    }
    // The last notification action, such as Undo.
    property var lastAction: null
    function applicationWindow() {
        return {
            showPassiveNotification: function(message, timeout, actionText, action) {
                fixture.lastAction = typeof action === "function" ? action : null
            }
        }
    }
    readonly property QtObject plasmoid: QtObject {
        readonly property QtObject configuration: QtObject {
            property int maxSnippets: 100
            property string defaultTemplate: ""
            property bool handleVariables: true
        }
    }

    // In-memory stand-in for the optional native backend: one library file
    // with a compare-and-swap revision.
    QtObject {
        id: fake
        property var files: ({})
        property int revisions: 0
        property string watchedLibrary: ""
        signal snapshotChanged(string name)
        function encode(records) {
            return JSON.stringify({format:"io.github.fooftilly.kopypast", version:1, snippets:records})
        }
        function readSnapshot(name) {
            return files[name] === undefined ? {status:"missing"}
                : {status:"ok", text:files[name].text, revision:files[name].revision}
        }
        function commit(name, revision, text) {
            if (files[name] === undefined)
                return {status:"missing"}
            if (files[name].revision !== revision)
                return {status:"conflict"}
            const next = "r" + (++revisions)
            files[name] = {text:text, revision:next}
            return {status:"ok", revision:next}
        }
        function create(name, content) {
            if (files[name] !== undefined)
                return {status:"exists"}
            files[name] = {text:content, revision:"r0"}
            return {status:"ok", revision:"r0"}
        }
        function watchLibrary(name) { watchedLibrary = name; return true }
        function stopWatching() { watchedLibrary = "" }
    }

    Local.BackupFormat { id: codec }

    Loader {
        id: loader
        anchors.fill: parent
        active: false
        source: "../package/contents/ui/configSnippets.qml"
    }

    TestCase {
        name: "ConfigSnippetsSharedLibrary"
        when: windowShown

        readonly property string localSnippets: '[{"id":"local","title":"Local","text":"own"}]'

        function init() {
            fake.files = {}
            fake.revisions = 0
            fake.create("team", fake.encode([{id:"s1", title:"Shared", text:"one"}]))
            fake.create("other", fake.encode([{id:"o1", title:"Other", text:"two"}]))
            fixture.lastAction = null
            loader.active = true
            tryVerify(function() { return loader.status === Loader.Ready })
            const page = loader.item
            page.cfg_snippets = localSnippets
            page.listBackend = fake
        }

        function cleanup() {
            loader.active = false
        }

        function sharedTitles(name) {
            return JSON.parse(fake.files[name || "team"].text).snippets.map(function(record) { return record.title })
        }

        function test_localSnippetsByDefault() {
            const page = loader.item
            compare(page.snippetModel.count, 1)
            compare(page.snippetModel.get(0).title, "Local")
            verify(page.storeWritable)
            verify(!findChild(page, "settingsLibraryStatus").visible)
        }

        function test_sharedLibraryIsEditedImmediately() {
            const page = loader.item
            page.cfg_sharedLibrary = "team"
            compare(page.snippetModel.count, 1)
            compare(page.snippetModel.get(0).title, "Shared")
            verify(page.storeWritable)
            tryCompare(findChild(page, "settingsLibraryStatus"), "visible", true)
            verify(findChild(page, "addSnippetButton").enabled)

            verify(page.snippetModel.append({title:"Added in settings", text:"two"}))
            compare(sharedTitles(), ["Shared", "Added in settings"])
            verify(page.snippetModel.set(0, {title:"Renamed", text:"one"}))
            compare(sharedTitles(), ["Renamed", "Added in settings"])
            // The widget's own snippets are not touched.
            compare(page.cfg_snippets, localSnippets)

            page.cfg_sharedLibrary = ""
            compare(page.snippetModel.count, 1)
            compare(page.snippetModel.get(0).title, "Local")
        }

        function test_conflictBlocksUntilRefresh() {
            const page = loader.item
            page.cfg_sharedLibrary = "team"
            // Another widget saves first; this page must not overwrite it.
            compare(fake.commit("team", fake.files["team"].revision,
                fake.encode([{id:"s1", title:"From other widget", text:"one"}])).status, "ok")
            verify(!page.snippetModel.append({title:"Stale", text:"x"}))
            compare(sharedTitles(), ["From other widget"])
            verify(!page.storeWritable)
            verify(!findChild(page, "addSnippetButton").enabled)
            const status = findChild(page, "settingsLibraryStatus")
            tryCompare(status, "visible", true)
            // Refresh rereads the library; it never writes.
            status.actions[0].trigger()
            verify(page.storeWritable)
            compare(page.snippetModel.get(0).title, "From other widget")
            verify(page.snippetModel.append({title:"After refresh", text:"y"}))
            compare(sharedTitles(), ["From other widget", "After refresh"])
            compare(page.cfg_snippets, localSnippets)
        }

        function test_undoStaysInItsLibrary() {
            const page = loader.item
            page.cfg_sharedLibrary = "team"
            page.deleteSnippet(0)
            compare(sharedTitles("team"), [])
            verify(fixture.lastAction !== null)
            // Both libraries use the same shared model object.
            page.cfg_sharedLibrary = ""
            page.cfg_sharedLibrary = "other"
            fixture.lastAction()
            compare(sharedTitles("other"), ["Other"])
            compare(sharedTitles("team"), [])

            // Undo still works in the library it came from.
            page.deleteSnippet(0)
            compare(sharedTitles("other"), [])
            fixture.lastAction()
            compare(sharedTitles("other"), ["Other"])
        }

        function test_noticesMatchPersistence() {
            const page = loader.item
            const metadata = findChild(page, "metadataPersistenceNote")
            verify(metadata.text.indexOf("Apply the widget settings to save") >= 0)
            verify(!findChild(page, "sharedModeNotice").visible)
            page.cfg_sharedLibrary = "team"
            verify(metadata.text.indexOf("saved to the shared library immediately") >= 0)
            const notice = findChild(page, "sharedModeNotice")
            tryCompare(notice, "visible", true)
            verify(notice.text.indexOf("from the popup") < 0)
            page.cfg_sharedLibrary = ""
            verify(metadata.text.indexOf("Apply the widget settings to save") >= 0)
        }

        function test_sharedLibraryBackupRoundTrip() {
            // Back up one shared library from the settings page and restore
            // it into another; identities survive and nothing is local.
            const page = loader.item
            page.cfg_sharedLibrary = "team"
            verify(page.snippetModel.append({title:"Second", text:"two", category:"Work", tags:["git"]}))
            const backup = codec.encode(page.snippetModel.snippets)
            const ids = page.snippetModel.snippets.map(function(record) { return record.id })

            page.cfg_sharedLibrary = "other"
            const decoded = codec.decode(backup)
            compare(decoded.status, "ok")
            const result = page.snippetModel.restoreBackup(decoded.content, 100, decoded.preserveIdentity)
            compare(result.status, "restored")
            compare(result.count, 2)
            compare(sharedTitles("other"), ["Other", "Shared", "Second"])
            const restored = JSON.parse(fake.files["other"].text).snippets
            compare(restored.slice(1).map(function(record) { return record.id }), ids)
            compare(restored[2].category, "Work")
            compare(restored[2].tags, ["git"])

            // Restoring the same backup again changes nothing.
            compare(page.snippetModel.restoreBackup(decoded.content, 100, true).status, "duplicates")
            compare(sharedTitles("other"), ["Other", "Shared", "Second"])
            compare(page.cfg_snippets, localSnippets)
        }

        function test_unavailableLibraryBlocksWrites() {
            const page = loader.item
            page.listBackend = null
            page.cfg_sharedLibrary = "team"
            compare(page.snippetModel.count, 0)
            verify(!page.storeWritable)
            verify(!findChild(page, "addSnippetButton").enabled)
            tryCompare(findChild(page, "settingsLibraryStatus"), "visible", true)
            compare(page.cfg_snippets, localSnippets)
        }
    }
}
