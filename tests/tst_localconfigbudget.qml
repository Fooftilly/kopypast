/*
    SPDX-FileCopyrightText: 2026 Kopypast contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtTest
import "../package/contents/ui" as Local

TestCase {
    name: "LocalConfigurationBudget"
    Local.SnippetModel {
        id: local
        enforceLocalConfigBudget: true
    }
    Local.SnippetModel { id: fileStore }
    SignalSpy { id: refused; target: local; signalName: "localConfigBudgetRejected" }

    function init() {
        local.loadFromConfig("[]")
        fileStore.loadFromConfig("[]")
        refused.clear()
    }

    function test_byteBudget() {
        verify(local.fitsLocalConfigBudget("a".repeat(1024*1024-64)))
        verify(!local.fitsLocalConfigBudget("a".repeat(1024*1024-63)))
        verify(!local.fitsLocalConfigBudget("č".repeat(400000)))
        verify(!local.fitsLocalConfigBudget("\\".repeat(600000)))
        verify(!local.fitsLocalConfigBudget("😀".repeat(200000)))
    }

    function test_mutationsAreAtomic() {
        verify(local.append({title:"Existing", text:"body"}))
        const before = local.configValue
        const huge = "\\".repeat(300000)
        verify(!local.append({title:"Large", text:huge}))
        verify(!local.set(0,{title:"Large",text:huge}))
        compare(local.restoreBackup(JSON.stringify([{title:"Large",text:huge}]),50).status,"write-failed")
        compare(refused.count,3)
        compare(local.configValue,before)
        compare(local.count,1)
        verify(local.set(0,{title:"Small edit",text:"body"}))
        compare(local.get(0).title,"Small edit")
    }

    function test_existingOversizedDataCanBeReduced() {
        const raw = JSON.stringify([{id:"a",title:"Large",text:"x".repeat(1200000)}])
        local.loadFromConfig(raw)
        verify(local.configurationValid)
        compare(local.configValue,raw)
        verify(!local.recordUse("a"))
        compare(local.configValue,raw)
        verify(local.set(0,{title:"Reduced",text:"small"}))
        compare(local.get(0).text,"small")
    }

    function test_fileStoresUseTheirOwnLimit() {
        verify(fileStore.append({title:"Large",text:"x".repeat(1200000)}))
        compare(fileStore.count,1)
    }
}
