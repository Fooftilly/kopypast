/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "SnippetSearch"
    Local.SnippetModel { id: store }

    function init() {
        store.loadFromConfig(JSON.stringify([
            { id: "a", title: "Git review", text: "Inspect pull request\nbefore merge." },
            { id: "b", title: "Git status", text: "Check repository state.", favorite: true },
            { id: "c", title: "Review checklist", text: "Inspect CI and tests.", usageCount: 5 },
            { id: "d", title: "Čaša", text: "日本語 <b>literal</b> $1" },
            { id: "e", title: "C\u030cAS\u030cA", text: "decomposed Unicode" }
        ]))
        verify(store.configurationValid)
    }

    function ids(query, sortByUsage = false) {
        return store.getFilteredSnippets(sortByUsage, query).map(function(item) {
            return item.id
        })
    }

    function test_allTermsAndFields() {
        compare(ids("git merge"), ["a"])
        compare(ids("MERGE git"), ["a"])
        compare(ids(" \tgit   merge\n"), ["a"])
        compare(ids("review inspect"), ["a", "c"])
        compare(ids("review inspect", true), ["c", "a"])
        compare(ids("git unrelated"), [])
        compare(ids("git git"), ["b", "a"])
    }

    function test_emptyAndOrder() {
        compare(ids(""), ["b", "a", "c", "d", "e"])
        compare(ids(" \t\n "), ["b", "a", "c", "d", "e"])
        compare(ids("", true), ["b", "c", "a", "d", "e"])
        compare(store.snippets.map(function(item) { return item.id }), ["a", "b", "c", "d", "e"])
    }

    function test_unicodeAndLiteralText() {
        compare(ids("čAŠa"), ["d", "e"])
        compare(ids("C\u030cAS\u030cA"), ["d", "e"])
        compare(ids("casa"), [])
        compare(ids("日本語 <b> $1"), ["d"])
        compare(ids(".*"), [])
    }

    function test_selectiveSortMatchesFullSort() {
        store.loadFromConfig(JSON.stringify([
            {id:"a", title:"Zulu", text:"match", usageCount:5, createdAt:100, lastUsedAt:200},
            {id:"b", title:"Alpha", text:"excluded", favorite:true},
            {id:"c", title:"Beta", text:"match", usageCount:5, favorite:true, createdAt:100},
            {id:"d", title:"alpha", text:"match", createdAt:200, lastUsedAt:100},
            {id:"e", title:"ALPHA", text:"match", lastUsedAt:100},
            {id:"f", title:"Beta", text:"excluded"},
            {id:"g", title:"Gamma", text:"match", favorite:true}
        ]))
        for (var mode = 0; mode <= 4; mode++) {
            const full = store.getSortedSnippets(mode)
            const expected = full.filter(function(record) { return record.text === "match" })
                .map(function(record) { return record.id })
            compare(ids("match", mode), expected)
            compare(ids("absent", mode), [])
            compare(ids("", mode), full.map(function(record) { return record.id }))
        }
        compare(store.snippets.map(function(record) { return record.id }), ["a","b","c","d","e","f","g"])
    }

    function test_noMutation() {
        const before = store.configValue
        ids("merge", true)
        ids("review")
        compare(store.configValue, before)
    }

    function fuzzyIds(query, mode = 0) {
        return store.getFilteredSnippets(mode, query, true).map(function(item) { return item.id })
    }

    function test_editDistance() {
        verify(store.withinOneEdit("review", "review"))
        verify(store.withinOneEdit("reveiw", "review"))
        verify(store.withinOneEdit("reviw", "review"))
        verify(store.withinOneEdit("reviews", "review"))
        verify(store.withinOneEdit("rexiew", "review"))
        verify(!store.withinOneEdit("rveiwe", "review"))
        verify(!store.withinOneEdit("revi", "review"))
    }

    function test_fuzzyIsOptional() {
        compare(ids("reveiw"), [])
        compare(fuzzyIds("reveiw"), ["a", "c"])
        compare(fuzzyIds("statsu"), ["b"])
        compare(fuzzyIds("repositroy"), ["b"])
        // Typing the start of a word with a typo.
        compare(fuzzyIds("chekc"), ["b", "c"])
    }

    function test_fuzzyRanksExactFirst() {
        store.loadFromConfig(JSON.stringify([
            { id: "near", title: "Deploy", text: "body", favorite: true },
            { id: "exact", title: "Deplyo notes", text: "body" }
        ]))
        compare(fuzzyIds("deplyo"), ["exact", "near"])
        compare(ids("deplyo"), ["exact"])
    }

    function test_fuzzyNeedsEveryWordAndFourLetters() {
        compare(fuzzyIds("gti"), [])
        compare(fuzzyIds("git reveiw"), ["a"])
        compare(fuzzyIds("reveiw unrelated"), [])
        compare(fuzzyIds("čaša"), ["d", "e"])
        compare(fuzzyIds("čaše"), ["d", "e"])
        compare(fuzzyIds(".*"), [])
        compare(fuzzyIds("merge,before"), [])
        compare(fuzzyIds("mergr"), ["a"])
        compare(fuzzyIds("日本話"), [])
    }
}
