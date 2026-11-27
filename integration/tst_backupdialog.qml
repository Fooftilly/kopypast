/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Controls
import QtTest
import "../package/contents/ui" as Local

Item {
    id: snippetsPage
    width: 640
    height: 480

    // Standalone dialog context, equivalent to its settings-page inputs.
    function i18n(text, arg) {
        return arg === undefined ? text : text.replace("%1", String(arg))
    }
    function i18np(single, plural, count, duplicates) {
        return (count === 1 ? single : plural).replace("%1", String(count)).replace("%2", String(duplicates))
    }

    Local.SnippetModel { id: snippetModel }
    Local.BackupFormat { id: codec }
    SignalSpy { id: notices; target: backupDialog; signalName: "notificationRequested" }

    Local.BackupDialog {
        id: backupDialog
        parent: snippetsPage
        store: snippetModel
        maximumSnippets: 3
        width: 500
        height: 360
    }

    TestCase {
        name: "BackupDialogLifecycle"
        when: windowShown

        function init() {
            notices.clear()
        }

        function cleanup() {
            if (backupDialog.visible)
                backupDialog.reject()
            tryCompare(backupDialog, "visible", false)
        }

        function acceptRestore(raw) {
            backupDialog.isBackup = false
            backupDialog.open()
            tryCompare(backupDialog, "opened", true)
            const input = findChild(backupDialog.contentItem, "backupText")
            verify(input !== null)
            input.text = raw
            verify(backupDialog.standardButton(Dialog.Ok).enabled)
            backupDialog.accept()
            tryCompare(backupDialog, "visible", false)
            tryCompare(notices, "count", 1)
            compare(notices.signalArguments[0][1], 3000)
            return notices.signalArguments[0][0]
        }

        function test_legacyRestore() {
            snippetModel.loadFromConfig("[]")
            compare(acceptRestore('[{"title":"Legacy","text":"body"}]'),
                "Successfully restored 1 snippet")
            compare(snippetModel.count, 1)
            compare(snippetModel.get(0).title, "Legacy")
        }

        function test_versionedRestorePreservesIdentities() {
            snippetModel.loadFromConfig("[]")
            const raw = codec.encode([
                {id:"a", title:"Same", text:"body", category:"Work"},
                {id:"b", title:"Same", text:"body", category:"Personal"}
            ])
            compare(acceptRestore(raw), "Successfully restored 2 snippets")
            compare(snippetModel.count, 2)
            compare(snippetModel.get(0).id, "a")
            compare(snippetModel.get(1).id, "b")
            compare(snippetModel.get(1).category, "Personal")
        }

        function test_rejectedRestore_data() {
            return [
                {tag:"malformed", raw:"[", message:"Invalid backup format"},
                {tag:"future-version", raw:'{"format":"io.github.fooftilly.kopypast","version":99,"snippets":[]}', message:"Unsupported backup version"},
                {tag:"invalid-record", raw:"[null]", message:"Invalid snippet format"},
                {tag:"conflicting-id", raw:'{"format":"io.github.fooftilly.kopypast","version":1,"snippets":[{"id":"new","title":"New","text":"new"},{"id":"a","title":"Changed","text":"body"}]}', message:"Backup conflicts with an existing snippet. No snippets were restored."}
            ]
        }

        function test_rejectedRestore(data) {
            snippetModel.loadFromConfig('[{"id":"a","title":"Original","text":"body"}]')
            const before = snippetModel.configValue
            compare(acceptRestore(data.raw), data.message)
            compare(snippetModel.configValue, before)
            compare(snippetModel.count, 1)
        }

        function test_capacity() {
            snippetModel.loadFromConfig('[{"id":"a","title":"Original","text":"body"}]')
            compare(acceptRestore('[{"title":"One","text":"one"},{"title":"Two","text":"two"},{"title":"Three","text":"three"}]'),
                "Only restored 2 snippets due to maximum limit")
            compare(snippetModel.count, 3)
        }

        function test_switchModes() {
            snippetModel.loadFromConfig('[{"title":"Original","text":"body"}]')
            const input = findChild(backupDialog.contentItem, "backupText")
            verify(input !== null)

            backupDialog.isBackup = true
            backupDialog.open()
            tryCompare(backupDialog, "opened", true)
            compare(JSON.parse(input.text).snippets[0].title, "Original")
            verify(backupDialog.standardButton(Dialog.Ok) === null)
            backupDialog.close()
            tryCompare(backupDialog, "visible", false)

            backupDialog.isBackup = false
            backupDialog.open()
            tryCompare(backupDialog, "opened", true)
            compare(input.text, "")
            verify(!backupDialog.standardButton(Dialog.Ok).enabled)
            input.text = '[{"title":"Unsaved","text":"draft"}]'
            verify(backupDialog.standardButton(Dialog.Ok).enabled)
            backupDialog.reject()
            tryCompare(backupDialog, "visible", false)
            compare(snippetModel.count, 1)

            snippetModel.append({title:"New", text:"new body"})
            backupDialog.isBackup = true
            backupDialog.open()
            tryCompare(backupDialog, "opened", true)
            compare(JSON.parse(input.text).snippets.length, 2)
            compare(JSON.parse(input.text).snippets[1].title, "New")
            backupDialog.close()
            tryCompare(backupDialog, "visible", false)

            snippetModel.loadFromConfig("[null]")
            backupDialog.open()
            tryCompare(backupDialog, "opened", true)
            compare(input.text, "[null]")
            backupDialog.close()
            tryCompare(backupDialog, "visible", false)
        }
    }
}
