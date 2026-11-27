/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "PopupCloseController"
    Local.PopupCloseController { id: controller }
    SignalSpy { id: closed; target: controller; signalName: "closeRequested" }

    function init() {
        controller.expanded = false
        controller.panel = true
        controller.pinned = false
        controller.delay = 80
        controller.expanded = true
        closed.clear()
    }

    function test_delayedClose() {
        controller.requestClose()
        verify(controller.pending)
        tryCompare(closed, "count", 1)
        verify(!controller.pending)
    }

    function test_reopenCancels() {
        controller.requestClose()
        controller.expanded = false
        controller.expanded = true
        verify(!controller.pending)
        wait(160)
        compare(closed.count, 0)
    }

    function test_pinCancels() {
        controller.requestClose()
        controller.pinned = true
        controller.pinned = false
        verify(!controller.pending)
        wait(160)
        compare(closed.count, 0)
    }

    function test_immediateAndNonPanel() {
        controller.delay = 0
        controller.requestClose()
        compare(closed.count, 1)
        controller.panel = false
        controller.requestClose()
        compare(closed.count, 1)
        controller.panel = true
        controller.pinned = true
        controller.requestClose()
        compare(closed.count, 1)
    }
}
