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

    function test_noMutation() {
        const before = store.configValue
        ids("merge", true)
        ids("review")
        compare(store.configValue, before)
    }
}
