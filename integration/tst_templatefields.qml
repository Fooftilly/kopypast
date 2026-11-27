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

    Local.VariableHandler { id: handler }
    Local.TemplateFieldsDialog {
        id: editor
        parent: fixture
        anchors.centerIn: parent
        width: 520
        height: 500
        processor: handler
    }

    SignalSpy {
        id: copied
        target: editor
        signalName: "copyRequested"
    }

    TestCase {
        name: "TemplateDialogInteraction"
        when: windowShown

        function init() {
            copied.clear()
        }

        function cleanup() {
            if (editor.visible)
                editor.reject()
            tryCompare(editor, "visible", false)
        }

        function openTemplate(id, text) {
            editor.openTemplate(id, text, handler.placeholderNames(text))
            tryCompare(editor, "opened", true)
        }

        function test_acceptSnapshot() {
            openTemplate("a", "{{PROJECT}} / {{PR_NUMBER}} / {{PROJECT}} {ISO_DATE}")
            compare(editor.fieldNames, ["PROJECT", "PR_NUMBER"])
            const first = findChild(editor.contentItem, "templateField_PROJECT")
            const second = findChild(editor.contentItem, "templateField_PR_NUMBER")
            const preview = findChild(editor.contentItem, "resolvedTemplatePreview")
            verify(first !== null && second !== null && preview !== null)
            tryCompare(first, "activeFocus", true)
            // Exercise the actual text-field input path and live preview.
            for (const character of "kopypast")
                keyClick(character)
            tryCompare(first, "text", "kopypast")
            second.forceActiveFocus()
            keyClick("5")
            keyClick("4")
            tryCompare(second, "text", "54")
            const expected = "kopypast / 54 / kopypast " + Qt.formatDate(editor.previewTime, "yyyy-MM-dd")
            compare(editor.resolvedText, expected)
            compare(preview.text, expected)
            compare(copied.count, 0)
            editor.accept()
            tryCompare(copied, "count", 1)
            compare(copied.signalArguments[0], ["a", expected])
            tryCompare(editor, "visible", false)
            tryCompare(editor, "snippetId", "")
            compare(editor.fieldNames, [])
            compare(editor.values, {})
        }

        function test_cancelAndReopen() {
            openTemplate("a", "{{FIELD}}")
            editor.setValue("FIELD", "unsaved")
            compare(editor.resolvedText, "unsaved")
            editor.reject()
            tryCompare(editor, "visible", false)
            tryCompare(editor, "snippetId", "")
            compare(copied.count, 0)
            openTemplate("b", "{{FIELD}} {{NEW_FIELD}}")
            compare(editor.values, {FIELD:"", NEW_FIELD:""})
            compare(editor.resolvedText, " ")
            editor.reject()
            tryCompare(editor, "visible", false)
            compare(copied.count, 0)
        }

        function test_emptyAndLiteral() {
            openTemplate("empty", "{{FIELD}}")
            editor.accept()
            tryCompare(copied, "count", 1)
            compare(copied.signalArguments[0], ["empty", ""])
            tryCompare(editor, "visible", false)
            tryCompare(editor, "snippetId", "")
            copied.clear()
            openTemplate("literal", "{{FIELD}}")
            editor.setValue("FIELD", "<b>{YEAR} {{OTHER}}</b>")
            editor.accept()
            tryCompare(copied, "count", 1)
            compare(copied.signalArguments[0], ["literal", "<b>{YEAR} {{OTHER}}</b>"])
        }
    }
}
