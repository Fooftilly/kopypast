/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Controls
import QtTest
import org.kde.kirigami as Kirigami
import "../package/contents/ui" as Local

Item {
    id: fixture
    width: 640
    height: 640

    function i18n(text) { return text }

    property bool permitWrites: true
    Local.SnippetModel {
        id: store
        beforeCommit: function(records) { return fixture.permitWrites }
    }
    Local.SnippetDialog {
        id: editor
        parent: fixture
        width: 500
        height: 560
        store: store
        maximumSnippets: 2
        defaultTemplate: "template text"
        // Simulates rereading a shared library after a failed save.
        recoverStore: function() {
            fixture.recoveries++
            fixture.permitWrites = true
            return true
        }
        recoverAvailable: fixture.recoverAvailable
    }
    property int recoveries: 0
    property bool recoverAvailable: false

    TestCase {
        name: "SnippetEditorLifecycle"
        when: windowShown

        function init() {
            fixture.permitWrites = true
            fixture.recoveries = 0
            fixture.recoverAvailable = false
            store.loadFromConfig('[{"id":"a","title":"One","text":"body","favorite":true,"category":"Work","tags":["Git"]}]')
        }

        function saveButton() {
            const button = findChild(editor.footer, "saveSnippetButton")
            verify(button !== null)
            return button
        }

        function test_libraryChangeBlocksDraft() {
            editor.createSnippet()
            tryCompare(editor, "opened", true)
            editor.titleText = "Local draft"
            verify(saveButton().enabled)
            editor.storeReplaced = true
            verify(!saveButton().enabled)
            verify(!editor.submit())
            verify(editor.visible)
            compare(editor.titleText, "Local draft")
            compare(store.count, 1)
            editor.reject()
            tryCompare(editor, "visible", false)
            editor.createSnippet()
            tryCompare(editor, "opened", true)
            verify(!editor.storeReplaced)
            editor.reject()
            tryCompare(editor, "visible", false)
        }

        // The control lies inside the dialog's visible content area.
        function verifyReachable(item) {
            const content = editor.contentItem
            const p = item.mapToItem(content, 0, 0)
            verify(item.width > 0 && item.height > 0)
            verify(p.x >= 0 && p.y >= 0, "control starts inside the dialog")
            verify(p.x + item.width <= content.width && p.y + item.height <= content.height,
                   "control ends inside the dialog")
        }

        function test_recoverAtMinimumPopupSize() {
            // The popup's minimum size is 14 x 18 grid units.
            const width = editor.width
            const height = editor.height
            editor.width = Kirigami.Units.gridUnit * 14
            editor.height = Kirigami.Units.gridUnit * 18
            fixture.recoverAvailable = true
            editor.editSnippet(0)
            tryCompare(editor, "opened", true)
            editor.titleText = "Small draft"
            fixture.permitWrites = false
            editor.submit()
            verify(editor.saveFailed)
            const recover = findChild(editor, "recoverStoreButton")
            tryCompare(recover, "visible", true)
            waitForItemPolished(recover.parent)
            verifyReachable(recover)
            mouseClick(recover)
            compare(fixture.recoveries, 1)
            compare(editor.titleText, "Small draft")
            mouseClick(saveButton())
            tryCompare(editor, "visible", false)
            compare(store.get(0).title, "Small draft")
            editor.width = width
            editor.height = height
        }

        function test_recoverAfterFailedSaveKeepsDraft() {
            fixture.recoverAvailable = true
            editor.editSnippet(0)
            tryCompare(editor, "opened", true)
            editor.titleText = "Retry draft"
            fixture.permitWrites = false
            mouseClick(saveButton())
            verify(editor.saveFailed)
            const recover = findChild(editor, "recoverStoreButton")
            verify(recover !== null)
            tryCompare(recover, "visible", true)
            // The button appears with the failure message; click only after
            // the layout has placed it, as a user would.
            waitForItemPolished(recover.parent)
            verifyReachable(recover)
            mouseClick(recover)
            compare(fixture.recoveries, 1)
            verify(!editor.saveFailed)
            compare(editor.titleText, "Retry draft")
            mouseClick(saveButton())
            tryCompare(editor, "visible", false)
            compare(store.get(0).title, "Retry draft")
        }

        function test_recoverHiddenWithoutSharedLibrary() {
            editor.editSnippet(0)
            tryCompare(editor, "opened", true)
            fixture.permitWrites = false
            mouseClick(saveButton())
            verify(editor.saveFailed)
            verify(!findChild(editor, "recoverStoreButton").visible)
            verify(!editor.recover())
            compare(fixture.recoveries, 0)
            editor.reject()
            tryCompare(editor, "visible", false)
        }

        function test_failedWriteKeepsDraft() {
            editor.editSnippet(0)
            tryCompare(editor, "opened", true)
            editor.titleText = "Unsaved draft"
            editor.snippetText = "draft body"
            fixture.permitWrites = false
            mouseClick(saveButton())
            verify(editor.visible)
            verify(editor.saveFailed)
            compare(editor.titleText, "Unsaved draft")
            compare(editor.snippetText, "draft body")
            compare(store.get(0).title, "One")
            fixture.permitWrites = true
            mouseClick(saveButton())
            tryCompare(editor, "visible", false)
            compare(store.get(0).title, "Unsaved draft")
            compare(store.get(0).text, "draft body")
        }

        function test_addAndCapacity() {
            editor.createSnippet()
            tryCompare(editor, "opened", true)
            compare(editor.snippetText, "template text")
            verify(!saveButton().enabled)
            editor.titleText = "New"
            verify(saveButton().enabled)
            editor.submit()
            tryCompare(editor, "visible", false)
            compare(store.count, 2)
            compare(store.get(1).title, "New")
            editor.createSnippet()
            verify(!editor.visible)
        }

        function test_editByStableId() {
            store.append({title:"Two", text:"two"})
            editor.editSnippet(0)
            tryCompare(editor, "opened", true)
            store.move(0, 1)
            editor.titleText = "Edited"
            editor.submit()
            tryCompare(editor, "visible", false)
            compare(store.get(0).title, "Two")
            compare(store.get(1).id, "a")
            compare(store.get(1).title, "Edited")
            verify(store.get(1).favorite)
            compare(store.get(1).category, "Work")
            compare(store.get(1).tags, ["Git"])
        }

        function test_concurrentEditIsRejected() {
            editor.editSnippet(0)
            tryCompare(editor, "opened", true)
            editor.titleText = "My draft"
            store.set(0, {title:"Other edit", text:"changed body"})
            verify(editor.editConflict)
            verify(!saveButton().enabled)
            compare(editor.titleText, "My draft")
            verify(!editor.submit())
            verify(editor.visible)
            editor.reject()
            tryCompare(editor, "visible", false)
            compare(store.get(0).title, "Other edit")
            compare(store.get(0).text, "changed body")
            editor.editSnippet(0)
            tryCompare(editor, "opened", true)
            verify(!editor.editConflict)
            compare(editor.titleText, "Other edit")
            editor.reject()
            tryCompare(editor, "visible", false)
        }

        function test_concurrentMetadataEditIsRejected() {
            editor.editSnippet(0)
            tryCompare(editor, "opened", true)
            store.set(0, {title:"One", text:"body", category:"Other", tags:["New"]})
            verify(editor.editConflict)
            verify(!saveButton().enabled)
            editor.reject()
            tryCompare(editor, "visible", false)
            compare(store.get(0).category, "Other")
            compare(store.get(0).tags, ["New"])
        }

        function test_usageAndFavoriteChangesDoNotConflict() {
            editor.editSnippet(0)
            tryCompare(editor, "opened", true)
            store.recordUse("a")
            store.setFavorite("a", false)
            verify(!editor.editConflict)
            verify(saveButton().enabled)
            editor.titleText = "Edited"
            editor.submit()
            tryCompare(editor, "visible", false)
            compare(store.get(0).title, "Edited")
            compare(store.get(0).usageCount, 1)
            verify(!store.get(0).favorite)
        }

        function test_deletedTarget() {
            editor.editSnippet(0)
            tryCompare(editor, "opened", true)
            store.remove(0)
            verify(!saveButton().enabled)
            verify(!editor.submit())
            verify(editor.visible)
            editor.reject()
            tryCompare(editor, "visible", false)
            compare(store.count, 0)
        }

        function test_cancel() {
            editor.editSnippet(0)
            tryCompare(editor, "opened", true)
            editor.titleText = "Unsaved"
            editor.reject()
            tryCompare(editor, "visible", false)
            compare(store.get(0).title, "One")
        }
    }
}
