/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "MetadataManagement"
    Local.SnippetModel { id: store }
    function init() {
        store.loadFromConfig(JSON.stringify([
            {id:"a", title:"A", text:"one", category:"Work", tags:["Git","CI"], favorite:true, usageCount:4},
            {id:"b", title:"B", text:"two", category:"work", tags:["git","Review"]},
            {id:"c", title:"C", text:"three"}
        ]))
        verify(store.configurationValid)
    }

    function test_categories() {
        compare(store.metadataNames("category"), ["Work"])
        verify(store.renameMetadata("category", "WORK", " Projects "))
        compare(store.get(0).category, "Projects")
        compare(store.get(1).category, "Projects")
        compare(store.get(2).category, "")
        verify(store.renameMetadata("category", "projects", ""))
        compare(store.metadataNames("category"), [])
        compare(store.count, 3)
        compare(store.get(0).id, "a")
        verify(store.get(0).favorite)
        compare(store.get(0).usageCount, 4)
    }

    function test_tags() {
        verify(store.renameMetadata("tag", "GIT", "CI"))
        compare(store.get(0).tags, ["CI"])
        compare(store.get(1).tags, ["CI","Review"])
        verify(store.renameMetadata("tag", "ci", ""))
        compare(store.get(0).tags, [])
        compare(store.get(1).tags, ["Review"])
        const snapshot = store.configValue
        store.loadFromConfig("[]")
        store.loadFromConfig(snapshot)
        compare(store.get(1).tags, ["Review"])
    }

    function test_invalid() {
        const before = store.configValue
        verify(!store.renameMetadata("tag", "git", "a,b"))
        verify(!store.renameMetadata("category", "work", "a\nb"))
        verify(!store.renameMetadata("tag", "missing", "new"))
        verify(!store.renameMetadata("unknown", "git", "new"))
        verify(!store.renameMetadata("category", "", "new"))
        compare(store.configValue, before)
        store.loadFromConfig("[null]")
        verify(!store.renameMetadata("tag", "git", "new"))
        compare(store.configValue, "[null]")
    }
}
