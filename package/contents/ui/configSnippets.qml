/*
    SPDX-FileCopyrightText: 2025 Vladimir Kosolapov
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils
import org.kde.kirigami as Kirigami
import "." as Local

SimpleKCM {
    id: snippetsPage

    property string cfg_snippets: "[]"
    property string cfg_snippetsDefault: "[]"

    Binding {
        target: snippetModel
        property: "configValue"
        value: cfg_snippets
    }

    Local.SnippetModel {
        id: snippetModel
        onConfigValueChanged: cfg_snippets = configValue
    }

    function duplicateSnippet(index) {
        var originalSnippet = snippetModel.get(index)
        var duplicatedSnippet = {
            title: originalSnippet.title + " " + i18n("(copy)"),
            text: originalSnippet.text,
            category: originalSnippet.category,
            tags: originalSnippet.tags,
            usageCount: 0
        }
        snippetModel.append(duplicatedSnippet)

        var title = originalSnippet.title.length > 20
            ? originalSnippet.title.substring(0, 20) + "..."
            : originalSnippet.title

        applicationWindow().showPassiveNotification(
            i18n("Snippet \"%1\" duplicated", title), 3000
        )
    }

    function deleteSnippet(index) {
        var deletion = snippetModel.removeForUndo(index)
        if (!deletion)
            return

        var title = deletion.item.title.length > 20
            ? deletion.item.title.substring(0, 20) + "..."
            : deletion.item.title

        applicationWindow().showPassiveNotification(
            i18n("Snippet \"%1\" deleted", title), 5000, i18n("Undo"), function() {
                snippetModel.undoRemoval(deletion)
            }
        )
    }

    ColumnLayout {
        anchors.fill: parent

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - (Kirigami.Units.largeSpacing * 4)
                visible: snippetModel.count === 0
                icon.source: Kirigami.Theme.textColor.hslLightness < 0.5
                    ? Qt.resolvedUrl("../icons/io.github.fooftilly.kopypast-light.svg").toString()
                    : Qt.resolvedUrl("../icons/io.github.fooftilly.kopypast-dark.svg").toString()
                text: snippetModel.configurationValid ? i18n("No snippets added") : i18n("Invalid snippet configuration")
                explanation: snippetModel.configurationValid
                    ? i18n("Add your first snippet using the button below")
                    : i18n("Back up the original data before resetting the configuration.")
            }

            ScrollView {
                anchors.fill: parent
                visible: snippetModel.count > 0

                ListView {
                    id: snippetList
                    model: snippetModel.snippets
                    clip: true

                    move: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: Kirigami.Units.longDuration
                            easing.type: Easing.InOutQuad
                        }
                    }

                    moveDisplaced: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: Kirigami.Units.longDuration
                            easing.type: Easing.InOutQuad
                        }
                    }

                    delegate: Item {
                        id: wrapper
                        width: ListView.view.width
                        height: snippetDelegate.implicitHeight

                        ItemDelegate {
                            id: snippetDelegate
                            width: parent.width
                            implicitHeight: Math.max(Kirigami.Units.iconSizes.large + Kirigami.Units.smallSpacing,
                                contentItem.implicitHeight + topPadding + bottomPadding)

                            contentItem: RowLayout {
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.ListItemDragHandle {
                                    listItem: snippetDelegate
                                    listView: snippetList
                                    visible: snippetList.count > 1
                                    onMoveRequested: function(oldIndex, newIndex) {
                                        snippetModel.move(oldIndex, newIndex)
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true

                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        textFormat: Text.PlainText
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.text
                                        textFormat: Text.PlainText
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        opacity: 0.7
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        visible: modelData.category !== "" || modelData.tags.length > 0
                                        text: [modelData.category, modelData.tags.join(", ")].filter(function(value) { return value !== "" }).join(" · ")
                                        textFormat: Text.PlainText
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        font: Kirigami.Theme.smallFont
                                        opacity: 0.7
                                    }
                                }

                                RowLayout {
                                    spacing: Kirigami.Units.smallSpacing
                                    Layout.rightMargin: Kirigami.Units.smallSpacing

                                    ToolButton {
                                        icon.name: modelData.favorite ? "rating" : "rating-unrated"
                                        display: ToolButton.IconOnly
                                        checkable: true
                                        checked: modelData.favorite
                                        onClicked: snippetModel.setFavorite(modelData.id, !modelData.favorite)
                                        Accessible.name: modelData.favorite ? i18n("Remove from favorites") : i18n("Add to favorites")
                                        ToolTip.text: Accessible.name
                                        ToolTip.visible: hovered
                                        ToolTip.delay: Kirigami.Units.toolTipDelay
                                    }

                                    ToolButton {
                                        icon.name: "document-edit"
                                        display: ToolButton.IconOnly
                                        onClicked: snippetDialog.editSnippet(index)
                                        ToolTip.text: i18n("Edit")
                                        ToolTip.visible: hovered
                                        ToolTip.delay: Kirigami.Units.toolTipDelay
                                    }

                                    ToolButton {
                                        icon.name: "edit-duplicate"
                                        display: ToolButton.IconOnly
                                        onClicked: duplicateSnippet(index)
                                        enabled: snippetModel.configurationValid && snippetModel.count < plasmoid.configuration.maxSnippets
                                        ToolTip.text: enabled ? i18n("Duplicate") : i18n("Maximum limit reached")
                                        ToolTip.visible: hovered
                                        ToolTip.delay: Kirigami.Units.toolTipDelay
                                    }

                                    ToolButton {
                                        icon.name: "edit-delete"
                                        display: ToolButton.IconOnly
                                        onClicked: deleteSnippet(index)
                                        ToolTip.text: i18n("Delete")
                                        ToolTip.visible: hovered
                                        ToolTip.delay: Kirigami.Units.toolTipDelay
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing

            Button {
                icon.name: "list-add"
                text: i18n("Add Snippet")
                onClicked: snippetDialog.createSnippet()
                enabled: snippetModel.configurationValid && snippetModel.count < plasmoid.configuration.maxSnippets
                ToolTip.text: i18n("Maximum limit reached")
                ToolTip.visible: !enabled && hovered
                ToolTip.delay: Kirigami.Units.toolTipDelay
            }

            Button {
                visible: !snippetModel.configurationValid
                icon.name: "edit-clear"
                text: i18n("Reset invalid data")
                onClicked: recoveryDialog.open()
            }

            Button {
                icon.name: "tag"
                text: i18n("Manage groups")
                enabled: snippetModel.configurationValid && snippetModel.count > 0
                onClicked: metadataDialog.open()
            }

            Item { Layout.fillWidth: true }

            Button {
                icon.name: "document-export"
                text: i18n("Backup")
                onClicked: {
                    backupDialog.isBackup = true
                    backupDialog.open()
                }
            }

            Button {
                icon.name: "document-import"
                text: i18n("Restore")
                enabled: snippetModel.configurationValid
                onClicked: {
                    backupDialog.isBackup = false
                    backupDialog.open()
                }
            }
        }
    }

    Dialog {
        id: recoveryDialog
        parent: snippetsPage
        anchors.centerIn: parent
        width: Math.min(snippetsPage.width, Kirigami.Units.gridUnit * 25)
        title: i18n("Reset invalid snippet data?")
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: snippetModel.resetInvalidConfiguration()

        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            text: i18n("This clears the stored snippet data when you apply the settings. Copy the original data using Backup before continuing.")
        }
    }

    Local.MetadataDialog {
        id: metadataDialog
        parent: snippetsPage
        anchors.centerIn: parent
        width: Math.min(snippetsPage.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 28)
        store: snippetModel
    }

    SnippetDialog {
        id: snippetDialog
        parent: snippetsPage
        width: Math.min(snippetsPage.width - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 30)
        height: Math.min(snippetsPage.height - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 30)
    }

    BackupDialog {
        id: backupDialog
        parent: snippetsPage
        width: Math.min(snippetsPage.width - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 30)
        height: Math.min(snippetsPage.height - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 30)
    }
}