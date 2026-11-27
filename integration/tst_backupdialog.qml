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
    function i18n(text) { return text }
    function i18np(single, plural, count) { return count === 1 ? single : plural }

    Local.SnippetModel { id: snippetModel }

    Local.BackupDialog {
        id: backupDialog
        width: 500
        height: 360
    }

    TestCase {
        name: "BackupDialogLifecycle"
        when: windowShown

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
