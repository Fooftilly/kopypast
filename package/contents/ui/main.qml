/*
    SPDX-FileCopyrightText: 2025 Vladimir Kosolapov
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.kirigami.private as KirigamiPrivate
import "." as Local

PlasmoidItem {
    id: root

    preferredRepresentation: isPanel ? compactRepresentation : fullRepresentation
    // Plasma owns registration, conflict handling and activation of per-instance shortcuts.
    activationTogglesExpanded: true

    property bool isCopied: false
    property string searchQuery: ""
    readonly property bool isPanel: plasmoid.formFactor === 2 || plasmoid.formFactor === 3
    readonly property var closeDelayValues: [0, 700, 1000, 1500]
    hideOnWindowDeactivate: !plasmoid.configuration.isPinned

    Local.SnippetModel {
        id: snippetModel
        Component.onCompleted: {
            loadFromConfig(plasmoid.configuration.snippets)
            if (plasmoid.configuration.sortMode === -1) {
                plasmoid.configuration.sortMode = plasmoid.configuration.sortByUsage ? 1 : 0
                plasmoid.configuration.sortByUsage = false
            }
        }
        onConfigValueChanged: plasmoid.configuration.snippets = configValue
    }

    Local.VariableHandler {
        id: variableHandler
        processingEnabled: plasmoid.configuration.handleVariables
    }

    Connections {
        target: plasmoid.configuration
        function onSnippetsChanged() {
            snippetModel.loadFromConfig(plasmoid.configuration.snippets)
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
            if (!snippet || templateDialog.visible)
                return

            var names = variableHandler.placeholderNames(snippet.text)
            if (names.length > 0) {
                closeController.cancelPending()
                templateDialog.openTemplate(snippet.id, snippet.text, names)
                return
            }

            copyResolvedSnippet(snippet.id, variableHandler.processVariables(snippet.text))
        }

        function copyResolvedSnippet(snippetId, processedText) {
            if (!snippetModel.configurationValid || snippetModel.indexOfId(snippetId) < 0)
                return

            KirigamiPrivate.CopyHelperPrivate.copyTextToClipboard(processedText)
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

        Local.TemplateFieldsDialog {
            id: templateDialog
            parent: popupContent
            anchors.centerIn: parent
            width: Math.min(parent.width, Kirigami.Units.gridUnit * 28)
            height: Math.min(implicitHeight, parent.height)
            processor: variableHandler
            onCopyRequested: function(snippetId, resolvedText) {
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

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: snippetList
                property var filteredModel: snippetModel.getFilteredSnippets(
                    plasmoid.configuration.sortMode, root.searchQuery)

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
                    if (!templateDialog.visible && plasmoid.configuration.useKbdNavigation && currentIndex >= 0 && currentIndex < count)
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
                    visible: snippetModel.count === 0 && !root.searchQuery
                    width: parent.width - (Kirigami.Units.largeSpacing * 4)
                    icon.source: Kirigami.Theme.textColor.hslLightness < 0.5
                        ? Qt.resolvedUrl("../icons/io.github.fooftilly.kopypast-light.svg").toString()
                        : Qt.resolvedUrl("../icons/io.github.fooftilly.kopypast-dark.svg").toString()
                    text: i18n("No snippets available")
                    explanation: i18n("Add snippets in the settings")
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    visible: snippetList.count === 0 && root.searchQuery
                    width: parent.width - (Kirigami.Units.largeSpacing * 4)
                    icon.name: "search"
                    icon.color: Kirigami.Theme.textColor
                    text: i18n("No matching snippets")
                    explanation: i18n("Try a different search term")
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
                                text: modelData.title
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Label {
                                Layout.fillWidth: true
                                text: modelData.text
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
                    if (root.isPanel && templateDialog.visible)
                        templateDialog.reject()
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
                    text: i18np("%1 snippet", "%1 snippets", snippetModel.count)
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