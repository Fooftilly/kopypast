/*
    SPDX-FileCopyrightText: 2025 Vladimir Kosolapov
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Dialog {
    id: dialog
    required property var store
    required property int maximumSnippets
    property string defaultTemplate: ""
    property bool processVariables: true
    property string editId: ""

    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)

    title: editId === "" ? i18n("Add Snippet") : i18n("Edit Snippet")
    modal: true
    standardButtons: Dialog.Ok | Dialog.Cancel

    property bool isValid: store.configurationValid && titleField.text !== "" && textArea.text !== ""
        && (editId === "" ? store.count < maximumSnippets : store.indexOfId(editId) >= 0)
    property alias titleText: titleField.text
    property alias snippetText: textArea.text
    property bool previewing: false
    property string resolvedPreview: ""

    VariableHandler {
        id: previewHandler
        processingEnabled: dialog.processVariables
    }

    function updateAcceptButton() {
        var button = standardButton(Dialog.Ok)
        if (button)
            button.enabled = isValid
    }

    Component.onCompleted: updateAcceptButton()
    onIsValidChanged: updateAcceptButton()

    onOpened: {
        updateAcceptButton()
        previewing = false
        resolvedPreview = ""
        titleField.forceActiveFocus()
    }
    onClosed: {
        previewing = false
        resolvedPreview = ""
    }

    function createSnippet() {
        if (!store.configurationValid || store.count >= maximumSnippets)
            return
        editId = ""
        titleText = ""
        categoryField.text = ""
        tagsField.text = ""
        snippetText = defaultTemplate
        open()
    }

    function editSnippet(index) {
        var item = store.get(index)
        if (!store.configurationValid || !item)
            return
        editId = item.id
        titleText = item.title
        categoryField.text = item.category
        tagsField.text = item.tags.join(", ")
        snippetText = item.text
        open()
    }

    onAccepted: {
        if (!isValid)
            return
        var item = {
            title: titleText,
            text: snippetText,
            category: categoryField.text,
            tags: tagsField.text.split(",")
        }
        if (editId === "") {
            store.append(item)
        } else {
            var index = store.indexOfId(editId)
            if (index < 0)
                return
            store.set(index, item)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        TextField {
            id: titleField
            Layout.fillWidth: true
            placeholderText: i18n("Snippet Title")
            onAccepted: {
                if (!previewing)
                    textArea.forceActiveFocus()
            }
        }

        TextField {
            id: categoryField
            Layout.fillWidth: true
            placeholderText: i18n("Category (optional)")
            Accessible.name: placeholderText
        }

        TextField {
            id: tagsField
            Layout.fillWidth: true
            placeholderText: i18n("Tags (comma-separated, optional)")
            Accessible.name: placeholderText
        }

        ScrollView {
            visible: !dialog.previewing
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing

            TextArea {
                id: textArea
                width: parent.width
                placeholderText: i18n("Snippet Text")
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
            }

            ToolButton {
                visible: textArea.text.length === 0
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

        ScrollView {
            visible: dialog.previewing
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing

            TextArea {
                width: parent.width
                readOnly: true
                selectByMouse: true
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.Wrap
                text: dialog.resolvedPreview
            }
        }

        Button {
            visible: dialog.processVariables || dialog.previewing
            enabled: dialog.previewing || textArea.text.length > 0
            text: dialog.previewing ? i18n("Back to editing") : i18n("Preview resolved text")
            icon.name: dialog.previewing ? "document-edit" : "document-preview"
            onClicked: {
                if (dialog.previewing) {
                    dialog.previewing = false
                    dialog.resolvedPreview = ""
                    textArea.forceActiveFocus()
                } else {
                    dialog.resolvedPreview = previewHandler.processVariables(textArea.text)
                    dialog.previewing = true
                }
            }
        }

        Button {
            icon.name: "code-context"
            text: i18n("Available Variables")
            flat: true
            hoverEnabled: false
            Layout.leftMargin: -Kirigami.Units.smallSpacing
            visible: dialog.processVariables

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.WhatsThisCursor
                onEntered: toolTip.visible = true
                onExited: toolTip.visible = false
            }

            ToolTip {
                id: toolTip
                delay: Kirigami.Units.toolTipDelay
                timeout: -1

                contentItem: GridLayout {
                    columns: 2
                    columnSpacing: Kirigami.Units.largeSpacing
                    rowSpacing: Kirigami.Units.smallSpacing

                    Label { text: "{DATE}"; font.family: "monospace" }
                    Label { text: i18n("current date in local format"); opacity: 0.7 }

                    Label { text: "{TIME}"; font.family: "monospace" }
                    Label { text: i18n("current time in local format"); opacity: 0.7 }

                    Label { text: "{DATETIME}"; font.family: "monospace" }
                    Label { text: i18n("current date and time"); opacity: 0.7 }

                    Label { text: "{ISO_DATE}"; font.family: "monospace" }
                    Label { text: i18n("date in YYYY-MM-DD format"); opacity: 0.7 }

                    Label { text: "{ISO_TIME}"; font.family: "monospace" }
                    Label { text: i18n("time in HH:mm:ss format"); opacity: 0.7 }

                    Label { text: "{ISO_TIME_DASHED}"; font.family: "monospace" }
                    Label { text: i18n("time in HH-mm-ss format"); opacity: 0.7 }

                    Label { text: "{ISO_DATETIME}"; font.family: "monospace" }
                    Label { text: i18n("full ISO date and time"); opacity: 0.7 }

                    Label { text: "{YEAR}"; font.family: "monospace" }
                    Label { text: i18n("current year (4 digits)"); opacity: 0.7 }

                    Label { text: "{MONTH}"; font.family: "monospace" }
                    Label { text: i18n("current month (01-12)"); opacity: 0.7 }

                    Label { text: "{DAY}"; font.family: "monospace" }
                    Label { text: i18n("current day (01-31)"); opacity: 0.7 }

                    Label { text: "{HOUR}"; font.family: "monospace" }
                    Label { text: i18n("current hour (00-23)"); opacity: 0.7 }

                    Label { text: "{HOUR12}"; font.family: "monospace" }
                    Label { text: i18n("current hour (01-12)"); opacity: 0.7 }

                    Label { text: "{MINUTE}"; font.family: "monospace" }
                    Label { text: i18n("current minute (00-59)"); opacity: 0.7 }

                    Label { text: "{SECOND}"; font.family: "monospace" }
                    Label { text: i18n("current second (00-59)"); opacity: 0.7 }
                
                    Label { text: "{AMPM}"; font.family: "monospace" }
                    Label { text: i18n("AM/PM marker"); opacity: 0.7 }
                }
            }
        }
    }
}