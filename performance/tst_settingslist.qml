/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest

Item {
    id: fixture
    width: 900
    height: 650
    property var plasmoid: ({configuration:{maxSnippets:100,defaultTemplate:"",handleVariables:true}})
    function i18n(text, arg) {
        return arg === undefined ? text : text.replace("%1", String(arg))
    }
    function i18np(single, plural, count) {
        return (count === 1 ? single : plural).replace("%1", String(count))
    }

    TestCase {
        name: "SettingsListBenchmark"
        when: windowShown
        function test_scale_data() {
            return [100,1000,10000].map(function(n) { return {tag:String(n), size:n} })
        }

        function test_scale(data) {
            const records = []
            const body = "Example procedure:\n  inspect the configuration and review the results.\nUnicode: čćž 日本語\n"
            for (let i = 0; i < data.size; i++)
                records.push({id:"benchmark-"+i,title:"Snippet "+i,text:body.repeat(4)+"\nIdentifier: "+i,usageCount:i%17,favorite:i%20===0})
            const raw = JSON.stringify(records)
            const component = Qt.createComponent("../package/contents/ui/configSnippets.qml")
            compare(component.status, Component.Ready, component.errorString())
            const load = []
            const jump = []
            for (let iteration = 0; iteration < 5; iteration++) {
                const start = Date.now()
                const page = component.createObject(fixture,{width:fixture.width,height:fixture.height,cfg_snippets:raw})
                verify(page !== null,component.errorString())
                const list = findChild(page,"settingsSnippetList")
                verify(list !== null)
                tryCompare(list,"count",data.size)
                list.forceLayout()
                tryVerify(function() { return list.itemAtIndex(0) !== null })
                verify(waitForRendering(list.itemAtIndex(0)))
                load.push(Date.now()-start)
                const jumpStart = Date.now()
                list.positionViewAtIndex(data.size-1,ListView.End)
                list.forceLayout()
                tryVerify(function() { return list.itemAtIndex(data.size-1) !== null })
                verify(waitForRendering(list.itemAtIndex(data.size-1)))
                jump.push(Date.now()-jumpStart)
                page.destroy()
                wait(0)
            }
            function stats(samples) {
                samples.sort(function(a,b) { return a-b })
                return {median_ms:samples[2],p95_ms:samples[4],samples:samples.length}
            }
            console.log("KOPYPAST_SETTINGS_BENCHMARK "+JSON.stringify({
                records:data.size, utf16_code_units:raw.length, create_and_first_frame:stats(load), jump_to_last_frame:stats(jump)
            }))
        }
    }
}
