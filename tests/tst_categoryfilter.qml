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

    function test_tagOptionsAndCombinedFiltering() {
        store.loadFromConfig(JSON.stringify([
            {id:"a",title:"Review",text:"Git changes",category:"Work",tags:["Git","CI"]},
            {id:"b",title:"Review",text:"Other changes",category:"work",tags:["git"],favorite:true},
            {id:"c",title:"Review",text:"Git changes",category:"Work"},
            {id:"d",title:"Status",text:"Git changes",category:"Other",tags:["Untagged","All tags"]},
            {id:"e",title:"Review",text:"Git changes",category:"Other",tags:["Čaša"]}
        ]))
        const keys = filter.tagOptions(store.snippets).map(function(option) { return option.key })
        compare(keys.length, 7)
        compare(keys.filter(function(key) { return key === "tag:git" }).length, 1)
        verify(keys.includes("untagged"))
        verify(keys.includes("tag:untagged"))
        verify(keys.includes("tag:all tags"))
        const work = filter.apply(store.getFilteredSnippets(0,"review"),filter.keyFor("work"))
        compare(ids(filter.applyTag(work,filter.tagKey("GIT"))),["b","a"])
        compare(ids(filter.applyTag(work,"untagged")),["c"])
        compare(ids(filter.applyTag(work,"")),["b","a","c"])
        compare(ids(filter.applyTag(store.snippets,filter.tagKey("Untagged"))),["d"])
        compare(ids(filter.applyTag(store.snippets,filter.tagKey("ČAŠA"))),["e"])
        compare(filter.tagOptions([]).length,1)
        compare(filter.tagOptions([{tags:[]}]).length,1)
        compare(filter.applyTag(store.snippets,"tag:missing"),[])
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
