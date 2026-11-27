/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Controls
import QtTest
import "../package/contents/ui" as Local

Item {
    id: fixture
    width: 640
    height: 640

    function i18n(text) { return text }

    Local.SnippetModel { id: store }
    Local.SnippetDialog {
        id: editor
        parent: fixture
        width: 500
        height: 560
        store: store
        maximumSnippets: 2
        defaultTemplate: "template text"
    }

    TestCase {
        name: "SnippetEditorLifecycle"
        when: windowShown

        function init() {
            store.loadFromConfig('[{"id":"a","title":"One","text":"body","favorite":true,"category":"Work","tags":["Git"]}]')
        }

        function test_addAndCapacity() {
            editor.createSnippet()
            tryCompare(editor, "opened", true)
            compare(editor.snippetText, "template text")
            verify(!editor.standardButton(Dialog.Ok).enabled)
            editor.titleText = "New"
            verify(editor.standardButton(Dialog.Ok).enabled)
            editor.accept()
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
            editor.accept()
            tryCompare(editor, "visible", false)
            compare(store.get(0).title, "Two")
            compare(store.get(1).id, "a")
            compare(store.get(1).title, "Edited")
            verify(store.get(1).favorite)
            compare(store.get(1).category, "Work")
            compare(store.get(1).tags, ["Git"])
        }

        function test_deletedTarget() {
            editor.editSnippet(0)
            tryCompare(editor, "opened", true)
            store.remove(0)
            verify(!editor.standardButton(Dialog.Ok).enabled)
            editor.accept()
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
