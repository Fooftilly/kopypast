/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "SnippetScaleBenchmark"

    Local.SnippetModel { id: store }

    function measure(operation, iterations) {
        const samples = []
        for (let i = 0; i < iterations; i++) {
            const start = Date.now()
            operation(i)
            samples.push(Date.now() - start)
        }
        samples.sort(function(a, b) { return a - b })
        return {
            median_ms: samples[Math.floor(samples.length / 2)],
            p95_ms: samples[Math.ceil(samples.length * 0.95) - 1],
            samples: samples.length
        }
    }

    function test_scale_data() {
        return [100, 1000, 10000].map(function(size) {
            return {tag: String(size), size: size}
        })
    }

    function test_scale(data) {
        const records = []
        const body = "Example procedure:\n  inspect the configuration and review the results.\nUnicode: čćž 日本語\n"
        for (let i = 0; i < data.size; i++) {
            records.push({
                id: "benchmark-" + i,
                title: "Snippet " + i,
                text: body.repeat(4) + "\nIdentifier: " + i,
                usageCount: i % 17,
                isNew: false,
                favorite: i % 20 === 0
            })
        }
        const raw = JSON.stringify(records)
        const result = {records: data.size, utf16_code_units: raw.length}
        result.load = measure(function() {
            store.loadFromConfig("[]")
            store.loadFromConfig(raw)
        }, 9)
        verify(store.configurationValid)
        compare(store.count, data.size)

        const expectedMatches = records.filter(function(record) {
            return record.title.includes("12")
        }).length
        result.search = measure(function() {
            const found = store.getFilteredSnippets(false, "12 snippet")
            if (found.length !== expectedMatches)
                throw new Error("Unexpected search result")
        }, 15)
        result.usage_sort = measure(function() {
            const sorted = store.getSortedSnippets(true)
            if (sorted.length !== data.size || !sorted[0].favorite)
                throw new Error("Invalid sort")
        }, 15)
        const before = store.get(0).usageCount
        result.copy_bookkeeping = measure(function() {
            store.recordUse("benchmark-0")
        }, 9)
        compare(store.get(0).usageCount, before + 9)
        result.backup_serialization = measure(function() {
            const json = JSON.stringify(store.snippets, null, 2)
            if (!json.length)
                throw new Error("Empty backup")
        }, 9)
        result.reload = measure(function() {
            const saved = store.configValue
            store.loadFromConfig("[]")
            store.loadFromConfig(saved)
        }, 9)
        compare(store.count, data.size)
        compare(store.get(0).usageCount, before + 9)
        console.log("KOPYPAST_BENCHMARK " + JSON.stringify(result))
    }
}
