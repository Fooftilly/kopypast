/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "PersistedSnippetValidation"
    Local.SnippetModel { id: store }

    function init() {
        store.loadFromConfig("[]")
    }

    function test_invalidConfig_data() {
        return [
            {tag: "syntax", raw: "["},
            {tag: "object", raw: "{}"},
            {tag: "null-record", raw: "[null]"},
            {tag: "numeric-title", raw: '[{"title":1,"text":"body"}]'},
            {tag: "invalid-last", raw: '[{"title":"A","text":"body"},null]'},
            {tag: "invalid-count", raw: '[{"title":"A","text":"body","usageCount":-1}]'}
        ]
    }

    function test_invalidConfig(data) {
        store.loadFromConfig(data.raw)
        verify(!store.configurationValid)
        compare(store.count, 0)
        compare(store.getFilteredSnippets(false, "a").length, 0)
        store.append({title: "New", text: "text"})
        store.remove(0)
        store.move(0, 1)
        compare(store.restoreBackup('[{"title":"New","text":"text"}]', 50).status, "invalid-config")
        compare(store.configValue, data.raw)
        compare(store.count, 0)
        verify(store.resetInvalidConfiguration())
        verify(store.configurationValid)
        compare(store.configValue, "[]")
        store.append({title: "Recovered", text: "ok"})
        compare(store.count, 1)
        verify(!store.resetInvalidConfiguration())
        compare(store.get(0).title, "Recovered")
    }

    function test_legacyAndDuplicateIds() {
        store.loadFromConfig('[{"title":"A","text":"one","id":"same"},{"title":"B","text":"two","id":"same"},{"title":"C","text":"three"}]')
        verify(store.configurationValid)
        compare(store.count, 3)
        compare(store.get(0).id, "same")
        verify(store.get(0).id !== store.get(1).id)
        verify(store.get(1).id !== store.get(2).id)
        compare(store.get(2).usageCount, 0)
        compare(store.get(2).isNew, false)
    }

    function test_validExternalReplacement() {
        store.loadFromConfig("[null]")
        verify(!store.configurationValid)
        store.loadFromConfig('[{"title":"Restored","text":"ok"}]')
        verify(store.configurationValid)
        compare(store.get(0).title, "Restored")
    }
}
