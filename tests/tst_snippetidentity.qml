/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "SnippetIdentity"

    property var store
    property bool sortByUsage: false
    property string query: ""
    property var visibleSnippets: store ? store.getFilteredSnippets(sortByUsage, query) : []

    Component {
        id: modelComponent
        Local.SnippetModel {}
    }

    function init() {
        store = createTemporaryObject(modelComponent, this)
        verify(store !== null)
        sortByUsage = false
        query = ""
    }

    function cleanup() {
        store = null
    }

    function append(title, text) {
        store.append({title: title, text: text})
        return store.get(store.count - 1).id
    }

    function test_legacyIdsAndPersistence() {
        const legacy = '[{"title":"Same","text":"text"},{"title":"Same","text":"text"}]'
        store.loadFromConfig(legacy)
        const firstId = store.get(0).id
        const secondId = store.get(1).id
        verify(firstId !== secondId)

        const other = createTemporaryObject(modelComponent, this)
        other.loadFromConfig(legacy)
        compare(other.get(0).id, firstId)
        compare(other.get(1).id, secondId)

        store.recordUse(secondId)
        compare(store.get(0).usageCount, 0)
        compare(store.get(1).usageCount, 1)
        store.move(1, 0)
        other.loadFromConfig(store.configValue)
        compare(other.get(0).id, secondId)
        compare(other.get(0).usageCount, 1)
        compare(other.get(1).id, firstId)
    }

    function test_editAndUsage() {
        const firstId = append("Same", "text")
        const secondId = append("Same", "text")

        store.set(0, {title: "Edited", text: "text"})
        compare(store.get(0).id, firstId)
        compare(store.get(0).isNew, true)

        store.recordUse(secondId)
        compare(store.get(0).usageCount, 0)
        compare(store.get(1).usageCount, 1)
        compare(store.get(1).isNew, false)

        compare(store.getSortedSnippets(true)[0].id, secondId)
        compare(store.getSortedSnippets(false)[0].id, firstId)
        store.recordUse(secondId)
        compare(store.getSortedSnippets(true)[0].usageCount, 2)

        store.set(1, {title: "Edited used", text: "new text"})
        compare(store.get(1).id, secondId)
        compare(store.get(1).usageCount, 2)
        compare(store.get(1).isNew, false)
        compare(JSON.parse(store.configValue), store.snippets)
    }

    function test_filteredSelectionAndSortPreference() {
        const firstId = append("Same", "text")
        const secondId = append("Same", "text")
        const unrelatedId = append("Other", "unrelated")
        query = "SAME"
        compare(visibleSnippets.length, 2)
        compare(visibleSnippets[1].id, secondId)

        store.recordUse(visibleSnippets[1].id)
        compare(store.get(0).usageCount, 0)
        compare(store.get(1).usageCount, 1)
        sortByUsage = true
        compare(visibleSnippets[0].id, secondId)
        sortByUsage = false
        compare(visibleSnippets[0].id, firstId)
        store.recordUse(visibleSnippets[1].id)
        sortByUsage = true
        compare(visibleSnippets[0].id, secondId)
        compare(visibleSnippets[0].usageCount, 2)
        compare(store.get(2).id, unrelatedId)
        compare(store.get(2).usageCount, 0)
    }

    function test_undoMultipleDeletions() {
        const a = append("A", "one")
        const b = append("B", "two")
        const c = append("C", "three")
        store.recordUse(b)
        const deletedA = store.removeForUndo(0)
        const deletedB = store.removeForUndo(0)
        compare(store.count, 1)

        verify(store.undoRemoval(deletedA))
        compare(store.get(0).id, a)
        compare(store.get(1).id, c)
        verify(store.undoRemoval(deletedB))
        compare(store.get(0).id, a)
        compare(store.get(1).id, b)
        compare(store.get(1).usageCount, 1)
        compare(store.get(2).id, c)
        verify(!store.undoRemoval(deletedA))
        compare(store.count, 3)
        compare(JSON.parse(store.configValue), store.snippets)
    }

    function test_restoreConflictingIds() {
        const id = append("Existing", "one")
        const backup = JSON.stringify([
            {id: id, title: "Imported", text: "two"},
            {id: id, title: "Other", text: "three"}
        ])
        compare(store.restoreBackup(backup, 50).status, "restored")
        compare(store.get(0).id, id)
        verify(store.get(1).id !== id)
        verify(store.get(2).id !== id)
        verify(store.get(1).id !== store.get(2).id)
    }
}
