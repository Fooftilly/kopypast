/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "SnippetSortModes"
    Local.SnippetModel { id: store }
    Local.SnippetModel { id: restored }

    function init() {
        store.loadFromConfig(JSON.stringify([
            {id: "a", title: "Zulu", text: "match", usageCount: 10, createdAt: 100, lastUsedAt: 200},
            {id: "b", title: "Beta", text: "match", createdAt: 300, lastUsedAt: 100},
            {id: "c", title: "alpha", text: "match", favorite: true, createdAt: 400, lastUsedAt: 0},
            {id: "d", title: "Delta", text: "other", favorite: true},
            {id: "e", title: "alpha", text: "match"}
        ]))
        restored.loadFromConfig("[]")
        verify(store.configurationValid)
    }

    function ids(items) {
        return items.map(function(item) { return item.id })
    }

    function test_order() {
        compare(ids(store.getSortedSnippets(0)), ["c", "d", "a", "b", "e"])
        compare(ids(store.getSortedSnippets(1)), ["c", "d", "a", "b", "e"])
        compare(ids(store.getSortedSnippets(2)), ["c", "d", "a", "b", "e"])
        compare(ids(store.getSortedSnippets(3)), ["c", "d", "b", "a", "e"])
        compare(ids(store.getSortedSnippets(4)), ["c", "d", "e", "b", "a"])
        compare(ids(store.getFilteredSnippets(4, "match")), ["c", "e", "b", "a"])
        compare(ids(store.snippets), ["a", "b", "c", "d", "e"])
        compare(store.get(4).createdAt, null)
        compare(store.get(4).lastUsedAt, null)
    }

    function test_recordUseAndRestore() {
        const before = Date.now()
        store.append({title: "New", text: "body"})
        const id = store.get(store.count - 1).id
        verify(store.get(store.count - 1).createdAt >= before)
        compare(store.get(store.count - 1).lastUsedAt, null)
        store.recordUse("b")
        verify(store.get(1).lastUsedAt >= before)
        compare(ids(store.getSortedSnippets(2)), ["c", "d", "b", "a", "e", id])
        store.set(1, {title: "Edited", text: "body"})
        compare(store.get(1).createdAt, 300)
        verify(store.get(1).lastUsedAt >= before)
        const deletion = store.removeForUndo(1)
        verify(store.undoRemoval(deletion))
        compare(store.get(1).createdAt, 300)
        compare(restored.restoreBackup(store.configValue, 50).status, "restored")
        compare(restored.snippets, store.snippets)
    }

    function test_invalidDates() {
        const before = store.configValue
        compare(store.restoreBackup('[{"title":"Bad","text":"body","createdAt":-1}]', 50).status, "invalid-record")
        compare(store.restoreBackup('[{"title":"Bad","text":"body","lastUsedAt":"now"}]', 50).status, "invalid-record")
        compare(store.configValue, before)
    }
}
