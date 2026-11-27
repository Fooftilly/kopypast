/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick

QtObject {
    function keyFor(category) {
        // Namespace the real category names so they cannot collide with
        // the all/uncategorized options, even if users choose those names.
        return category ? "category:" + category.normalize("NFC").toLowerCase() : "uncategorized"
    }

    function options(records, allLabel = "All categories", uncategorizedLabel = "Uncategorized") {
        var seen = new Set()
        var groups = []
        var uncategorized = false
        for (var i = 0; i < records.length; i++) {
            var category = records[i].category
            if (!category) {
                uncategorized = true
                continue
            }
            var key = keyFor(category)
            if (!seen.has(key)) {
                seen.add(key)
                groups.push({key: key, label: category})
            }
        }
        groups.sort(function(a,b) { return a.label.localeCompare(b.label) })
        var result = [{key: "", label: allLabel}]
        // Avoid a redundant filter when no categories exist.
        if (groups.length > 0 && uncategorized)
            result.push({key: "uncategorized", label: uncategorizedLabel})
        return result.concat(groups)
    }

    function tagKey(tag) {
        return "tag:" + tag.normalize("NFC").toLowerCase()
    }

    function tagOptions(records, allLabel = "All tags", untaggedLabel = "Untagged") {
        const seen = new Set()
        const groups = []
        let untagged = false
        for (const record of records) {
            if (record.tags.length === 0)
                untagged = true
            for (const tag of record.tags) {
                const key = tagKey(tag)
                if (!seen.has(key)) {
                    seen.add(key)
                    groups.push({key:key, label:tag})
                }
            }
        }
        groups.sort(function(a,b) { return a.label.localeCompare(b.label) })
        const result = [{key:"", label:allLabel}]
        if (groups.length > 0 && untagged)
            result.push({key:"untagged", label:untaggedLabel})
        return result.concat(groups)
    }

    function applyTag(records, key) {
        if (!key)
            return records
        return records.filter(function(record) {
            if (key === "untagged")
                return record.tags.length === 0
            return record.tags.some(function(tag) { return tagKey(tag) === key })
        })
    }

    function apply(records, key) {
        if (!key)
            return records
        return records.filter(function(record) {
            return keyFor(record.category) === key
        })
    }
}
