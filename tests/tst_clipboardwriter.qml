/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "ClipboardWriter"

    component FakeHelper: QtObject {
        property var copied: []
        property bool succeeds: true
        function copyText(text) {
            copied = copied.concat([text])
            return succeeds
        }
    }

    FakeHelper { id: publicHelper }
    FakeHelper { id: privateHelper }
    Local.ClipboardWriter { id: both; preferred: publicHelper; fallback: privateHelper }
    Local.ClipboardWriter { id: onlyFallback; fallback: privateHelper; loaded: true }
    // No module can be loaded here: neither the native module nor Kirigami
    // is installed in the plain Qt test job.
    Local.ClipboardWriter { id: none; loaded: true }

    function init() {
        publicHelper.copied = []
        publicHelper.succeeds = true
        privateHelper.copied = []
    }

    function test_prefersPublicApi() {
        compare(both.backendName, "native")
        verify(both.copyText(""))
        verify(both.copyText("a\nb"))
        compare(publicHelper.copied, ["", "a\nb"])
        compare(privateHelper.copied, [])
    }

    function test_reportsFailure() {
        publicHelper.succeeds = false
        verify(!both.copyText("text"))
        // A failed public copy is reported, not retried with another helper.
        compare(privateHelper.copied, [])
    }

    function test_fallback() {
        compare(onlyFallback.backendName, "kirigami-private")
        verify(onlyFallback.copyText("text"))
        compare(privateHelper.copied, ["text"])
    }

    function test_noHelper() {
        compare(none.backendName, "")
        verify(!none.copyText("text"))
    }
}
