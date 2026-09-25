import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Ui as Ui
import qs.Commons
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property int launches: 0
    property bool startupLaunch: false
    property var control: null
    property var confirmation: null
    property bool waiting: false
    TestCase { id: asyncWait; when:false }
    function flush() {
        waiting=true;
        for (var i=0;host.runtime.preferences.saving && i<2000;i++) asyncWait.wait(1);
        waiting=false;
        check(!host.runtime.preferences.saving,"async save completed");
    }
    function check(value, message) { if (!value) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        var children = item.children || [];
        for (var i = 0; i < children.length; i++) {
            var result = find(children[i], name);
            if (result) return result;
        }
        return null;
    }
    function scheduler() {
        var updates = host.runtime.updates;
        var prefs = host.runtime.preferences;
        updates.runtimeAvailable = true;
        updates.launch = function(startup) { test.launches++; test.startupLaunch = startup; };
        updates.nextCheck = 0; updates.lastCheck = 0; updates.lastLaunch = 0; updates.startupPending = true;
        var quiet = {opened:false, hoverOpened:false, actionBusy:false};
        try {
            check(updates.enabled, "saved default enables updates");
            ["opened", "hoverOpened", "actionBusy"].forEach(function(key) {
                var busy = {opened:false, hoverOpened:false, actionBusy:false}; busy[key] = true;
                updates.check([quiet, busy], 1000);
                check(test.launches === 0, key + " on another monitor defers the check");
            });
            var payload = prefs.lastPayload;
            prefs.lastPayload = "";
            updates.check([quiet], 1000);
            check(!updates.enabled && test.launches === 0, "unsaved preferences cannot start a worker");
            prefs.lastPayload = payload;
            prefs.failed = true; updates.check([quiet], 1000);
            check(test.launches === 0, "failed save blocks the worker");
            prefs.failed = false; prefs.readBlocked = true; updates.check([quiet], 1000);
            check(test.launches === 0, "unreadable preferences block the worker");
            prefs.readBlocked = false;
            updates.check([quiet], 1000); updates.check([quiet], 1000);
            check(test.launches === 1, "monitor timers share one launch throttle");
            updates.check([quiet], 1299);
            check(test.launches === 1, "failed worker startup is not retried every tick");
            updates.check([quiet], 1300);
            check(test.launches === 2, "worker startup can be retried");
            updates.lastCheck = 1000; updates.nextCheck = 87400; updates.lastLaunch = 0; updates.startupPending = true;
            updates.check([quiet], 1001);
            check(test.launches === 2, "a restart on the same day does not add a check");
            updates.check([quiet], 22599);
            check(test.launches === 2, "old daily schedule waits for the six-hour deadline");
            updates.check([quiet], 22600);
            check(test.launches === 3 && !test.startupLaunch, "check becomes due after six hours from the previous attempt");
            var yesterday = new Date(2026,8,20,23,30).getTime()/1000;
            var today = new Date(2026,8,21,0,15).getTime()/1000;
            updates.lastCheck = yesterday; updates.nextCheck = yesterday + 21600; updates.lastLaunch = 0;
            updates.check([quiet], today);
            check(test.launches === 3,"midnight alone does not break the six-hour cadence");
            updates.startupPending = true; updates.check([quiet],today);
            check(test.launches === 4 && test.startupLaunch,"first startup of a new day requests its check");
            updates.lastCheck = today; updates.nextCheck = today+21600; updates.lastLaunch = 0;
            updates.startupPending = true; updates.check([quiet],today+60);
            check(test.launches === 4,"another startup the same day keeps the recorded deadline");
            host.persistSettings({autoUpdates:false}); test.flush();
            updates.check([quiet], 200000);
            check(!updates.enabled && test.launches === 4, "saved opt-out blocks checks");
            host.persistSettings({autoUpdates:"true"}); test.flush();
            updates.check([quiet], 200000);
            check(!updates.enabled && !host.autoUpdates && test.launches === 4, "invalid opt-in does not start a worker");
            host.persistSettings({autoUpdates:true}); test.flush();
        } finally { updates.runtimeAvailable = false; }
    }
    QtObject {
        id: shell
        function updateEntryInline(id, values) { return true; }
    }
    Ui.PluginBarApi {
        id: bar
        pluginId: "sarr.windowpeek"; moduleName: "sarr.windowpeek"; shell: shell
        position: "top"; barSize: 26; fontFamily: "monospace"
        layoutConfig: ({left:[{id:"sarr.windowpeek", language:"en"}], center:[], right:[]})
        _moduleWidgets: function() { return [host]; }
    }
    TestEvent { id: events }
    Window {
        id: window
        visible: true; width: 500; height: 490; color: Color.popups.background
        Plugin.Widget { id: host; bar: bar; visible: false }
        Plugin.PanelContent { id: panel; anchors.fill: parent; hostWidget: host }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (test.waiting || host.runtime.preferences.saving || !host.settingsReady || !host.runtime.updates.ready || !host.updatesAvailable) return;
            try {
                switch (test.step++) {
                case 0:
                    test.scheduler(); panel.begin();
                    test.control = test.find(panel, "updateSwitch");
                    test.confirmation = test.find(panel, "cancelUpdateOff");
                    test.check(test.control.checked, "footer reflects saved enabled default");
                    break;
                case 1: test.control.clicked(); break;
                case 2:
                    test.check(test.confirmation.visible && host.autoUpdates, "off requires confirmation");
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 0); break;
                case 3:
                    test.check(!test.confirmation.visible && host.autoUpdates, "default Enter cancels");
                    test.control.clicked(); break;
                case 4: events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0); break;
                case 5:
                    test.check(!test.confirmation.visible && host.autoUpdates, "Escape cancels");
                    test.control.clicked(); test.confirmation.clicked();
                    test.check(host.autoUpdates, "Cancel keeps updates enabled");
                    test.control.clicked(); test.find(panel, "confirmUpdateOff").clicked(); test.flush();
                    test.check(!host.autoUpdates && !test.control.checked
                        && host.runtime.preferences.values.autoUpdates === false, "explicit confirmation is saved");
                    test.control.clicked(); test.flush();
                    test.check(host.autoUpdates && test.control.checked, "enabling needs no confirmation");
                    // Another monitor may save an opt-out while the dialog is open.
                    test.control.clicked(); host.persistSettings({autoUpdates:false}); test.flush();
                    test.find(panel, "confirmUpdateOff").clicked(); test.flush();
                    test.check(!host.autoUpdates, "confirming an existing opt-out cannot toggle it back on");
                    host.persistSettings({autoUpdates:true}); test.flush();
                    host.runtime.preferences.readBlocked = true;
                    test.control.clicked(); test.find(panel, "confirmUpdateOff").clicked(); test.flush();
                    test.check(host.autoUpdates && test.control.checked, "failed save cannot confirm an unsaved opt-out");
                    host.runtime.preferences.readBlocked = false;
                    if (Quickshell.env("WINDOWPEEK_TEST_IMAGE"))
                        window.contentItem.grabToImage(function(result) { result.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE")); });
                    break;
                case 6: console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit(); break;
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
