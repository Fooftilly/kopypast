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

    onConfigValueChanged: {
        try {
            var parsedSnippets = JSON.parse(configValue || "[]")
            snippets = parsedSnippets.map(function(snippet) {
                return {
                    title: snippet.title,
                    text: snippet.text,
                    usageCount: snippet.usageCount || 0,
                    isNew: snippet.isNew !== undefined ? snippet.isNew : false
                }
            })
        } catch (e) {
            console.error("Failed to parse snippets:", e)
            snippets = []
        }
    }

    function loadFromConfig(config) {
        configValue = config
    }

    function get(index) {
        return snippets[index]
    }

    function append(item) {
        var snippetsArray = snippets.slice()
        item.isNew = true
        snippetsArray.push(item)
        updateModel(snippetsArray)
    }

    function set(index, item) {
        var snippetsArray = snippets.slice()
        snippetsArray[index] = item
        updateModel(snippetsArray)
    }

    function remove(index) {
        var snippetsArray = snippets.slice()
        snippetsArray.splice(index, 1)
        updateModel(snippetsArray)
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
            snippetsArray[index].usageCount = (snippetsArray[index].usageCount || 0) + 1
            if (snippetsArray[index].isNew) {
                snippetsArray[index].isNew = false
            }
            updateModel(snippetsArray)
        }
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

    function resetUsageCount() {
        var snippetsArray = snippets.slice()
        for (var i = 0; i < snippetsArray.length; i++) {
            snippetsArray[i].usageCount = 0
        }
        updateModel(snippetsArray)
    }

    function restoreBackup(content, maxSnippets) {
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
        var normalized = []
        for (var i = 0; i < data.length; i++) {
            var entry = data[i]
            if (!entry || typeof entry.title !== "string" || entry.title.length === 0
                    || typeof entry.text !== "string" || entry.text.length === 0
                    || (entry.usageCount !== undefined
                        && (!Number.isSafeInteger(entry.usageCount) || entry.usageCount < 0))
                    || (entry.isNew !== undefined && typeof entry.isNew !== "boolean")) {
                return { status: "invalid-record" }
            }
            normalized.push({
                title: entry.title,
                text: entry.text,
                usageCount: entry.usageCount === undefined ? 0 : entry.usageCount,
                isNew: entry.isNew === undefined ? false : entry.isNew
            })
        }

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
        updateModel(snippets.concat(restored))
        return {
            status: restored.length < accepted.length ? "partial" : "restored",
            count: restored.length,
            duplicates: duplicates
        }
    }

    function updateModel(newSnippets) {
        snippets = newSnippets
        configValue = JSON.stringify(newSnippets)
    }
}