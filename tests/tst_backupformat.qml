/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "BackupFormat"
    Local.BackupFormat { id: codec }
    Local.SnippetModel { id: source }
    Local.SnippetModel { id: target }

    function init() {
        source.loadFromConfig("[]")
        target.loadFromConfig("[]")
    }

    function test_roundTrip() {
        source.append({title: "α", text: "  <b>literal</b>\n\tčćž 日本語"})
        const id = source.get(0).id
        source.setFavorite(id, true)
        source.recordUse(id)
        const exported = codec.encode(source.snippets)
        const envelope = JSON.parse(exported)
        compare(envelope.format, "io.github.fooftilly.kopypast")
        compare(envelope.version, 1)
        const decoded = codec.decode(exported)
        compare(decoded.status, "ok")
        compare(target.restoreBackup(decoded.content, 50).status, "restored")
        compare(target.snippets, source.snippets)
    }

    function test_legacy() {
        const raw = '[{"title":"Legacy","text":"body"}]'
        const result = codec.decode(raw)
        compare(result.status, "ok")
        compare(result.content, raw)
        compare(target.restoreBackup(result.content, 50).status, "restored")
        compare(target.get(0).title, "Legacy")
    }

    function test_invalidEnvelope_data() {
        return [
            {tag: "malformed", raw: "[", status: "invalid-format"},
            {tag: "null", raw: "null", status: "invalid-format"},
            {tag: "wrong-format", raw: '{"format":"other","version":1,"snippets":[]}', status: "invalid-format"},
            {tag: "future", raw: '{"format":"io.github.fooftilly.kopypast","version":2,"snippets":[]}', status: "unsupported-version"},
            {tag: "string-version", raw: '{"format":"io.github.fooftilly.kopypast","version":"1","snippets":[]}', status: "unsupported-version"},
            {tag: "missing-records", raw: '{"format":"io.github.fooftilly.kopypast","version":1}', status: "invalid-format"},
            {tag: "not-array", raw: '{"format":"io.github.fooftilly.kopypast","version":1,"snippets":{}}', status: "invalid-format"}
        ]
    }

    function test_invalidEnvelope(data) {
        compare(codec.decode(data.raw).status, data.status)
    }

    function test_modelValidationAndCapacity() {
        target.append({title: "Existing", text: "body"})
        const before = target.configValue
        const invalid = codec.decode(codec.encode([{title: "valid", text: "body"}, null]))
        compare(invalid.status, "ok")
        compare(target.restoreBackup(invalid.content, 50).status, "invalid-record")
        compare(target.configValue, before)
        const decoded = codec.decode(codec.encode([{title: "Existing", text: "body"}, {title: "Second", text: "two"}, {title: "Third", text: "three"}]))
        const result = target.restoreBackup(decoded.content, 2)
        compare(result.status, "partial")
        compare(result.count, 1)
        compare(result.duplicates, 1)
        compare(target.count, 2)
    }
}
