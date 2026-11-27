/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "SnippetModel"

    property var store

    Component {
        id: modelComponent
        Local.SnippetModel {}
    }

    function init() {
        store = createTemporaryObject(modelComponent, this)
        verify(store !== null)
    }

    function cleanup() {
        store = null
    }

    function sample(title, text) {
        return { title: title, text: text, usageCount: 0 }
    }

    function test_loadLegacyData() {
        store.loadFromConfig('[{"title":"Example","text":"first\\nsecond"}]')
        compare(store.count, 1)
        compare(store.get(0).title, "Example")
        compare(store.get(0).text, "first\nsecond")
        compare(store.get(0).usageCount, 0)
        compare(store.get(0).isNew, false)
    }

    function test_appendAndRoundTrip() {
        const text = "Line 1\nLine 2 — čćž"
        store.append(sample("Prompt", text))
        compare(store.count, 1)
        compare(store.get(0).isNew, true)

        const restored = createTemporaryObject(modelComponent, this)
        verify(restored !== null)
        restored.loadFromConfig(store.configValue)
        compare(restored.count, 1)
        compare(restored.get(0).title, "Prompt")
        compare(restored.get(0).text, text)
        compare(restored.get(0).isNew, true)
    }

    function test_editMoveAndRemove() {
        store.append(sample("A", "one"))
        store.append(sample("B", "two"))
        store.append(sample("C", "three"))

        store.move(2, 0)
        compare(store.get(0).title, "C")
        compare(store.get(1).title, "A")
        compare(store.get(2).title, "B")

        store.set(1, sample("A edited", "updated"))
        store.remove(2)
        compare(store.count, 2)
        compare(store.get(1).text, "updated")
        compare(JSON.parse(store.configValue).length, 2)
    }

    function test_usageSortPreservesManualOrder() {
        store.append(sample("A", "one"))
        store.append(sample("B", "two"))
        store.append(sample("C", "three"))

        store.incrementUsage(1)
        store.incrementUsage(1)
        store.incrementUsage(2)

        compare(store.get(1).usageCount, 2)
        compare(store.get(1).isNew, false)
        compare(store.get(0).isNew, true)

        const sorted = store.getSortedSnippets(true)
        compare(sorted[0].title, "B")
        compare(sorted[1].title, "C")
        compare(sorted[2].title, "A")
        compare(store.getSortedSnippets(false)[0].title, "A")
        compare(JSON.parse(store.configValue)[0].title, "A")
    }

    function test_markAsUsed() {
        store.append(sample("A", "one"))
        store.markAsUsed(0)
        compare(store.get(0).isNew, false)
        compare(JSON.parse(store.configValue)[0].isNew, false)
    }
}
