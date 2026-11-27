/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "SnippetFavorites"
    Local.SnippetModel { id: store }
    Local.SnippetModel { id: restored }

    function init() {
        store.loadFromConfig("[]")
        restored.loadFromConfig("[]")
    }

    function append(title, text) {
        store.append({title: title, text: text})
        return store.get(store.count - 1).id
    }

    function ids(items) {
        return items.map(function(item) { return item.id })
    }

    function test_orderAndFilter() {
        const a = append("First", "one")
        const b = append("Favorite B", "two")
        const c = append("Popular", "three")
        const d = append("Favorite D", "four")
        verify(store.setFavorite(b, true))
        verify(store.setFavorite(d, true))
        store.recordUse(c)
        store.recordUse(c)
        store.recordUse(d)
        compare(ids(store.getSortedSnippets(false)), [b, d, a, c])
        compare(ids(store.getSortedSnippets(true)), [d, b, c, a])
        compare(ids(store.getFilteredSnippets(false, "favorite")), [b, d])
        compare(ids(store.getFilteredSnippets(true, "favorite")), [d, b])
        compare(ids(store.getFilteredSnippets(true, "one")), [a])
        compare(ids(store.snippets), [a, b, c, d])
        verify(store.setFavorite(b, false))
        compare(ids(store.getSortedSnippets(false)), [d, a, b, c])
        store.move(3, 0)
        compare(ids(store.snippets), [d, a, b, c])
        compare(ids(store.getSortedSnippets(false)), [d, a, b, c])
    }

    function test_identityAndPersistence() {
        const a = append("Same", "same")
        const b = append("Same", "same")
        verify(store.setFavorite(b, true))
        verify(!store.get(0).favorite)
        verify(store.get(1).favorite)
        store.set(1, {title: "Edited", text: "new"})
        store.recordUse(b)
        verify(store.get(1).favorite)
        compare(store.get(1).usageCount, 1)
        restored.loadFromConfig(store.configValue)
        verify(restored.get(1).favorite)
        compare(restored.get(1).id, b)
        const deletion = store.removeForUndo(1)
        verify(store.undoRemoval(deletion))
        compare(store.get(1).id, b)
        verify(store.get(1).favorite)
        verify(!store.setFavorite("missing", true))
        verify(!store.setFavorite(a, "true"))
        verify(!store.get(0).favorite)
    }

    function test_backupAndLegacy() {
        store.loadFromConfig('[{"title":"Legacy","text":"one"}]')
        verify(store.configurationValid)
        compare(store.get(0).favorite, false)
        const id = store.get(0).id
        verify(store.setFavorite(id, true))
        const result = restored.restoreBackup(store.configValue, 50)
        compare(result.status, "restored")
        compare(restored.get(0).id, id)
        verify(restored.get(0).favorite)
        const before = restored.configValue
        compare(restored.restoreBackup('[{"title":"Bad","text":"value","favorite":"yes"}]', 50).status, "invalid-record")
        compare(restored.configValue, before)
        restored.loadFromConfig('[{"title":"Bad","text":"value","favorite":1}]')
        verify(!restored.configurationValid)
        compare(restored.configValue, '[{"title":"Bad","text":"value","favorite":1}]')
    }
}
