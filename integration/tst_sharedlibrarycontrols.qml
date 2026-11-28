/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Controls
import QtTest
import "../package/contents/ui" as Local

Item {
    id: fixture
    width: 640
    height: 480

    function i18n(text, arg) {
        return arg === undefined ? text : text.replace("%1", String(arg))
    }

    property string selected: ""

    // In-memory stand-in for the optional native backend.
    QtObject {
        id: fake
        property var files: ({})
        function readSnapshot(name) {
            return files[name] === undefined ? {status:"missing"}
                : {status:"ok", text:files[name], revision:"r1"}
        }
        function create(name, content) {
            if (files[name] !== undefined)
                return {status:"exists"}
            files[name] = content
            return {status:"ok", revision:"r1"}
        }
    }

    Local.SharedLibraryControls {
        id: controls
        width: parent.width
        backend: fake
        selectedLibrary: fixture.selected
        localRecords: [{id:"a", title:"Local", text:"body", category:"", tags:[]}]
        dialogParent: fixture
        onSelectionRequested: function(name) { fixture.selected = name }
    }
    Local.SharedLibraryControls {
        id: withoutModule
        y: 200
        width: parent.width
        dialogParent: fixture
    }

    TestCase {
        name: "SharedLibraryControls"
        when: windowShown

        function control(parent, name) {
            const item = findChild(parent, name)
            verify(item !== null, name)
            return item
        }

        function typeName(text) {
            const field = control(controls, "libraryNameField")
            field.forceActiveFocus()
            field.selectAll()
            for (const letter of text)
                keyClick(letter)
            tryCompare(field, "text", text)
        }

        function init() {
            fake.files = {}
            fixture.selected = ""
        }

        function cleanup() {
            const dialog = control(controls, "shareLibraryDialog")
            if (dialog.visible)
                dialog.close()
            tryCompare(dialog, "visible", false)
        }

        function test_createSwitchesSelection() {
            compare(control(controls, "librarySummary").text, "Snippets: this widget only")
            mouseClick(control(controls, "shareLibraryButton"))
            tryCompare(control(controls, "shareLibraryDialog"), "opened", true)
            const create = control(controls, "createLibraryButton")
            verify(!create.enabled)
            typeName("team")
            verify(create.enabled)
            mouseClick(create)
            compare(fixture.selected, "team")
            verify(fake.files["team"].indexOf("Local") >= 0)
            tryCompare(control(controls, "shareLibraryDialog"), "visible", false)
            compare(control(controls, "librarySummary").text, "Snippets: shared library “team”")
            verify(control(controls, "leaveLibraryButton").visible)
            mouseClick(control(controls, "leaveLibraryButton"))
            compare(fixture.selected, "")
        }

        function test_joinMissingKeepsDialogOpen() {
            mouseClick(control(controls, "shareLibraryButton"))
            tryCompare(control(controls, "shareLibraryDialog"), "opened", true)
            typeName("absent")
            mouseClick(control(controls, "joinLibraryButton"))
            compare(fixture.selected, "")
            verify(control(controls, "shareLibraryDialog").visible)
            compare(controls.errorText, "The shared library file was not found.")
        }

        function test_invalidNameIsNotAccepted() {
            mouseClick(control(controls, "shareLibraryButton"))
            tryCompare(control(controls, "shareLibraryDialog"), "opened", true)
            const field = control(controls, "libraryNameField")
            field.text = "Team"
            verify(!field.acceptableInput)
            verify(!control(controls, "createLibraryButton").enabled)
            verify(!control(controls, "joinLibraryButton").enabled)
        }

        function test_withoutNativeModule() {
            verify(!control(withoutModule, "shareLibraryButton").enabled)
        }
    }
}
