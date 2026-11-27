/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Controls
import QtTest
import io.github.fooftilly.kopypast.fileio 1.0
import "../../package/contents/ui" as Local

Item {
    id: fixture
    width: 640
    height: 480
    function i18n(text, arg) { return arg === undefined ? text : text.replace("%1", String(arg)) }
    function i18np(single, plural, count) { return (count === 1 ? single : plural).replace("%1", String(count)) }
    Local.SnippetModel { id: store }
    BackupFile { id: io }
    Local.BackupDialog {
        id: editor
        parent: fixture
        store: store
        maximumSnippets: 10
        width: 500
        height: 400
    }
    SignalSpy { id: notices; target: editor; signalName: "notificationRequested" }
    TestCase {
        name: "InstalledBackupFileDialog"
        when: windowShown
        // Use a unique local path under the test runner working directory.
        property url targetUrl: Qt.resolvedUrl("../../native-test-backup-" + Date.now() + ".json")
        function cleanup() {
            const confirmation = findChild(editor, "backupOverwriteDialog")
            if (confirmation && confirmation.visible)
                confirmation.reject()
            if (editor.visible)
                editor.close()
            tryCompare(editor, "visible", false)
            notices.clear()
        }

        function test_overwriteConfirmation() {
            const url = Qt.resolvedUrl("../../native-test-backup-confirm-" + Date.now() + ".json")
            compare(io.write(url, "original", false).status, "ok")
            store.loadFromConfig('[{"id":"a","title":"Replacement","text":"body"}]')
            editor.isBackup = true
            editor.open()
            tryCompare(editor, "opened", true)
            const input = findChild(editor.contentItem, "backupText")
            const confirmation = findChild(editor, "backupOverwriteDialog")
            verify(input !== null && confirmation !== null)
            const replacement = input.text
            editor.writeBackupFile(url, replacement)
            tryCompare(confirmation, "opened", true)
            compare(io.read(url).text, "original")
            confirmation.reject()
            tryCompare(confirmation, "visible", false)
            compare(io.read(url).text, "original")
            compare(editor.pendingOverwriteText, "")
            compare(notices.count, 0)

            editor.writeBackupFile(url, replacement)
            tryCompare(confirmation, "opened", true)
            const yes = confirmation.standardButton(Dialog.Yes)
            verify(yes !== null && yes.enabled)
            mouseClick(yes)
            tryCompare(confirmation, "visible", false)
            compare(io.read(url).text, replacement)
            tryCompare(notices, "count", 1)
            compare(notices.signalArguments[0][0], "Backup file saved")
            compare(editor.pendingOverwriteText, "")
        }

        function test_failedReadKeepsDraft() {
            store.loadFromConfig("[]")
            editor.isBackup = false
            editor.open()
            tryCompare(editor, "opened", true)
            const input = findChild(editor.contentItem, "backupText")
            verify(input !== null)
            input.text = '[{"title":"Draft","text":"body"}]'
            const draft = input.text
            editor.readBackupFile("https://example.invalid/backup.json")
            compare(input.text, draft)
            compare(store.count, 0)
            tryCompare(notices, "count", 1)
            compare(notices.signalArguments[0][0], "Select a local regular file")
        }

        function test_fileRoundTrip() {
            verify(editor.fileAccessAvailable)
            store.loadFromConfig('[{"id":"a","title":"Čaša","text":"  日本語\\n\\t<b>literal</b>"}]')
            const expected = JSON.stringify(store.snippets)
            editor.isBackup = true
            editor.open()
            tryCompare(editor, "opened", true)
            const input = findChild(editor.contentItem, "backupText")
            verify(input !== null)
            verify(findChild(editor.contentItem, "backupFileButton").visible)
            editor.writeBackupFile(targetUrl, input.text)
            compare(io.read(targetUrl).status, "ok")
            const original = io.read(targetUrl).text
            editor.writeBackupFile(targetUrl, "must not overwrite")
            compare(io.read(targetUrl).text, original)
            verify(editor.pendingOverwriteText === "must not overwrite")
            editor.close()
            tryCompare(editor, "visible", false)
            compare(io.read(targetUrl).text, original)
            store.loadFromConfig("[]")
            editor.isBackup = false
            editor.open()
            tryCompare(editor, "opened", true)
            editor.readBackupFile(targetUrl)
            compare(input.text, original)
            compare(store.count, 0)
            editor.reject()
            tryCompare(editor, "visible", false)
            compare(store.count, 0)
            editor.open()
            tryCompare(editor, "opened", true)
            editor.readBackupFile(targetUrl)
            editor.accept()
            tryCompare(editor, "visible", false)
            compare(JSON.stringify(store.snippets), expected)
        }
    }
}
