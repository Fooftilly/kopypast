/*
    SPDX-FileCopyrightText: 2025 Vladimir Kosolapov
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kirigami.private as KirigamiPrivate

Dialog {
    id: dialog
    required property var store
    required property int maximumSnippets
    signal notificationRequested(string message, int timeout)

    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)

    title: isBackup ? i18n("Backup Snippets") : i18n("Restore Snippets")
    modal: true
    standardButtons: isBackup ? Dialog.Close : Dialog.Ok | Dialog.Cancel

    // Load only the fixed, trusted optional module; a missing module must
    // not prevent ordinary clipboard backup/restore or widget installation.
    property var fileBackend: null
    readonly property bool fileAccessAvailable: fileBackend !== null
    property url pendingOverwriteUrl
    property string pendingOverwriteText

    Component.onCompleted: {
        try {
            fileBackend = Qt.createQmlObject(
                "import io.github.fooftilly.kopypast.fileio 1.0; BackupFile {}",
                dialog, "OptionalBackupFile")
        } catch (error) {
            fileBackend = null
        }
    }

    property bool isBackup: true
    property string backupContent: store.configurationValid
        ? backupFormat.encode(store.snippets)
        : store.configValue

    BackupFormat {
        id: backupFormat
    }
    property bool isValid: !isBackup && textArea.text !== ""

    function showNotification(message, timeout = 3000) {
        notificationRequested(message, timeout)
    }

    function updateAcceptButton() {
        var button = standardButton(Dialog.Ok)
        if (button)
            button.enabled = isValid
    }

    onAboutToShow: {
        // Take a fresh snapshot for every opening. A restore edit or clear
        // must not break a binding needed by a later backup.
        textArea.text = isBackup ? backupContent : ""
        updateAcceptButton()
    }

    onOpened: {
        updateAcceptButton()
        if (!isBackup)
            textArea.forceActiveFocus()
    }

    onClosed: {
        filePicker.close()
        overwriteDialog.close()
        pendingOverwriteText = ""
        pendingOverwriteUrl = ""
        textArea.clear()
    }
    onIsValidChanged: updateAcceptButton()

    onAccepted: {
        if (isBackup)
            return

        var decoded = backupFormat.decode(textArea.text)
        if (decoded.status !== "ok") {
            showNotification(decoded.status === "unsupported-version"
                ? i18n("Unsupported backup version")
                : i18n("Invalid backup format"))
            return
        }

        var result = store.restoreBackup(decoded.content, maximumSnippets, decoded.preserveIdentity)
        switch (result.status) {
        case "invalid-config":
            showNotification(i18n("Invalid snippet configuration"))
            break
        case "invalid-format":
            showNotification(i18n("Invalid backup format"))
            break
        case "invalid-record":
            showNotification(i18n("Invalid snippet format"))
            break
        case "id-conflict":
            showNotification(i18n("Backup conflicts with an existing snippet. No snippets were restored."))
            break
        case "empty":
            showNotification(i18n("Backup contains no snippets"))
            break
        case "duplicates":
            showNotification(i18n("All snippets are duplicates"))
            break
        case "limit":
            showNotification(i18n("Cannot restore snippets: maximum limit (%1) reached",
                                  maximumSnippets))
            break
        case "partial":
            showNotification(i18np("Only restored %1 snippet due to maximum limit",
                                   "Only restored %1 snippets due to maximum limit",
                                   result.count))
            break
        case "restored":
            if (result.duplicates > 0) {
                showNotification(i18np("Restored %1 snippet, skipped %2 duplicate(s)",
                                       "Restored %1 snippets, skipped %2 duplicate(s)",
                                       result.count, result.duplicates))
            } else {
                showNotification(i18np("Successfully restored %1 snippet",
                                       "Successfully restored %1 snippets",
                                       result.count))
            }
            break
        }
    }

    function reportFileError(status) {
        switch (status) {
        case "too-large":
            showNotification(i18n("Backup file exceeds the 16 MiB size limit"))
            break
        case "invalid-utf8":
        case "invalid-utf16":
            showNotification(i18n("Backup file contains invalid Unicode text"))
            break
        case "invalid-path":
            showNotification(i18n("Select a local regular file"))
            break
        default:
            showNotification(i18n("Could not read or write the backup file"))
        }
    }

    function readBackupFile(url) {
        if (!fileAccessAvailable || !visible || isBackup)
            return
        const result = fileBackend.read(url)
        if (result.status === "ok")
            textArea.text = result.text
        else
            reportFileError(result.status)
    }

    function writeBackupFile(url, text, replaceExisting = false) {
        if (!fileAccessAvailable || !visible || !isBackup)
            return
        const result = fileBackend.write(url, text, replaceExisting)
        if (result.status === "ok") {
            showNotification(i18n("Backup file saved"))
        } else if (result.status === "exists" && !replaceExisting) {
            pendingOverwriteUrl = url
            pendingOverwriteText = text
            overwriteDialog.open()
        } else {
            reportFileError(result.status)
        }
    }

    FileDialog {
        id: filePicker
        title: dialog.isBackup ? i18n("Save backup file") : i18n("Open backup file")
        fileMode: dialog.isBackup ? FileDialog.SaveFile : FileDialog.OpenFile
        nameFilters: [i18n("JSON files (*.json)"), i18n("All files (*)")]
        defaultSuffix: dialog.isBackup ? "json" : ""
        // Always let our own explicit confirmation handle replacement.
        options: dialog.isBackup ? FileDialog.DontConfirmOverwrite : 0
        onAccepted: {
            if (dialog.isBackup)
                dialog.writeBackupFile(selectedFile, textArea.text)
            else
                dialog.readBackupFile(selectedFile)
        }
    }

    Dialog {
        id: overwriteDialog
        objectName: "backupOverwriteDialog"
        parent: dialog.contentItem
        anchors.centerIn: parent
        width: Math.min(parent.width, Kirigami.Units.gridUnit * 24)
        title: i18n("Replace existing backup?")
        modal: true
        standardButtons: Dialog.Yes | Dialog.Cancel
        contentItem: Label {
            text: i18n("The selected file already exists. Replace its contents?")
            wrapMode: Text.Wrap
        }
        onAccepted: dialog.writeBackupFile(dialog.pendingOverwriteUrl, dialog.pendingOverwriteText, true)
        onClosed: {
            dialog.pendingOverwriteUrl = ""
            dialog.pendingOverwriteText = ""
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Label {
            Layout.fillWidth: true
            text: isBackup
                ? i18n("Copy and save the contents below to back up your snippets:")
                : i18n("Paste the backup contents below to restore your snippets:")
            wrapMode: Text.Wrap
            color: Kirigami.Theme.textColor
        }

        Button {
            objectName: "backupFileButton"
            visible: dialog.fileAccessAvailable
            text: dialog.isBackup ? i18n("Save to file") : i18n("Open file")
            icon.name: dialog.isBackup ? "document-save" : "document-open"
            onClicked: filePicker.open()
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.smallSpacing

            TextArea {
                id: textArea
                width: parent.width
                readOnly: isBackup
                objectName: "backupText"
                text: ""
                placeholderText: !isBackup ? i18n("Backup Contents") : ""
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
            }
        }
    }

    ToolButton {
        visible: isBackup
        parent: textArea
        anchors {
            top: parent.top
            right: parent.right
            margins: Kirigami.Units.smallSpacing
        }
        property bool copied: false
        icon.name: copied ? "dialog-ok" : "edit-copy"
        icon.color: copied ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.textColor
        display: ToolButton.IconOnly
        flat: true
        ToolTip.text: i18n("Copy")
        ToolTip.visible: hovered
        ToolTip.delay: Kirigami.Units.toolTipDelay

        onClicked: {
            KirigamiPrivate.CopyHelperPrivate.copyTextToClipboard(textArea.text)
            copied = true
            resetTimer.restart()
        }

        Timer {
            id: resetTimer
            interval: 2000
            onTriggered: parent.copied = false
        }

        Behavior on icon.color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    ToolButton {
        visible: !isBackup && textArea.text.length === 0
        parent: textArea
        anchors {
            top: parent.top
            right: parent.right
            margins: Kirigami.Units.smallSpacing
        }
        icon.name: "edit-paste"
        icon.color: Kirigami.Theme.textColor
        display: ToolButton.IconOnly
        flat: true
        ToolTip.text: i18n("Paste")
        ToolTip.visible: hovered
        ToolTip.delay: Kirigami.Units.toolTipDelay

        onClicked: {
            textArea.paste()
        }
    }
}