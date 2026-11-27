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

    // Optional synchronous storage gate. Reject a mutation before publishing it.
    // Local configuration keeps the existing behavior when no gate is supplied.
    property var beforeCommit: null

    // Only stores persisted as a single KConfig entry use this budget.
    // File-backed stores have their own native size limit.
    property bool enforceLocalConfigBudget: false
    readonly property int localConfigBudget: 1024 * 1024
    signal localConfigBudgetRejected()

    function fitsLocalConfigBudget(serialized) {
        // Conservative upper bound for the escaped UTF-8 KConfig line.
        // JSON.stringify escapes controls and quotes; KConfig escapes
        // backslashes again. Count non-ASCII UTF-16 units as three bytes
        // (a surrogate pair is at most four UTF-8 bytes). Include room
        // for the key, entry flags and line ending.
        var bytes = 64
        for (var i = 0; i < serialized.length; i++) {
            var unit = serialized.charCodeAt(i)
            bytes += unit < 32 || unit === 127 ? 4
                : unit === 92 ? 2
                : unit < 128 ? 1 : 3
            if (bytes > localConfigBudget)
                return false
        }
        return true
    }

    // A prepared internal write is valid only for its exact serialized value.
    // External configuration changes must always pass normal validation.
    property var preparedWrite: null

    onConfigValueChanged: {
        if (preparedWrite !== null && preparedWrite.config === configValue) {
            var records = preparedWrite.records
            preparedWrite = null
            snippets = records
            configurationValid = true
            return
        }
        try {
            var parsed = JSON.parse(configValue || "[]")
            var normalized = normalizeRecords(parsed)
            if (normalized === null)
                throw new Error("Invalid snippet configuration")
            snippets = normalizeIds(normalized)
            configurationValid = true
        } catch (error) {
            // Preserve the original configuration string for recovery.
            configurationValid = false
            snippets = []
            console.warn("Invalid snippet configuration; changes are blocked")
        }
    }

    function validTimestamp(value) {
        return value === undefined || value === null
            || (Number.isSafeInteger(value) && value >= 0 && value <= 8640000000000000)
    }

    function normalizedTags(value) {
        if (value === undefined)
            return []
        if (!Array.isArray(value))
            return null
        var seen = new Set()
        var tags = []
        for (var i = 0; i < value.length; i++) {
            if (typeof value[i] !== "string" || /[,\r\n]/.test(value[i]))
                return null
            var tag = value[i].trim().normalize("NFC")
            var key = tag.toLowerCase()
            if (tag && !seen.has(key)) {
                seen.add(key)
                tags.push(tag)
            }
        }
        return tags
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
                    || (entry.favorite !== undefined && typeof entry.favorite !== "boolean")
                    || !validTimestamp(entry.createdAt) || !validTimestamp(entry.lastUsedAt)
                    || (entry.category !== undefined && (typeof entry.category !== "string" || /[\r\n]/.test(entry.category)))
                    || (entry.id !== undefined && (typeof entry.id !== "string" || entry.id.length === 0)))
                return null
            var tags = normalizedTags(entry.tags)
            if (tags === null)
                return null
            records.push({
                id: entry.id,
                title: entry.title,
                text: entry.text,
                usageCount: entry.usageCount === undefined ? 0 : entry.usageCount,
                isNew: entry.isNew === undefined ? false : entry.isNew,
                favorite: entry.favorite === true,
                createdAt: entry.createdAt === undefined ? null : entry.createdAt,
                lastUsedAt: entry.lastUsedAt === undefined ? null : entry.lastUsedAt,
                category: entry.category === undefined ? "" : entry.category.trim().normalize("NFC"),
                tags: tags
            })
        }
        return records
    }

    function resetInvalidConfiguration() {
        if (configurationValid || beforeCommit !== null)
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
            isNew: true,
            favorite: false,
            createdAt: Date.now(),
            lastUsedAt: null,
            category: item.category,
            tags: item.tags
        })
        return updateModel(snippetsArray)
    }

    function set(index, item) {
        var snippetsArray = snippets.slice()
        if (!snippetsArray[index])
            return false
        var changes = { title: item.title, text: item.text }
        if (item.category !== undefined)
            changes.category = item.category
        if (item.tags !== undefined)
            changes.tags = item.tags
        snippetsArray[index] = Object.assign({}, snippetsArray[index], changes)
        return updateModel(snippetsArray)
    }

    function remove(index) {
        if (!Number.isInteger(index) || index < 0 || index >= snippets.length)
            return false
        var snippetsArray = snippets.slice()
        snippetsArray.splice(index, 1)
        return updateModel(snippetsArray)
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
        return remove(index) ? deletion : null
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
        if (!updateModel(updated))
            return false
        deletion.undone = true
        return true
    }

    function move(from, to) {
        if (!Number.isInteger(from) || !Number.isInteger(to)
                || from < 0 || to < 0 || from >= snippets.length || to >= snippets.length)
            return false
        if (from === to)
            return true
        var snippetsArray = snippets.slice()
        snippetsArray.splice(to, 0, snippetsArray.splice(from, 1)[0])
        return updateModel(snippetsArray)
    }

    function incrementUsage(index) {
        if (!configurationValid || !snippets[index])
            return false
        var snippetsArray = snippets.slice()
        var now = Date.now()
        // Preserve the validation invariant even if the system clock is invalid.
        if (!validTimestamp(now))
            return false
        snippetsArray[index] = Object.assign({}, snippetsArray[index], {
            usageCount: Math.min(Number.MAX_SAFE_INTEGER, snippetsArray[index].usageCount + 1),
            isNew: false,
            lastUsedAt: now
        })
        return commitNormalized(snippetsArray)
    }

    function recordUse(id) {
        var index = indexOfId(id)
        return index >= 0 && incrementUsage(index)
    }

    function markAsUsed(index) {
        if (!configurationValid || !snippets[index] || !snippets[index].isNew)
            return false
        var snippetsArray = snippets.slice()
        snippetsArray[index] = Object.assign({}, snippetsArray[index], { isNew: false })
        return commitNormalized(snippetsArray)
    }

    function setFavorite(id, favorite) {
        if (!configurationValid || typeof favorite !== "boolean")
            return false
        var index = indexOfId(id)
        if (index < 0)
            return false
        if (snippets[index].favorite === favorite)
            return true
        var updated = snippets.slice()
        updated[index] = Object.assign({}, updated[index], { favorite: favorite })
        return commitNormalized(updated)
    }

    function metadataNames(kind) {
        if (kind !== "category" && kind !== "tag")
            return []
        var seen = new Set()
        var names = []
        for (var i = 0; i < snippets.length; i++) {
            var values = kind === "category" ? [snippets[i].category] : snippets[i].tags
            for (var j = 0; j < values.length; j++) {
                var key = values[j].toLowerCase()
                if (key && !seen.has(key)) {
                    seen.add(key)
                    names.push(values[j])
                }
            }
        }
        return names.sort(function(a,b) { return a.localeCompare(b) })
    }

    // An empty replacement clears the category or removes the tag.
    // Snippets themselves are never removed.
    function renameMetadata(kind, from, to) {
        if (!configurationValid || (kind !== "category" && kind !== "tag")
                || typeof from !== "string" || typeof to !== "string")
            return false
        var source = from.trim().normalize("NFC").toLowerCase()
        var replacement = to.trim().normalize("NFC")
        if (!source || /[\r\n]/.test(replacement) || (kind === "tag" && replacement.includes(",")))
            return false
        var changed = false
        var updated = snippets.map(function(item) {
            if (kind === "category") {
                if (item.category.toLowerCase() !== source || item.category === replacement)
                    return item
                changed = true
                return Object.assign({}, item, { category: replacement })
            }
            if (!item.tags.some(function(tag) { return tag.toLowerCase() === source }))
                return item
            var tags = normalizedTags(item.tags.map(function(tag) {
                return tag.toLowerCase() === source ? replacement : tag
            }))
            if (JSON.stringify(tags) === JSON.stringify(item.tags))
                return item
            changed = true
            return Object.assign({}, item, { tags: tags })
        })
        return changed && updateModel(updated)
    }

    function getSortedSnippets(sortMode) {
        return sortRecords(snippets, sortMode)
    }

    function sortRecords(records, sortMode) {
        // 0 manual, 1 usage, 2 recent use, 3 recently created, 4 alphabetical.
        // Favorites remain first in every mode. Unknown dates sort last.
        var mode = Number(sortMode)
        var favorites = []
        var others = []
        for (var i = 0; i < records.length; i++) {
            var record = { item: records[i], index: i }
            if (mode === 4)
                record.titleKey = record.item.title.normalize("NFC").toLocaleLowerCase()
            if (record.item.favorite)
                favorites.push(record)
            else
                others.push(record)
        }

        function compareDates(a, b) {
            if (a === b)
                return 0
            if (a === null)
                return 1
            if (b === null)
                return -1
            return b - a
        }

        function compareRecords(a, b) {
            var result = 0
            switch (mode) {
            case 1:
                result = b.item.usageCount - a.item.usageCount
                break
            case 2:
                result = compareDates(a.item.lastUsedAt, b.item.lastUsedAt)
                break
            case 3:
                result = compareDates(a.item.createdAt, b.item.createdAt)
                break
            case 4:
                result = a.titleKey.localeCompare(b.titleKey)
                break
            }
            return result || a.index - b.index
        }

        if (mode >= 1 && mode <= 4) {
            favorites.sort(compareRecords)
            others.sort(compareRecords)
        }
        return favorites.concat(others).map(function(record) { return record.item })
    }

    function getFilteredSnippets(sortMode, query) {
        var search = query.trim().normalize("NFC").toLowerCase()
        if (!search)
            return getSortedSnippets(sortMode)

        // All words must match, in any order, across title, body and metadata.
        // Normalize equivalent Unicode spellings without stripping accents.
        var words = search.split(/\s+/)
        var matching = snippets.filter(function(snippet) {
            var title = snippet.title.normalize("NFC").toLowerCase()
            var body = snippet.text.normalize("NFC").toLowerCase()
            var category = snippet.category.toLowerCase()
            var tags = snippet.tags.map(function(tag) { return tag.toLowerCase() })
            return words.every(function(word) {
                return title.includes(word) || body.includes(word) || category.includes(word)
                    || tags.some(function(tag) { return tag.includes(word) })
            })
        })
        // Filtering preserves manual order, which is the tie-breaker in
        // every sort mode. Sort only records that can actually be shown.
        return sortRecords(matching, sortMode)
    }

    function restoreBackup(content, maxSnippets, preserveIdentity = false) {
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

        var accepted = []
        var duplicates = 0
        if (preserveIdentity) {
            // Versioned exports contain a stable ID for every record. Equal
            // content does not imply equal identity. Validate all IDs before
            // applying any part of a backup.
            var existingById = new Map(snippets.map(function(entry) { return [entry.id, entry] }))
            var incomingIds = new Set()
            for (var j = 0; j < normalized.length; j++) {
                var record = normalized[j]
                if (!record.id || incomingIds.has(record.id))
                    return { status: "invalid-record" }
                incomingIds.add(record.id)
                var existing = existingById.get(record.id)
                if (!existing) {
                    accepted.push(record)
                    continue
                }
                // Never overwrite or silently discard an edited record.
                // Keep local usage, favorites and timestamps on repeat import.
                if (existing.title !== record.title || existing.text !== record.text
                        || existing.category !== record.category
                        || JSON.stringify(existing.tags) !== JSON.stringify(record.tags))
                    return { status: "id-conflict" }
                duplicates++
            }
        } else {
            // Legacy clipboard imports identify duplicates by content.
            var seen = new Set(snippets.map(function(entry) {
                return JSON.stringify([entry.title, entry.text])
            }))
            for (var i = 0; i < normalized.length; i++) {
                var snippet = normalized[i]
                var key = JSON.stringify([snippet.title, snippet.text])
                if (seen.has(key)) {
                    duplicates++
                } else {
                    seen.add(key)
                    accepted.push(snippet)
                }
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
        if (!updateModel(snippets.concat(restored)))
            return { status: "write-failed" }
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
        return commitNormalized(normalizeIds(records))
    }

    // Only use this path with already validated records and unchanged unique IDs.
    // Metadata-only mutations above preserve that invariant; imports/edits use
    // updateModel(), and externally loaded JSON uses onConfigValueChanged.
    function commitNormalized(records) {
        if (!configurationValid)
            return false
        var serialized = JSON.stringify(records)
        if (serialized === configValue)
            return true

        if (enforceLocalConfigBudget && !fitsLocalConfigBudget(serialized)) {
            localConfigBudgetRejected()
            return false
        }
        if (beforeCommit !== null && !beforeCommit(records))
            return false

        preparedWrite = { config: serialized, records: records }
        try {
            configValue = serialized
        } finally {
            // Do not let a later external change reuse a prepared snapshot.
            preparedWrite = null
        }
        return configValue === serialized
    }
}