/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "CategoryFilter"
    Local.CategoryFilter { id: filter }
    Local.SnippetModel { id: store }

    function init() {
        store.loadFromConfig(JSON.stringify([
            {id:"a", title:"Review", text:"Git changes", category:"Work"},
            {id:"b", title:"Review", text:"Other changes", category:"work", favorite:true},
            {id:"c", title:"Review", text:"Git changes"},
            {id:"d", title:"Status", text:"Git changes", category:"Uncategorized"},
            {id:"e", title:"Review", text:"Git changes", category:"All categories"}
        ]))
    }

    function ids(records) {
        return records.map(function(item) { return item.id })
    }

    function test_keysAndSearch() {
        compare(filter.keyFor("Work"), filter.keyFor("work"))
        verify(filter.keyFor("Uncategorized") !== filter.keyFor(""))
        verify(filter.keyFor("All categories") !== "")
        compare(ids(filter.apply(store.getFilteredSnippets(0, "review"), filter.keyFor("Work"))), ["b","a"])
        compare(ids(filter.apply(store.getFilteredSnippets(0, "git"), filter.keyFor("Work"))), ["a"])
        compare(ids(filter.apply(store.getFilteredSnippets(0, "git"), "uncategorized")), ["c"])
        compare(ids(filter.apply(store.getFilteredSnippets(0, "git"), filter.keyFor("Uncategorized"))), ["d"])
        compare(ids(filter.apply(store.getFilteredSnippets(0, "git"), "")), ["a","c","d","e"])
    }

    function test_emptyAndRemovedGroup() {
        compare(filter.apply([], "uncategorized"), [])
        compare(filter.apply(store.snippets, "category:missing"), [])
        compare(filter.options([]).length, 1)
        compare(filter.options([{category:""}]).length, 1)
    }

    function test_uniqueOptions() {
        const options = filter.options(store.snippets)
        const keys = options.map(function(option) { return option.key })
        compare(options.length, 5)
        compare(keys.filter(function(key) { return key === "category:work" }).length, 1)
        verify(keys.includes("uncategorized"))
        verify(keys.includes("category:uncategorized"))
        verify(keys.includes("category:all categories"))
    }
}
