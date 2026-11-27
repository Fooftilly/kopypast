/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

Item {
    id: controller
    visible: false

    property bool expanded: false
    property bool pinned: false
    property bool panel: false
    property int delay: 0
    readonly property bool pending: timer.running
    signal closeRequested()

    onExpandedChanged: timer.stop()
    onPinnedChanged: timer.stop()
    onPanelChanged: timer.stop()
    onDelayChanged: timer.stop()

    function cancelPending() {
        timer.stop()
    }

    function requestClose() {
        if (!expanded || pinned || !panel)
            return
        if (delay > 0)
            timer.restart()
        else
            closeRequested()
    }

    Timer {
        id: timer
        interval: controller.delay
        repeat: false
        onTriggered: {
            if (controller.expanded && !controller.pinned && controller.panel)
                controller.closeRequested()
        }
    }
}
