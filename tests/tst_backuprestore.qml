/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "BackupRestore"

    property var store

    Component {
        id: modelComponent
        Local.SnippetModel {}
    }

    function init() {
        store = createTemporaryObject(modelComponent, this)
        verify(store !== null)
        store.loadFromConfig('[{"title":"Existing","text":"Keep me","usageCount":3,"isNew":false}]')
    }

    function cleanup() {
        store = null
    }

    function test_rejectInvalidBackup_data() {
        return [
            { tag: "broken-json", content: "[", status: "invalid-format" },
            { tag: "not-array", content: "{}", status: "invalid-format" },
            { tag: "empty-array", content: "[]", status: "empty" },
            { tag: "null", content: "[null]", status: "invalid-record" },
            { tag: "numeric-title", content: '[{"title":123,"text":"text"}]', status: "invalid-record" },
            { tag: "object-text", content: '[{"title":"A","text":{}}]', status: "invalid-record" },
            { tag: "empty-title", content: '[{"title":"","text":"text"}]', status: "invalid-record" },
            { tag: "negative-count", content: '[{"title":"A","text":"text","usageCount":-1}]', status: "invalid-record" },
            { tag: "fractional-count", content: '[{"title":"A","text":"text","usageCount":1.5}]', status: "invalid-record" },
            { tag: "string-count", content: '[{"title":"A","text":"text","usageCount":"1"}]', status: "invalid-record" },
            { tag: "bad-id", content: '[{"title":"A","text":"text","id":12}]', status: "invalid-record" },
            { tag: "bad-flag", content: '[{"title":"A","text":"text","isNew":"false"}]', status: "invalid-record" },
            { tag: "invalid-last", content: '[{"title":"A","text":"valid"},null]', status: "invalid-record" }
        ]
    }

    function test_rejectInvalidBackup(data) {
        const before = store.configValue
        compare(store.restoreBackup(data.content, 50).status, data.status)
        compare(store.configValue, before)
        compare(store.count, 1)
        compare(store.get(0).title, "Existing")
    }

    function test_legacyAndMetadata() {
        const result = store.restoreBackup('[{"title":"A","text":"one"},{"title":"B","text":"two","usageCount":4,"isNew":true}]', 50)
        compare(result.status, "restored")
        compare(result.count, 2)
        compare(store.get(1).usageCount, 0)
        compare(store.get(1).isNew, false)
        compare(store.get(2).usageCount, 4)
        compare(store.get(2).isNew, true)
        compare(JSON.parse(store.configValue), store.snippets)
    }

    function test_duplicatesAndLimit() {
        const result = store.restoreBackup('[{"title":"Existing","text":"Keep me"},{"title":"A","text":"one"},{"title":"A","text":"one"},{"title":"B","text":"two"}]', 3)
        compare(result.status, "restored")
        compare(result.duplicates, 2)
        compare(result.count, 2)
        compare(store.count, 3)
        compare(store.get(1).title, "A")
        compare(store.get(2).title, "B")
    }

    function test_partialAndFull() {
        const result = store.restoreBackup('[{"title":"A","text":"one"},{"title":"B","text":"two"}]', 2)
        compare(result.status, "partial")
        compare(result.count, 1)
        const before = store.configValue
        compare(store.restoreBackup('[{"title":"B","text":"two"}]', 2).status, "limit")
        compare(store.configValue, before)
        compare(store.restoreBackup('[{"title":"A","text":"one"}]', 2).status, "duplicates")
        compare(store.configValue, before)
    }
}
