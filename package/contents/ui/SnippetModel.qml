/*
    SPDX-FileCopyrightText: 2025 Vladimir Kosolapov
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

Item {
    id: snippetModel

    property string configValue: ""
    property var snippets: []
    property int count: snippets.length
    property bool configurationValid: true

    onConfigValueChanged: {
        try {
            var parsed = JSON.parse(configValue || "[]")
            var records = normalizeRecords(parsed)
            if (records === null)
                throw new Error("Invalid snippet configuration")
            snippets = normalizeIds(records)
            configurationValid = true
        } catch (error) {
            // Preserve the original configuration string for recovery.
            configurationValid = false
            snippets = []
            console.warn("Invalid snippet configuration; changes are blocked")
        }
    }

    function normalizeRecords(data) {
        if (!Array.isArray(data))
            return null
        var records = []
        for (var i = 0; i < data.length; i++) {
            var entry = data[i]
            if (!entry || typeof entry.title !== "string" || entry.title.length === 0
                    || typeof entry.text !== "string" || entry.text.length === 0
                    || (entry.usageCount !== undefined
                        && (!Number.isSafeInteger(entry.usageCount) || entry.usageCount < 0))
                    || (entry.isNew !== undefined && typeof entry.isNew !== "boolean")
                    || (entry.id !== undefined && (typeof entry.id !== "string" || entry.id.length === 0)))
                return null
            records.push({
                id: entry.id,
                title: entry.title,
                text: entry.text,
                usageCount: entry.usageCount === undefined ? 0 : entry.usageCount,
                isNew: entry.isNew === undefined ? false : entry.isNew
            })
        }
        return records
    }

    function resetInvalidConfiguration() {
        if (configurationValid)
            return false
        configValue = "[]"
        return true
    }

    function loadFromConfig(config) {
        configValue = config
    }

    // Old configurations have no ID. Use deterministic IDs until the next write,
    // so both the popup and settings resolve the same legacy records.
    function normalizeIds(records) {
        var reserved = new Set()
        var used = new Set()
        for (var i = 0; i < records.length; i++) {
            if (typeof records[i].id === "string" && records[i].id.length > 0)
                reserved.add(records[i].id)
        }
        return records.map(function(record, index) {
            var id = record.id
            if (typeof id !== "string" || id.length === 0 || used.has(id)) {
                id = "legacy-" + index
                while (reserved.has(id) || used.has(id))
                    id += "-"
            }
            used.add(id)
            return Object.assign({}, record, { id: id })
        })
    }

    function indexOfId(id) {
        return snippets.findIndex(function(snippet) { return snippet.id === id })
    }

    function createId(reserved) {
        var id
        do {
            id = "snippet-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2)
        } while (reserved.has(id))
        reserved.add(id)
        return id
    }

    function get(index) {
        return snippets[index]
    }

    function append(item) {
        var snippetsArray = snippets.slice()
        var reserved = new Set(snippets.map(function(snippet) { return snippet.id }))
        snippetsArray.push({
            id: createId(reserved),
            title: item.title,
            text: item.text,
            usageCount: 0,
            isNew: true
        })
        updateModel(snippetsArray)
    }

    function set(index, item) {
        var snippetsArray = snippets.slice()
        if (!snippetsArray[index])
            return
        snippetsArray[index] = Object.assign({}, snippetsArray[index], {
            title: item.title,
            text: item.text
        })
        updateModel(snippetsArray)
    }

    function remove(index) {
        var snippetsArray = snippets.slice()
        snippetsArray.splice(index, 1)
        updateModel(snippetsArray)
    }

    function removeForUndo(index) {
        if (!snippets[index])
            return null
        var deletion = {
            item: Object.assign({}, snippets[index]),
            index: index,
            previousId: index > 0 ? snippets[index - 1].id : null,
            nextId: index + 1 < snippets.length ? snippets[index + 1].id : null,
            undone: false
        }
        remove(index)
        return deletion
    }

    function undoRemoval(deletion) {
        if (!configurationValid || !deletion || deletion.undone)
            return false

        var item = Object.assign({}, deletion.item)
        var existingIndex = indexOfId(item.id)
        if (existingIndex >= 0) {
            var existing = snippets[existingIndex]
            if (existing.title === item.title && existing.text === item.text) {
                deletion.undone = true
                return false
            }
            item.id = createId(new Set(snippets.map(function(snippet) { return snippet.id })))
        }

        var next = indexOfId(deletion.nextId)
        var previous = indexOfId(deletion.previousId)
        var index = next >= 0 ? next : previous >= 0 ? previous + 1
                : Math.min(deletion.index, snippets.length)
        var updated = snippets.slice()
        updated.splice(index, 0, item)
        updateModel(updated)
        deletion.undone = true
        return true
    }

    function move(from, to) {
        if (from === to) return
        var snippetsArray = snippets.slice()
        snippetsArray.splice(to, 0, snippetsArray.splice(from, 1)[0])
        updateModel(snippetsArray)
    }

    function incrementUsage(index) {
        var snippetsArray = snippets.slice()
        if (snippetsArray[index]) {
            snippetsArray[index].usageCount = Math.min(Number.MAX_SAFE_INTEGER, (snippetsArray[index].usageCount || 0) + 1)
            if (snippetsArray[index].isNew) {
                snippetsArray[index].isNew = false
            }
            updateModel(snippetsArray)
        }
    }

    function recordUse(id) {
        var index = indexOfId(id)
        if (index >= 0)
            incrementUsage(index)
    }

    function markAsUsed(index) {
        var snippetsArray = snippets.slice()
        if (snippetsArray[index] && snippetsArray[index].isNew) {
            snippetsArray[index].isNew = false
            updateModel(snippetsArray)
        }
    }

    function getSortedSnippets(sortByUsage) {
        if (!sortByUsage) {
            return snippets
        }

        var sortedSnippets = snippets.slice()
        sortedSnippets.sort(function(a, b) {
            var usageA = a.usageCount || 0
            var usageB = b.usageCount || 0
            if (usageA !== usageB) {
                return usageB - usageA
            }
            var indexA = snippets.indexOf(a)
            var indexB = snippets.indexOf(b)
            return indexA - indexB
        })
        return sortedSnippets
    }

    function getFilteredSnippets(sortByUsage, query) {
        var sorted = getSortedSnippets(sortByUsage)
        if (!query)
            return sorted
        var search = query.toLowerCase()
        return sorted.filter(function(snippet) {
            return snippet.title.toLowerCase().includes(search)
                    || snippet.text.toLowerCase().includes(search)
        })
    }

    function restoreBackup(content, maxSnippets) {
        if (!configurationValid)
            return { status: "invalid-config" }
        var data
        try {
            data = JSON.parse(content)
        } catch (error) {
            return { status: "invalid-format" }
        }
        if (!Array.isArray(data))
            return { status: "invalid-format" }
        if (data.length === 0)
            return { status: "empty" }

        // Validate the entire backup before applying any changes.
        var normalized = normalizeRecords(data)
        if (normalized === null)
            return { status: "invalid-record" }

        var seen = new Set(snippets.map(function(entry) {
            return JSON.stringify([entry.title, entry.text])
        }))
        var accepted = []
        var duplicates = 0
        for (var j = 0; j < normalized.length; j++) {
            var snippet = normalized[j]
            var key = JSON.stringify([snippet.title, snippet.text])
            if (seen.has(key)) {
                duplicates++
            } else {
                seen.add(key)
                accepted.push(snippet)
            }
        }
        if (accepted.length === 0)
            return { status: "duplicates" }

        var remaining = Math.max(0, maxSnippets - snippets.length)
        if (remaining === 0)
            return { status: "limit" }

        var restored = accepted.slice(0, remaining)
        var reserved = new Set(snippets.map(function(snippet) { return snippet.id }))
        for (var k = 0; k < restored.length; k++) {
            var restoredEntry = restored[k]
            if (!restoredEntry.id || reserved.has(restoredEntry.id))
                restoredEntry.id = createId(reserved)
            else
                reserved.add(restoredEntry.id)
        }
        updateModel(snippets.concat(restored))
        return {
            status: restored.length < accepted.length ? "partial" : "restored",
            count: restored.length,
            duplicates: duplicates
        }
    }

    function updateModel(newSnippets) {
        if (!configurationValid)
            return false
        var records = normalizeRecords(newSnippets)
        if (records === null)
            return false
        snippets = normalizeIds(records)
        configValue = JSON.stringify(snippets)
        return true
    }
}