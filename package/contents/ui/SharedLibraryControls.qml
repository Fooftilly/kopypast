/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Selects the library for one widget. Creating or joining checks the
// library immediately; the widget switches when the settings are applied.
// Logic lives in LibrarySelection; this file is presentation only.
ColumnLayout {
    id: controls

    // Optional native SharedLibrary instance; null when not installed.
    property var backend: null
    // The pending selection (cfg_sharedLibrary); empty means this widget only.
    property string selectedLibrary: ""
    // Validated local records copied into a newly created library.
    property var localRecords: []
    property bool localRecordsValid: true
    // Item that hosts the modal dialog, normally the settings page.
    property Item dialogParent: controls
    signal selectionRequested(string name)

    readonly property bool available: backend !== null
    readonly property bool shared: selectedLibrary !== ""

    LibraryStatusText { id: statusText }
    LibrarySelection {
        id: selection
        backend: controls.backend
        localRecords: controls.localRecords
        localRecordsValid: controls.localRecordsValid
        onSelectionRequested: function(name) {
            shareDialog.close()
            controls.selectionRequested(name)
        }
    }
    readonly property string errorText: selection.errorStatus === "invalid-local"
        ? i18n("This widget's snippet data is invalid. Back it up and repair it before sharing.")
        : selection.errorStatus === "" ? "" : statusText.message(selection.errorStatus)

    RowLayout {
        Layout.fillWidth: true

        Label {
            Layout.fillWidth: true
            objectName: "librarySummary"
            text: controls.shared
                ? i18n("Snippets: shared library “%1”", controls.selectedLibrary)
                : i18n("Snippets: this widget only")
            textFormat: Text.PlainText
            elide: Text.ElideRight
        }

        Button {
            objectName: "shareLibraryButton"
            visible: !controls.shared
            enabled: controls.available
            icon.name: "folder-cloud"
            text: i18n("Share…")
            ToolTip.text: controls.available
                ? i18n("Use one snippet library in several widgets")
                : i18n("Requires the optional native module")
            ToolTip.visible: hovered
            ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: {
                selection.errorStatus = ""
                shareDialog.open()
            }
        }

        Button {
            objectName: "leaveLibraryButton"
            visible: controls.shared
            icon.name: "edit-undo"
            text: i18n("Stop sharing")
            onClicked: selection.leaveLibrary()
        }
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        objectName: "sharedModeNotice"
        visible: controls.shared
        type: Kirigami.MessageType.Information
        text: i18n("Apply the settings to make this widget use the shared library. This widget's own snippets are kept and return when you stop sharing.")
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        objectName: "libraryError"
        visible: controls.errorText !== "" && !shareDialog.visible
        type: Kirigami.MessageType.Error
        text: controls.errorText
    }

    Dialog {
        id: shareDialog
        objectName: "shareLibraryDialog"
        parent: controls.dialogParent
        anchors.centerIn: parent
        width: Math.min(parent.width, Kirigami.Units.gridUnit * 26)
        modal: true
        title: i18n("Share Snippets")
        standardButtons: Dialog.Cancel

        onOpened: nameField.forceActiveFocus()

        ColumnLayout {
            anchors.fill: parent

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: i18n("Widgets that use the same library name show and edit the same snippets. Libraries are stored in your user data folder as plain-text backup files.")
            }

            TextField {
                id: nameField
                objectName: "libraryNameField"
                Layout.fillWidth: true
                placeholderText: i18n("Library name, for example work")
                validator: RegularExpressionValidator {
                    regularExpression: /[a-z0-9][a-z0-9_-]{0,63}/
                }
            }

            Label {
                Layout.fillWidth: true
                visible: controls.errorText !== ""
                text: controls.errorText
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.negativeTextColor
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight

                Button {
                    objectName: "createLibraryButton"
                    text: i18n("Create from these snippets")
                    enabled: nameField.acceptableInput && controls.localRecordsValid
                    onClicked: selection.createLibrary(nameField.text)
                }

                Button {
                    objectName: "joinLibraryButton"
                    text: i18n("Join existing")
                    enabled: nameField.acceptableInput
                    onClicked: selection.joinLibrary(nameField.text)
                }
            }
        }
    }
}
