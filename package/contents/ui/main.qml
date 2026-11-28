/*
    SPDX-FileCopyrightText: 2025 Vladimir Kosolapov
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "." as Local

PlasmoidItem {
    id: root

    preferredRepresentation: isPanel ? compactRepresentation : fullRepresentation
    // Plasma owns registration, conflict handling and activation of per-instance shortcuts.
    activationTogglesExpanded: true

    property bool isCopied: false
    property bool localStorageLimitReached: false
    property string searchQuery: ""
    readonly property bool isPanel: plasmoid.formFactor === 2 || plasmoid.formFactor === 3
    readonly property var closeDelayValues: [0, 700, 1000, 1500]
    hideOnWindowDeactivate: !plasmoid.configuration.isPinned

    // Optional native backend for an opt-in shared library. Without the
    // module, a saved shared selection stays blocked instead of silently
    // writing to this widget's own snippets.
    property var sharedLibraryBackend: null

    Local.LibraryStorageRouter {
        id: libraryRouter
        backend: root.sharedLibraryBackend
        enforceLocalConfigBudget: true
        onLocalConfigBudgetRejected: root.localStorageLimitReached = true
        Component.onCompleted: {
            try {
                root.sharedLibraryBackend = Qt.createQmlObject(
                    "import io.github.fooftilly.kopypast.fileio 1.0; SharedLibrary {}",
                    libraryRouter, "OptionalSharedLibrary")
            } catch (error) {
                root.sharedLibraryBackend = null
            }
            localConfig = plasmoid.configuration.snippets
            restoreSelection(plasmoid.configuration.sharedLibrary)
            if (plasmoid.configuration.sortMode === -1) {
                plasmoid.configuration.sortMode = plasmoid.configuration.sortByUsage ? 1 : 0
                plasmoid.configuration.sortByUsage = false
            }
        }
        onLocalConfigChanged: {
            root.localStorageLimitReached = false
            plasmoid.configuration.snippets = localConfig
        }
    }

    Local.ClipboardWriter {
        id: clipboardWriter
    }

    // The store the popup shows: local snippets, or the selected library.
    readonly property var snippetModel: libraryRouter.activeStore
    readonly property bool storeWritable: libraryRouter.writable

    Local.LibraryStatusText {
        id: libraryStatusText
    }

    Local.SearchHighlighter {
        id: searchHighlighter
    }

    Local.VariableHandler {
        id: variableHandler
        processingEnabled: plasmoid.configuration.handleVariables
    }

    Connections {
        target: plasmoid.configuration
        function onSnippetsChanged() {
            libraryRouter.localConfig = plasmoid.configuration.snippets
        }
        function onSharedLibraryChanged() {
            libraryRouter.restoreSelection(plasmoid.configuration.sharedLibrary)
        }
    }

    Timer {
        id: resetTimer
        interval: 2000
        onTriggered: root.isCopied = false
    }

    Local.PopupCloseController {
        id: closeController
        expanded: root.expanded
        pinned: plasmoid.configuration.isPinned
        panel: root.isPanel
        delay: closeDelayValues[Math.max(0, Math.min(closeDelayValues.length - 1, plasmoid.configuration.closeAfterCopy))]
        onCloseRequested: root.expanded = false
    }

    compactRepresentation: Item {
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: Plasmoid.title
        Accessible.onPressAction: Plasmoid.activated()

        Keys.onPressed: function(event) {
            switch (event.key) {
            case Qt.Key_Space:
            case Qt.Key_Enter:
            case Qt.Key_Return:
            case Qt.Key_Select:
                Plasmoid.activated()
                event.accepted = true
                break
            }
        }

        Kirigami.Icon {
            anchors.fill: parent
            source: plasmoid.configuration.useSymbolicIcon
                ? (Kirigami.Theme.textColor.hslLightness < 0.5
                    ? Qt.resolvedUrl("../icons/io.github.fooftilly.kopypast-light.svg").toString()
                    : Qt.resolvedUrl("../icons/io.github.fooftilly.kopypast-dark.svg").toString())
                : Qt.resolvedUrl("../icons/io.github.fooftilly.kopypast.svg").toString()
            active: mouseArea.containsMouse
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: ColumnLayout {
        id: popupContent

        property var lastDeletion: null
        // Incremented on every library switch. A template opened for one
        // library must not copy or record use in another.
        property int libraryGeneration: 0
        property int templateGeneration: -1
        // An undo record belongs to the store it was removed from.
        Connections {
            target: libraryRouter
            function onSelectedLibraryChanged() {
                popupContent.libraryGeneration++
                popupContent.lastDeletion = null
                if (templateDialog.visible)
                    templateDialog.reject()
                if (editor.visible)
                    editor.storeReplaced = true
                if (deleteDialog.visible)
                    deleteDialog.reject()
                if (actionsMenu.visible)
                    actionsMenu.close()
            }
        }
        readonly property bool managing: editor.visible || deleteDialog.visible || actionsMenu.visible
        property string categoryKey: ""
        property string tagKey: ""
        readonly property var tagOptions: categoryFilter.tagOptions(snippetModel.snippets, i18n("All tags"), i18n("Untagged"))
        onTagOptionsChanged: {
            if (!tagOptions.some(function(option) { return option.key === tagKey }))
                tagKey = ""
        }
        readonly property var categoryOptions: categoryFilter.options(snippetModel.snippets, i18n("All categories"), i18n("Uncategorized"))

        Local.CategoryFilter {
            id: categoryFilter
        }

        onCategoryOptionsChanged: {
            if (!categoryOptions.some(function(option) { return option.key === categoryKey }))
                categoryKey = ""
        }

        function focusOnOpen() {
            if (!root.isPanel || !root.expanded || !visible)
                return
            if (searchField.enabled)
                searchField.forceActiveFocus()
            else if (plasmoid.configuration.useKbdNavigation)
                snippetList.forceActiveFocus()
        }

        // The full representation may be created lazily, after expanded changes.
        Component.onCompleted: Qt.callLater(focusOnOpen)
        onVisibleChanged: {
            if (visible)
                Qt.callLater(focusOnOpen)
        }

        function copySnippet(snippet) {
            if (!snippet || templateDialog.visible || managing)
                return

            var names = variableHandler.placeholderNames(snippet.text)
            if (names.length > 0) {
                closeController.cancelPending()
                templateGeneration = libraryGeneration
                templateDialog.openTemplate(snippet.id, snippet.text, names)
                return
            }

            copyResolvedSnippet(snippet.id, variableHandler.processVariables(snippet.text))
        }

        function copyResolvedSnippet(snippetId, processedText) {
            if (!snippetModel.configurationValid || snippetModel.indexOfId(snippetId) < 0)
                return

            // Count a use and close only after the text reached the clipboard.
            if (!clipboardWriter.copyText(processedText)) {
                console.warn("Kopypast: no clipboard helper is available")
                return
            }
            snippetModel.recordUse(snippetId)

            if (plasmoid.configuration.isPinned || !isPanel) {
                root.isCopied = true
                resetTimer.restart()
            }

            if (isPanel && !plasmoid.configuration.isPinned) {
                closeController.requestClose()
            } else if (plasmoid.configuration.clearSearchOnCopy) {
                searchField.clear()
                root.searchQuery = ""
            }
        }

        function showEditor(id) {
            closeController.cancelPending()
            if (id === "")
                editor.createSnippet()
            else
                editor.editSnippet(snippetModel.indexOfId(id))
        }

        Local.SnippetDialog {
            id: editor
            parent: popupContent
            preferredWidth: Math.min(parent.width, Kirigami.Units.gridUnit * 28)
            preferredHeight: Math.min(parent.height, Kirigami.Units.gridUnit * 30)
            store: snippetModel
            maximumSnippets: plasmoid.configuration.maxSnippets
            defaultTemplate: plasmoid.configuration.defaultTemplate
            processVariables: plasmoid.configuration.handleVariables
            recoverStore: function() { return libraryRouter.refresh() }
            recoverAvailable: libraryRouter.shared
        }

        Menu {
            id: actionsMenu
            property string snippetId: ""
            readonly property int snippetIndex: snippetModel.indexOfId(snippetId)
            MenuItem {
                text: i18n("Edit")
                enabled: actionsMenu.snippetIndex >= 0 && root.storeWritable
                onTriggered: popupContent.showEditor(actionsMenu.snippetId)
            }
            MenuItem {
                text: i18n("Duplicate")
                enabled: actionsMenu.snippetIndex >= 0 && root.storeWritable
                    && snippetModel.count < plasmoid.configuration.maxSnippets
                onTriggered: {
                    var item = snippetModel.get(actionsMenu.snippetIndex)
                    if (item && snippetModel.count < plasmoid.configuration.maxSnippets)
                        snippetModel.append({title: item.title + " " + i18n("(copy)"),
                            text: item.text, category: item.category, tags: item.tags})
                }
            }
            MenuItem {
                text: i18n("Delete")
                enabled: actionsMenu.snippetIndex >= 0 && root.storeWritable
                onTriggered: {
                    deleteDialog.confirm(actionsMenu.snippetId)
                }
            }
        }

        Local.FittedDialog {
            id: deleteDialog
            parent: popupContent
            preferredWidth: Math.min(parent.width, Kirigami.Units.gridUnit * 22)
            property string snippetId: ""
            // The record as the user saw it when asked to confirm.
            property string confirmedFields: ""
            property bool changedBeforeConfirmation: false
            title: i18n("Delete snippet?")
            modal: true
            standardButtons: Dialog.Ok | Dialog.Cancel
            contentItem: Label {
                text: deleteDialog.changedBeforeConfirmation
                    ? i18n("This snippet changed in another widget. Delete the updated snippet? You can undo the deletion from the toolbar.")
                    : i18n("Delete the selected snippet? You can undo the deletion from the toolbar.")
                wrapMode: Text.Wrap
            }
            function confirm(id, changed = false) {
                var item = snippetModel.get(snippetModel.indexOfId(id))
                if (!item)
                    return
                snippetId = id
                confirmedFields = snippetModel.editableFields(item)
                changedBeforeConfirmation = changed
                open()
            }
            onAccepted: {
                var result = snippetModel.removeConfirmed(snippetId, confirmedFields)
                if (result.status === "ok")
                    popupContent.lastDeletion = result.deletion
                else if (result.status === "changed")
                    Qt.callLater(confirm, snippetId, true)
            }
        }

        Local.TemplateFieldsDialog {
            id: templateDialog
            parent: popupContent
            preferredWidth: Math.min(parent.width, Kirigami.Units.gridUnit * 28)
            preferredHeight: Math.min(implicitHeight, parent.height)
            processor: variableHandler
            onCopyRequested: function(snippetId, resolvedText) {
                if (popupContent.templateGeneration !== popupContent.libraryGeneration)
                    return
                popupContent.copyResolvedSnippet(snippetId, resolvedText)
            }
        }

        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 18
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: Kirigami.Units.gridUnit * 28
        Layout.maximumWidth: isPanel ? Kirigami.Units.gridUnit * 28 : root.width
        Layout.maximumHeight: isPanel ? Kirigami.Units.gridUnit * 42 : root.height

        Keys.forwardTo: [snippetList]
        focus: !plasmoid.configuration.showSearchField || !searchField.enabled

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            objectName: "sharedLibraryStatus"
            visible: libraryRouter.shared && libraryStatusText.message(libraryRouter.status) !== ""
            type: libraryRouter.status === "conflict" || libraryRouter.status === "busy"
                ? Kirigami.MessageType.Warning : Kirigami.MessageType.Error
            text: libraryStatusText.message(libraryRouter.status)
            actions: [
                Kirigami.Action {
                    icon.name: "view-refresh"
                    text: i18n("Refresh")
                    // Refresh rereads the file; it never overwrites it.
                    onTriggered: libraryRouter.refresh()
                }
            ]
        }

        Label {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: root.localStorageLimitReached
            text: i18n("Change not saved: local snippet storage is too large. Reduce the data or back up the snippets.")
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.negativeTextColor
        }

        Kirigami.SearchField {
            id: searchField
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            placeholderText: i18n("Search for snippets...")
            onTextChanged: root.searchQuery = text
            selectByMouse: true
            persistentSelection: false
            Keys.onEscapePressed: {
                clear()
                root.expanded = false
            }
            Keys.onPressed: function(event) {
                if (!plasmoid.configuration.useKbdNavigation)
                    return
                if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                    snippetList.selectRelative(event.key === Qt.Key_Up ? -1 : 1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    snippetList.handleSelection()
                    event.accepted = true
                }
            }
            visible: plasmoid.configuration.showSearchField
            enabled: visible && snippetModel.count > 0
            focus: plasmoid.configuration.showSearchField && plasmoid.configuration.useKbdNavigation
        }

        ComboBox {
            id: categoryBox
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            visible: popupContent.categoryOptions.length > 1
            model: popupContent.categoryOptions
            textRole: "label"
            valueRole: "key"
            currentIndex: Math.max(0, popupContent.categoryOptions.findIndex(function(option) {
                return option.key === popupContent.categoryKey
            }))
            Accessible.name: i18n("Filter by category")
            onActivated: function(index) {
                popupContent.categoryKey = popupContent.categoryOptions[index].key
            }
        }

        ComboBox {
            id: tagBox
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            visible: popupContent.tagOptions.length > 1
            model: popupContent.tagOptions
            textRole: "label"
            valueRole: "key"
            currentIndex: Math.max(0, popupContent.tagOptions.findIndex(function(option) {
                return option.key === popupContent.tagKey
            }))
            Accessible.name: i18n("Filter by tag")
            onActivated: function(index) {
                popupContent.tagKey = popupContent.tagOptions[index].key
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: snippetList
                property var filteredModel: categoryFilter.applyTag(
                    categoryFilter.apply(snippetModel.getFilteredSnippets(plasmoid.configuration.sortMode, root.searchQuery,
                            plasmoid.configuration.fuzzySearch),
                        popupContent.categoryKey), popupContent.tagKey)

                model: filteredModel
                clip: true
                focus: plasmoid.configuration.useKbdNavigation && !searchField.enabled
                keyNavigationEnabled: plasmoid.configuration.useKbdNavigation
                currentIndex: -1

                function resetSelection() {
                    currentIndex = count > 0 ? 0 : -1
                }

                function selectRelative(direction) {
                    if (count === 0) {
                        currentIndex = -1
                        return
                    }
                    currentIndex = currentIndex < 0 ? 0 : Math.max(0, Math.min(count - 1, currentIndex + direction))
                    positionViewAtIndex(currentIndex, ListView.Contain)
                }

                function handleSelection() {
                    if (!templateDialog.visible && !popupContent.managing && plasmoid.configuration.useKbdNavigation && currentIndex >= 0 && currentIndex < count)
                        popupContent.copySnippet(filteredModel[currentIndex])
                }

                onCountChanged: resetSelection()
                onModelChanged: resetSelection()
                Component.onCompleted: resetSelection()
                Keys.enabled: plasmoid.configuration.useKbdNavigation
                Keys.onEnterPressed: handleSelection()
                Keys.onReturnPressed: handleSelection()

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    visible: snippetModel.count === 0
                    width: parent.width - (Kirigami.Units.largeSpacing * 4)
                    icon.source: Kirigami.Theme.textColor.hslLightness < 0.5
                        ? Qt.resolvedUrl("../icons/io.github.fooftilly.kopypast-light.svg").toString()
                        : Qt.resolvedUrl("../icons/io.github.fooftilly.kopypast-dark.svg").toString()
                    text: i18n("No snippets available")
                    explanation: i18n("Add snippets in the settings")
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    visible: snippetModel.count > 0 && snippetList.count === 0
                    width: parent.width - (Kirigami.Units.largeSpacing * 4)
                    icon.name: "search"
                    icon.color: Kirigami.Theme.textColor
                    text: i18n("No matching snippets")
                    explanation: i18n("Try a different search term, category or tag")
                }

                delegate: Kirigami.SwipeListItem {
                    id: snippetDelegate
                    width: ListView.view.width
                    implicitHeight: Kirigami.Units.iconSizes.large + Kirigami.Units.smallSpacing
                    highlighted: plasmoid.configuration.useKbdNavigation && ListView.isCurrentItem

                    contentItem: RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        ColumnLayout {
                            Layout.fillWidth: true

                            Label {
                                Layout.fillWidth: true
                                readonly property var displayText: searchHighlighter.highlight(modelData.title, root.searchQuery)
                                text: displayText.text
                                textFormat: displayText.highlighted ? Text.StyledText : Text.PlainText
                                Accessible.name: modelData.title
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Label {
                                Layout.fillWidth: true
                                readonly property var displayText: searchHighlighter.highlight(modelData.text, root.searchQuery)
                                text: displayText.text
                                textFormat: displayText.highlighted ? Text.StyledText : Text.PlainText
                                Accessible.name: modelData.text
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                opacity: 0.7
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                visible: !plasmoid.configuration.showOnlyTitles
                            }
                        }

                        Kirigami.Icon {
                            visible: modelData.favorite
                            source: "rating"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            Accessible.name: i18n("Favorite")
                        }

                        ToolButton {
                            icon.name: "overflow-menu"
                            display: ToolButton.IconOnly
                            Accessible.name: i18n("Manage snippet")
                            ToolTip.text: Accessible.name
                            ToolTip.visible: hovered
                            enabled: root.storeWritable
                            onClicked: {
                                closeController.cancelPending()
                                actionsMenu.snippetId = modelData.id
                                actionsMenu.popup()
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.rightMargin: Kirigami.Units.smallSpacing
                            implicitWidth: badgeLabel.implicitWidth + Kirigami.Units.cornerRadius * 2
                            implicitHeight: Math.round(Kirigami.Units.iconSizes.sizeForLabels * 1.3)
                            radius: Kirigami.Units.cornerRadius
                            color: Kirigami.Theme.positiveTextColor
                            visible: plasmoid.configuration.showNewBadges && modelData.isNew

                            Label {
                                id: badgeLabel
                                anchors.centerIn: parent
                                text: i18n("New!")
                                font.bold: true
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            }
                        }
                    }

                    onClicked: popupContent.copySnippet(modelData)
                }
            }
        }

        Connections {
            target: root
            function onExpandedChanged() {
                if (root.expanded) {
                    snippetList.resetSelection()
                    Qt.callLater(popupContent.focusOnOpen)
                } else {
                    if (root.isPanel) {
                        if (templateDialog.visible)
                            templateDialog.reject()
                        if (editor.visible)
                            editor.reject()
                        if (deleteDialog.visible)
                            deleteDialog.reject()
                        if (actionsMenu.visible)
                            actionsMenu.close()
                    }
                    if (plasmoid.configuration.isPinned)
                        return
                    snippetList.currentIndex = -1
                    snippetList.positionViewAtBeginning()
                    if (plasmoid.configuration.clearSearchOnCopy) {
                        searchField.clear()
                        root.searchQuery = ""
                    }
                }
            }
        }

        ToolBar {
            Layout.fillWidth: true
            implicitHeight: Kirigami.Units.iconSizes.medium + Kirigami.Units.largeSpacing
            position: ToolBar.Footer
            visible: plasmoid.configuration.showToolbarPanel

            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                Label {
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                    text: libraryRouter.shared
                        ? i18np("%1 snippet in “%2”", "%1 snippets in “%2”", snippetModel.count, libraryRouter.selectedLibrary)
                        : i18np("%1 snippet", "%1 snippets", snippetModel.count)
                    textFormat: Text.PlainText
                    opacity: 0.6
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: i18n("Copied!")
                    opacity: root.isCopied ? 1 : 0
                    color: Kirigami.Theme.textColor

                    Behavior on opacity {
                        NumberAnimation { duration: Kirigami.Units.shortDuration }
                    }
                }

                ToolButton {
                    icon.name: "list-add"
                    display: ToolButton.IconOnly
                    Accessible.name: i18n("Add Snippet")
                    ToolTip.text: Accessible.name
                    ToolTip.visible: hovered
                    enabled: root.storeWritable && snippetModel.count < plasmoid.configuration.maxSnippets
                    onClicked: popupContent.showEditor("")
                }

                ToolButton {
                    icon.name: "edit-undo"
                    display: ToolButton.IconOnly
                    Accessible.name: i18n("Undo deletion")
                    ToolTip.text: Accessible.name
                    ToolTip.visible: hovered
                    visible: popupContent.lastDeletion !== null
                    enabled: visible && root.storeWritable && snippetModel.count < plasmoid.configuration.maxSnippets
                    onClicked: {
                        if (snippetModel.undoRemoval(popupContent.lastDeletion))
                            popupContent.lastDeletion = null
                    }
                }

                ToolButton {
                    id: configButton
                    icon.name: "configure"
                    display: ToolButton.IconOnly
                    onClicked: plasmoid.internalAction("configure").trigger()
                    ToolTip.text: i18n("Configure")
                    ToolTip.visible: hovered
                    ToolTip.delay: Kirigami.Units.toolTipDelay
                    KeyNavigation.right: pinButton
                }

                ToolButton {
                    id: pinButton
                    icon.name: "window-pin"
                    display: ToolButton.IconOnly
                    checkable: true
                    checked: plasmoid.configuration.isPinned
                    down: checked
                    onToggled: plasmoid.configuration.isPinned = checked
                    ToolTip.text: i18n("Keep Open")
                    ToolTip.visible: hovered
                    ToolTip.delay: Kirigami.Units.toolTipDelay
                    KeyNavigation.left: configButton
                    visible: isPanel
                    enabled: visible
                }
            }
        }
    }
}