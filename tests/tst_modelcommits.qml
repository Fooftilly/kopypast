/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "SnippetModelCommits"
    Local.SnippetModel { id: store }
    Local.SnippetModel { id: other }
    SignalSpy { id: changes; target: store; signalName: "snippetsChanged" }

    function init() {
        store.loadFromConfig('[{"id":"a","title":"One","text":"body","createdAt":100,"favorite":true},{"id":"b","title":"Two","text":"two","usageCount":3,"isNew":true}]')
        other.loadFromConfig("[]")
        verify(store.configurationValid)
        changes.clear()
    }

    function test_metadataWrites() {
        store.recordUse("b")
        compare(changes.count, 1)
        compare(store.get(1).usageCount, 4)
        verify(!store.get(1).isNew)
        verify(store.get(1).lastUsedAt !== null)
        compare(store.get(0).createdAt, 100)
        verify(store.get(0).favorite)
        verify(store.setFavorite("b", true))
        compare(changes.count, 2)
        verify(store.get(1).favorite)
        compare(store.get(0).id, "a")
        compare(store.get(1).id, "b")
        other.loadFromConfig(store.configValue)
        compare(other.snippets, store.snippets)
        compare(JSON.parse(store.configValue), store.snippets)
        compare(store.preparedWrite, null)
        verify(store.setFavorite("b", true))
        compare(changes.count, 2)
    }

    function test_externalConfigStillValidated() {
        store.recordUse("b")
        const saved = store.configValue
        store.loadFromConfig("[null]")
        verify(!store.configurationValid)
        compare(store.count, 0)
        compare(store.configValue, "[null]")
        verify(!store.setFavorite("b", false))
        store.recordUse("b")
        store.markAsUsed(0)
        compare(store.configValue, "[null]")
        store.loadFromConfig(saved)
        verify(store.configurationValid)
        compare(store.get(1).usageCount, 4)
        store.loadFromConfig('[{"id":"external","title":"External","text":"new"}]')
        compare(store.count, 1)
        compare(store.get(0).id, "external")
        compare(store.get(0).usageCount, 0)
    }

    function test_regularWritesStillValidate() {
        const before = store.configValue
        store.append({title: "", text: "invalid"})
        store.set(0, {title: "valid", text: ""})
        compare(store.configValue, before)
        compare(changes.count, 0)
        store.append({title: "Three", text: "third"})
        compare(changes.count, 1)
        compare(store.count, 3)
        other.loadFromConfig(store.configValue)
        compare(other.snippets, store.snippets)
    }
}
