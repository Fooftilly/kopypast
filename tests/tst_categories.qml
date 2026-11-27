/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "SnippetCategoriesTags"
    Local.SnippetModel { id: store }
    Local.SnippetModel { id: restored }

    function init() {
        store.loadFromConfig("[]")
        restored.loadFromConfig("[]")
    }

    function ids(query) {
        return store.getFilteredSnippets(0, query).map(function(item) { return item.id })
    }

    function test_legacyAndSearch() {
        store.loadFromConfig('[{"id":"a","title":"Review","text":"Check the changes","category":" Development ","tags":["Git","git"," CI ",""]},{"id":"b","title":"Status","text":"Check the server"},{"id":"c","title":"Report","text":"Draft","category":"Operations","tags":["Čaša"]}]')
        verify(store.configurationValid)
        compare(store.get(0).category, "Development")
        compare(store.get(0).tags, ["Git", "CI"])
        compare(store.get(1).category, "")
        compare(store.get(1).tags, [])
        compare(ids("development git changes"), ["a"])
        compare(ids("check"), ["a", "b"])
        compare(ids("operations C\u030cAS\u030cA"), ["c"])
        compare(ids("development server"), [])
        compare(ids(""), ["a", "b", "c"])
    }

    function test_editAndRoundTrip() {
        store.append({title:"Prompt", text:"Review PR", category:"AI", tags:["Git", "Review"]})
        const id = store.get(0).id
        store.setFavorite(id, true)
        store.recordUse(id)
        store.set(0, {title:"Updated", text:"Review changes"})
        compare(store.get(0).category, "AI")
        compare(store.get(0).tags, ["Git", "Review"])
        store.set(0, {title:"Updated", text:"Review changes", category:"Work", tags:["New"]})
        compare(store.get(0).id, id)
        verify(store.get(0).favorite)
        compare(store.get(0).usageCount, 1)
        const deletion = store.removeForUndo(0)
        verify(store.undoRemoval(deletion))
        compare(store.get(0).category, "Work")
        compare(store.get(0).tags, ["New"])
        compare(restored.restoreBackup(store.configValue, 50).status, "restored")
        compare(restored.snippets, store.snippets)
        store.set(0, {title:"Updated", text:"Review changes", category:"", tags:[]})
        compare(store.get(0).category, "")
        compare(store.get(0).tags, [])
    }

    function test_invalidMetadata_data() {
        return [
            {tag:"category-number", fields:{category:1}},
            {tag:"category-newline", fields:{category:"one\ntwo"}},
            {tag:"tags-string", fields:{tags:"Git"}},
            {tag:"tags-null", fields:{tags:null}},
            {tag:"tag-number", fields:{tags:[1]}},
            {tag:"tag-comma", fields:{tags:["one,two"]}},
            {tag:"tag-newline", fields:{tags:["one\ntwo"]}}
        ]
    }

    function test_invalidMetadata(data) {
        store.append({title:"Existing", text:"body"})
        const before = store.configValue
        const raw = JSON.stringify([Object.assign({title:"Invalid", text:"body"}, data.fields)])
        compare(store.restoreBackup(raw, 50).status, "invalid-record")
        compare(store.configValue, before)
        store.loadFromConfig(raw)
        verify(!store.configurationValid)
        compare(store.configValue, raw)
    }
}
