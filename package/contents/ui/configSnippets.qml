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
    property string cfg_sharedLibrary: ""
    property string cfg_sharedLibraryDefault: ""

    // Optional native module; ordinary local snippets work without it.
    // The share controls and the snippet list each get their own backend,
    // because a backend holds a single library watch.
    property var sharedLibraryBackend: null
    property var listBackend: null
    function createBackend(name) {
        try {
            return Qt.createQmlObject(
                "import io.github.fooftilly.kopypast.fileio 1.0; SharedLibrary {}",
                snippetsPage, name)
        } catch (error) {
            return null
        }
    }
    Component.onCompleted: {
        sharedLibraryBackend = createBackend("OptionalSharedLibrary")
        listBackend = createBackend("OptionalSharedLibraryList")
        libraryRouter.restoreSelection(cfg_sharedLibrary)
    }
    onCfg_sharedLibraryChanged: libraryRouter.restoreSelection(cfg_sharedLibrary)
    property bool localStorageLimitReached: false

    // Local snippets follow the page's pending configuration and are saved
    // on Apply. While the page selects a shared library, the list shows that
    // library and each change is written to it at once, as in the popup;
    // the widget's own snippets stay unchanged.
    Binding {
        target: libraryRouter
        property: "localConfig"
        value: cfg_snippets
    }

    Local.LibraryStorageRouter {
        id: libraryRouter
        backend: snippetsPage.listBackend
        enforceLocalConfigBudget: true
        onLocalConfigBudgetRejected: snippetsPage.localStorageLimitReached = true
        onLocalConfigChanged: {
            snippetsPage.localStorageLimitReached = false
            cfg_snippets = localConfig
        }
        onSelectedLibraryChanged: {
            if (snippetDialog.visible)
                snippetDialog.storeReplaced = true
            if (metadataDialog.visible)
                metadataDialog.reject()
            if (backupDialog.visible)
                backupDialog.reject()
            if (recoveryDialog.visible)
                recoveryDialog.reject()
        }
    }

    readonly property var snippetModel: libraryRouter.activeStore
    readonly property bool storeWritable: libraryRouter.writable

    Local.LibraryStatusText {
        id: libraryStatusText
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
        if (!snippetModel.append(duplicatedSnippet))
            return

        var title = originalSnippet.title.length > 20
            ? originalSnippet.title.substring(0, 20) + "..."
            : originalSnippet.title

        applicationWindow().showPassiveNotification(
            i18n("Snippet \"%1\" duplicated", title), 3000
        )
    }

    function deleteSnippet(index) {
        // Undo restores into the store the snippet was removed from.
        var store = snippetModel
        var deletion = store.removeForUndo(index)
        if (!deletion)
            return

        var title = deletion.item.title.length > 20
            ? deletion.item.title.substring(0, 20) + "..."
            : deletion.item.title

        applicationWindow().showPassiveNotification(
            i18n("Snippet \"%1\" deleted", title), 5000, i18n("Undo"), function() {
                if (store === snippetsPage.snippetModel)
                    store.undoRemoval(deletion)
            }
        )
    }

    ColumnLayout {
        anchors.fill: parent

        Local.SharedLibraryControls {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            backend: snippetsPage.sharedLibraryBackend
            selectedLibrary: snippetsPage.cfg_sharedLibrary
            localRecords: libraryRouter.shared ? [] : snippetModel.snippets
            localRecordsValid: !libraryRouter.shared && snippetModel.configurationValid
            dialogParent: snippetsPage
            onSelectionRequested: function(name) {
                snippetsPage.cfg_sharedLibrary = name
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            objectName: "settingsLibraryStatus"
            visible: libraryRouter.shared
            type: libraryStatusText.message(libraryRouter.status) === ""
                ? Kirigami.MessageType.Information
                : libraryRouter.status === "conflict" || libraryRouter.status === "busy"
                    ? Kirigami.MessageType.Warning : Kirigami.MessageType.Error
            text: libraryStatusText.message(libraryRouter.status) !== ""
                ? libraryStatusText.message(libraryRouter.status)
                : i18n("Showing the shared library “%1”. Changes here are saved to it immediately and appear in every widget that uses it.", libraryRouter.selectedLibrary)
            actions: [
                Kirigami.Action {
                    icon.name: "view-refresh"
                    text: i18n("Refresh")
                    visible: libraryStatusText.message(libraryRouter.status) !== ""
                    // Refresh rereads the file; it never overwrites it.
                    onTriggered: libraryRouter.refresh()
                }
            ]
        }

        Label {
            Layout.fillWidth: true
            visible: snippetsPage.localStorageLimitReached
            text: i18n("Change not saved: local snippet storage is too large. Reduce the data or back up the snippets.")
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.negativeTextColor
        }

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
                text: snippetModel.configurationValid || libraryRouter.shared ? i18n("No snippets added") : i18n("Invalid snippet configuration")
                explanation: snippetModel.configurationValid || libraryRouter.shared
                    ? i18n("Add your first snippet using the button below")
                    : i18n("Back up the original data before resetting the configuration.")
            }

            ScrollView {
                anchors.fill: parent
                visible: snippetModel.count > 0

                ListView {
                    id: snippetList
                    objectName: "settingsSnippetList"
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
                                    enabled: snippetsPage.storeWritable
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
                                        enabled: snippetsPage.storeWritable
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
                                        enabled: snippetsPage.storeWritable
                                        ToolTip.text: i18n("Edit")
                                        ToolTip.visible: hovered
                                        ToolTip.delay: Kirigami.Units.toolTipDelay
                                    }

                                    ToolButton {
                                        icon.name: "edit-duplicate"
                                        display: ToolButton.IconOnly
                                        onClicked: duplicateSnippet(index)
                                        enabled: snippetsPage.storeWritable && snippetModel.count < plasmoid.configuration.maxSnippets
                                        ToolTip.text: enabled ? i18n("Duplicate") : i18n("Maximum limit reached")
                                        ToolTip.visible: hovered
                                        ToolTip.delay: Kirigami.Units.toolTipDelay
                                    }

                                    ToolButton {
                                        icon.name: "edit-delete"
                                        display: ToolButton.IconOnly
                                        onClicked: deleteSnippet(index)
                                        enabled: snippetsPage.storeWritable
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
                objectName: "addSnippetButton"
                icon.name: "list-add"
                text: i18n("Add Snippet")
                onClicked: snippetDialog.createSnippet()
                enabled: snippetsPage.storeWritable && snippetModel.count < plasmoid.configuration.maxSnippets
                ToolTip.text: i18n("Maximum limit reached")
                ToolTip.visible: !enabled && hovered
                ToolTip.delay: Kirigami.Units.toolTipDelay
            }

            Button {
                // A shared library is recovered with Refresh, never reset here.
                visible: !libraryRouter.shared && !snippetModel.configurationValid
                icon.name: "edit-clear"
                text: i18n("Reset invalid data")
                onClicked: recoveryDialog.open()
            }

            Button {
                icon.name: "tag"
                text: i18n("Manage groups")
                enabled: snippetsPage.storeWritable && snippetModel.count > 0
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
                enabled: snippetsPage.storeWritable
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
        store: snippetModel
        maximumSnippets: plasmoid.configuration.maxSnippets
        defaultTemplate: plasmoid.configuration.defaultTemplate
        processVariables: plasmoid.configuration.handleVariables
        recoverStore: function() { return libraryRouter.refresh() }
        recoverAvailable: libraryRouter.shared
        width: Math.min(snippetsPage.width - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 30)
        height: Math.min(snippetsPage.height - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 30)
    }

    BackupDialog {
        id: backupDialog
        parent: snippetsPage
        store: snippetModel
        maximumSnippets: plasmoid.configuration.maxSnippets
        onNotificationRequested: function(message, timeout) {
            applicationWindow().showPassiveNotification(message, timeout)
        }
        width: Math.min(snippetsPage.width - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 30)
        height: Math.min(snippetsPage.height - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 30)
    }
}