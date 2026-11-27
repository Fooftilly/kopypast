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
    height: 480

    function i18n(text, arg) {
        return arg === undefined ? text : text.replace("%1", String(arg))
    }

    Local.SnippetModel { id: store }
    Local.MetadataDialog {
        id: editor
        parent: fixture
        anchors.centerIn: parent
        width: 480
        store: store
    }

    TestCase {
        name: "MetadataDialogInteraction"
        when: windowShown

        function control(name) {
            const item = findChild(editor, name)
            verify(item !== null, name)
            return item
        }

        function init() {
            store.loadFromConfig(JSON.stringify([
                {id:"a", title:"One", text:"body", category:"Work", tags:["Git","CI"], favorite:true},
                {id:"b", title:"Two", text:"two", category:"work", tags:["git"]},
                {id:"c", title:"Three", text:"three"}
            ]))
            editor.open()
            tryCompare(editor, "opened", true)
        }

        function cleanup() {
            const confirmation = findChild(editor, "confirmMetadataRemoval")
            if (confirmation && confirmation.visible)
                confirmation.reject()
            if (editor.visible)
                editor.close()
            tryCompare(editor, "visible", false)
        }

        function test_renameCategory() {
            const replacement = control("metadataReplacement")
            const rename = control("renameMetadataButton")
            verify(!rename.enabled)
            compare(control("metadataName").currentText, "Work")
            replacement.forceActiveFocus()
            for (const letter of "projects")
                keyClick(letter)
            tryCompare(replacement, "text", "projects")
            verify(rename.enabled)
            mouseClick(rename)
            compare(store.get(0).category, "projects")
            compare(store.get(1).category, "projects")
            compare(store.get(2).category, "")
            verify(store.get(0).favorite)
            compare(store.count, 3)
            tryCompare(control("metadataName"), "currentText", "projects")
            compare(replacement.text, "")
        }

        function test_tagRemovalConfirmation() {
            const kind = control("metadataKind")
            kind.currentIndex = 1
            const names = control("metadataName")
            tryCompare(names, "count", 2)
            names.currentIndex = names.find("Git")
            compare(names.currentText, "Git")
            const before = store.configValue
            mouseClick(control("removeMetadataButton"))
            const confirmation = control("confirmMetadataRemoval")
            tryCompare(confirmation, "opened", true)
            confirmation.reject()
            tryCompare(confirmation, "visible", false)
            compare(store.configValue, before)
            mouseClick(control("removeMetadataButton"))
            tryCompare(confirmation, "opened", true)
            confirmation.accept()
            tryCompare(confirmation, "visible", false)
            compare(store.get(0).tags, ["CI"])
            compare(store.get(1).tags, [])
            compare(store.count, 3)
            tryCompare(names, "count", 1)
        }

        function test_invalidTagName() {
            control("metadataKind").currentIndex = 1
            tryCompare(control("metadataName"), "count", 2)
            control("metadataReplacement").text = "one,two"
            verify(!control("renameMetadataButton").enabled)
            compare(store.get(0).tags, ["Git","CI"])
        }
    }
}
