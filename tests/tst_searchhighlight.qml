/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "SearchHighlighter"
    Local.SearchHighlighter { id: highlighter }

    function test_noMatch() {
        const source = "<img src='https://example.invalid/x'> & literal"
        compare(highlighter.highlight(source, ""), {text: source, highlighted: false})
        compare(highlighter.highlight(source, "  \t "), {text: source, highlighted: false})
        compare(highlighter.highlight(source, "not present"), {text: source, highlighted: false})
    }

    function test_literalEscaping() {
        const source = "<b>Review</b> & <img src='https://example.invalid/x'>"
        compare(highlighter.highlight(source, "review"), {
            text: "&lt;b&gt;<b>Review</b>&lt;/b&gt; &amp; &lt;img src='https://example.invalid/x'&gt;",
            highlighted: true
        })
        compare(highlighter.highlight("<b> & .* $1", "<b> & .* $1"), {
            text: "<b>&lt;b&gt;</b> <b>&amp;</b> <b>.*</b> <b>$1</b>", highlighted: true
        })
    }

    function test_multipleAndUnicode() {
        compare(highlighter.highlight("Review git review", "git REV"), {
            text: "<b>Rev</b>iew <b>git</b> <b>rev</b>iew", highlighted: true
        })
        compare(highlighter.highlight("Čaša C\u030cAS\u030cA", "čAŠa"), {
            text: "<b>Čaša</b> <b>ČAŠA</b>", highlighted: true
        })
        compare(highlighter.highlight("review", "rev review"), {
            text: "<b>review</b>", highlighted: true
        })
    }

    function test_regexMetacharacters() {
        const source = "a[b] {x} \\ ? (x) | ^"
        const result = highlighter.highlight(source, "[b] {x} \\ ? (x) | ^")
        compare(result.highlighted, true)
        compare(result.text, "a<b>[b]</b> <b>{x}</b> <b>\\</b> <b>?</b> <b>(x)</b> <b>|</b> <b>^</b>")
    }
}
