/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

FittedDialog {
    id: dialog
    title: i18n("Fill template fields")
    modal: true
    focus: true
    standardButtons: Dialog.Ok | Dialog.Cancel
    closePolicy: Popup.CloseOnEscape

    required property var processor
    property string snippetId: ""
    property string templateText: ""
    property var fieldNames: []
    property var values: ({})
    property var previewTime: new Date()
    property var previewLocale: Qt.locale()
    readonly property string resolvedText: processor.processVariables(templateText, previewTime, previewLocale, values)
    signal copyRequested(string snippetId, string resolvedText)

    function openTemplate(id, text, names) {
        snippetId = id
        templateText = text
        fieldNames = names.slice()
        var initial = {}
        for (var i = 0; i < fieldNames.length; i++)
            initial[fieldNames[i]] = ""
        values = initial
        previewTime = new Date()
        previewLocale = Qt.locale()
        open()
    }

    function setValue(name, value) {
        if (fieldNames.indexOf(name) < 0)
            return
        var updated = Object.assign({}, values)
        updated[name] = value
        values = updated
    }

    onOpened: {
        var first = fields.itemAt(0)
        if (first)
            first.focusField()
    }
    onAccepted: {
        // Capture before closing clears the form; defer copy until the dialog
        // has started closing, so an immediate panel close cannot reject it.
        const id = snippetId
        const text = resolvedText
        Qt.callLater(function() { dialog.copyRequested(id, text) })
    }
    onClosed: {
        snippetId = ""
        templateText = ""
        fieldNames = []
        values = ({})
    }

    ScrollView {
        clip: true
        contentWidth: availableWidth
        implicitHeight: Math.min(form.implicitHeight, Kirigami.Units.gridUnit * 23)

        ColumnLayout {
            id: form
            width: parent.width
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                id: fields
                model: dialog.fieldNames

                delegate: ColumnLayout {
                    required property string modelData
                    Layout.fillWidth: true
                    function focusField() {
                        field.forceActiveFocus()
                    }

                    Label {
                        text: modelData
                        textFormat: Text.PlainText
                    }

                    TextField {
                        id: field
                        objectName: "templateField_" + modelData
                        Layout.fillWidth: true
                        Accessible.name: modelData
                        text: dialog.values[modelData] || ""
                        onTextEdited: dialog.setValue(modelData, text)
                    }
                }
            }

            Label {
                text: i18n("Resolved text")
                font.bold: true
            }

            TextArea {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 6
                readOnly: true
                selectByMouse: true
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.Wrap
                objectName: "resolvedTemplatePreview"
                text: dialog.resolvedText
            }
        }
    }
}
