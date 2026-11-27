/*
    SPDX-FileCopyrightText: 2025 Vladimir Kosolapov
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigami.private as KirigamiPrivate

Dialog {
    id: dialog
    parent: snippetsPage

    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)

    title: isBackup ? i18n("Backup Snippets") : i18n("Restore Snippets")
    modal: true
    standardButtons: isBackup ? Dialog.Close : Dialog.Ok | Dialog.Cancel

    property bool isBackup: true
    property string backupContent: snippetModel.configurationValid
        ? JSON.stringify(snippetModel.snippets, null, 2)
        : snippetModel.configValue
    property bool isValid: !isBackup && textArea.text !== ""
    property bool initializing: true

    function showNotification(message, timeout = 3000) {
        applicationWindow().showPassiveNotification(message, timeout)
    }

    onOpened: {
        if (!isBackup) {
            initializing = true
            standardButton(Dialog.Ok).enabled = false
            textArea.forceActiveFocus()
        }
    }

    onVisibleChanged: {
        if (visible && !isBackup && initializing) {
            standardButton(Dialog.Ok).enabled = false
            initializing = false
        }
        if (!visible && !isBackup) {
            textArea.clear()
        }
    }

    onIsValidChanged: {
        standardButton(Dialog.Ok).enabled = isValid
    }

    onAccepted: {
        if (isBackup)
            return

        var result = snippetModel.restoreBackup(textArea.text, plasmoid.configuration.maxSnippets)
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
        case "empty":
            showNotification(i18n("Backup contains no snippets"))
            break
        case "duplicates":
            showNotification(i18n("All snippets are duplicates"))
            break
        case "limit":
            showNotification(i18n("Cannot restore snippets: maximum limit (%1) reached",
                                  plasmoid.configuration.maxSnippets))
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

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.smallSpacing

            TextArea {
                id: textArea
                width: parent.width
                readOnly: isBackup
                text: isBackup ? backupContent : ""
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