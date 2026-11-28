/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Dialog {
    id: dialog
    required property var store
    // False when changes are written to storage at once, as for a shared
    // library, rather than kept until the widget settings are applied.
    property bool saveOnApply: true
    title: i18n("Manage categories and tags")
    modal: true
    standardButtons: Dialog.Close
    readonly property string kind: kindBox.currentIndex === 0 ? "category" : "tag"
    readonly property var names: {
        // Explicit dependency on the immutable record array.
        var records = store.snippets
        return store.metadataNames(kind)
    }
    readonly property bool validName: replacement.text.trim() !== ""
        && !/[\r\n]/.test(replacement.text)
        && (kind !== "tag" || !replacement.text.includes(","))
    onOpened: {
        kindBox.currentIndex = 0
        replacement.clear()
    }
    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing
        ComboBox {
            id: kindBox
            objectName: "metadataKind"
            Layout.fillWidth: true
            model: [i18n("Categories"), i18n("Tags")]
            Accessible.name: i18n("Group type")
            onActivated: replacement.clear()
        }
        ComboBox {
            id: nameBox
            objectName: "metadataName"
            Layout.fillWidth: true
            model: dialog.names
            Accessible.name: i18n("Existing group")
            onActivated: replacement.clear()
        }
        TextField {
            id: replacement
            objectName: "metadataReplacement"
            Layout.fillWidth: true
            placeholderText: i18n("New name")
            Accessible.name: placeholderText
        }
        Label {
            Layout.fillWidth: true
            objectName: "metadataPersistenceNote"
            wrapMode: Text.Wrap
            text: dialog.saveOnApply
                ? i18n("Changes affect all snippets with the selected name. Removing a group keeps its snippets. Apply the widget settings to save.")
                : i18n("Changes affect all snippets with the selected name. Removing a group keeps its snippets. Changes are saved to the shared library immediately.")
        }
        RowLayout {
            Button {
                objectName: "renameMetadataButton"
                text: i18n("Rename")
                enabled: nameBox.currentIndex >= 0 && dialog.validName
                onClicked: {
                    if (dialog.store.renameMetadata(dialog.kind, nameBox.currentText, replacement.text))
                        replacement.clear()
                }
            }
            Button {
                objectName: "removeMetadataButton"
                text: i18n("Remove")
                enabled: nameBox.currentIndex >= 0
                onClicked: {
                    confirmRemoval.groupKind = dialog.kind
                    confirmRemoval.groupName = nameBox.currentText
                    confirmRemoval.open()
                }
            }
        }
    }

    Dialog {
        id: confirmRemoval
        objectName: "confirmMetadataRemoval"
        property string groupKind: ""
        property string groupName: ""
        parent: dialog.contentItem
        anchors.centerIn: parent
        modal: true
        title: i18n("Remove group?")
        standardButtons: Dialog.Ok | Dialog.Cancel
        contentItem: Label {
            width: Kirigami.Units.gridUnit * 18
            text: i18n("Remove \"%1\" from all snippets?", confirmRemoval.groupName)
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        onAccepted: {
            dialog.store.renameMetadata(groupKind, groupName, "")
            replacement.clear()
        }
    }
}
