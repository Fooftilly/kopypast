/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls

// A dialog centred on its parent that stays inside the window. Styles such
// as org.kde.desktop give popups window margins; Qt moves a popup inside
// them but does not shrink it, so a dialog as large as the applet popup
// would be pushed past the window's right and bottom edges.
Dialog {
    id: dialog
    // Size wanted when the window has room. A negative height uses the
    // dialog's implicit height.
    property real preferredWidth: implicitWidth
    property real preferredHeight: -1

    readonly property var hostWindow: parent ? parent.Window.window : null
    readonly property real availableWindowWidth: hostWindow
        ? hostWindow.width - Math.max(0, leftMargin) - Math.max(0, rightMargin) : preferredWidth
    readonly property real availableWindowHeight: hostWindow
        ? hostWindow.height - Math.max(0, topMargin) - Math.max(0, bottomMargin)
        : (preferredHeight < 0 ? implicitHeight : preferredHeight)

    anchors.centerIn: parent
    width: Math.max(0, Math.min(preferredWidth, availableWindowWidth))
    height: Math.max(0, Math.min(preferredHeight < 0 ? implicitHeight : preferredHeight, availableWindowHeight))
}
