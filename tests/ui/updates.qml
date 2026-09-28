import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Ui as Ui
import qs.Commons
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    property int step: 0
    property int launches: 0
    property int manualChecks: 0
    property int terminals: 0
    property bool startupLaunch: false
    property bool waiting: false
    // Helpers pump Qt's event loop; the repeating driver must never begin the
    // next scenario before the current handler has returned.
    property bool runningStep: false
    TestCase { id: asyncWait; when:false }
    function flush() {
        waiting=true;
        for (var i=0;host.runtime.preferences.saving && i<2000;i++) asyncWait.wait(1);
        waiting=false;
        check(!host.runtime.preferences.saving,"async save completed");
    }
    function check(value, message) { if (!value) throw new Error(message); }
    function screenshot(suffix) {
        var path = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
        if (!path) return;
        var captured = false;
        window.contentItem.grabToImage(function(result) { result.saveToFile(path + suffix); captured = true; });
        test.waiting = true;
        for (var i=0; i<200 && !captured; i++) asyncWait.wait(5);
        test.waiting = false;
        check(captured, "screenshot completed before navigating");
    }
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
        updates.startManualCheck = function(force) { test.manualChecks++; };
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
    function settle() { waiting=true; asyncWait.wait(40); waiting=false; }
    function click(item, x) { events.mouseClick(item, x === undefined ? item.width/2 : x, item.height/2, Qt.LeftButton, Qt.NoModifier, 0); settle(); }
    function assertFits() {
        settle();
        var scroll=find(panel,"editorScroll");
        check(scroll.contentHeight <= scroll.height + 0.01,
            "Updates fits without scrolling: " + scroll.contentHeight + " / " + scroll.height + " " + host.language);
    }
    function manualUpdates() {
        var updates = host.runtime.updates;
        updates.runtimeAvailable=true; updates.manualReady=true;
        updates.startManualCheck=function(force) { test.manualChecks++; };
        updates.startTerminal=function() { test.terminals++; };
        test.manualChecks=0;
        updates.manualResult={}; updates.manualLastLaunch=0;
        updates.checkManual([{opened:true}],1000);
        check(test.manualChecks===0,"manual checks wait for idle");
        updates.checkManual([{opened:false}],1000); updates.checkManual([{opened:false}],1001);
        check(test.manualChecks===1,"checker shared across monitors");
        updates.manualResult={status:"current",lastCheck:1000};
        updates.checkManual([{opened:false}],22599);
        check(test.manualChecks===1,"manual cache lasts six hours");
        updates.checkManual([{opened:false}],22600);
        check(test.manualChecks===2,"cache expires");
        host.persistSettings({autoUpdates:false,checkUpdates:false}); flush();
        updates.checkManual([{opened:false}],50000);
        check(test.manualChecks===2,"notification opt-out stops background metadata checks");
        panel.showSettings(); panel.showUpdates(); settle();
        var action=find(panel,"primaryUpdateAction");
        var history=find(panel,"viewUpdateChanges");
        check(action.text==="Check now" && action.visible,"one primary action checks the current version");
        check(action.fontSize===history.fontSize,"primary action and history use the same readable font size");
        check(!action.textOnly && !history.textOnly && action.width===history.width && action.height===history.height,
            "check and history are equally sized bordered buttons");
        click(action);
        check(test.manualChecks===3 && test.terminals===0,"explicit check works with both options off and installs nothing");
        stableCheckLayout();
        updates.manualResult={status:"available",version:"0.7.3",commit:"a".repeat(40),installedCommit:"b".repeat(40),
            verification:"unverified",lastCheck:Date.UTC(2026,8,28,10,30)/1000}; settle();
        check(action.text==="Update…" && action.enabled,"same primary action offers manual update with both options off");
        check(find(panel,"manualUpdateVerification").text.indexOf("not been verified")>=0,"unverified code is identified");
        assertFits(); screenshot(".available.png");
        click(action); check(test.terminals===1,"one click starts one terminal");
        check(updates.changesUrl().indexOf("/compare/")>=0,"changes link points to checked comparison");
        panel.back(); panel.mode="windows"; panel.searchField.text="Editor"; settle();
        var notice=find(panel,"availableUpdateButton");
        check(!notice.visible,"notification opt-out hides available badge without losing manual results");
        host.persistSettings({checkUpdates:true}); flush(); settle();
        check(notice.visible,"available update appears in expanded list");
        panel.expanded=false; check(!notice.visible,"compact panel stays uncluttered"); panel.expanded=true;
        click(notice); check(panel.mode==="updates","update notice opens shared page");
        panel.back(); settle();
        check(panel.mode==="windows" && panel.searchField.text==="Editor","Back restores search");
        panel.showSettings(); find(panel,"settingsControlsSection").expanded=true;
        find(panel,"updatesEntry").clicked(); settle();
        check(panel.mode==="updates","Settings entry opens same page");
        panel.back(); check(panel.mode==="settings" && find(panel,"settingsControlsSection").expanded,"Back preserves Settings section");
        panel.showUpdates(); settle();
        action=find(panel,"primaryUpdateAction");
        updates.manualResult={status:"available",commit:"bad"};
        check(!updates.manualAvailable && !updates.openManualUpdate(),"invalid state cannot install");
        updates.manualResult={status:"local-changes",reason:"development"}; settle();
        check(action.visible && action.enabled && action.text==="Check now"
            && find(panel,"manualUpdateStatus").text.indexOf("Local development")===0,
            "development copy retains an enabled Check now action");
        var beforeCheck=test.manualChecks, beforeTerminal=test.terminals;
        click(action);
        check(test.manualChecks===beforeCheck+1 && test.terminals===beforeTerminal,
            "development Check now checks without starting an installation");
        check(find(panel,"viewUpdateChanges").visible && !find(panel,"viewUpdateChanges").textOnly,"development copy retains bordered history action");
        assertFits(); screenshot(".development.png");
        check(!updates.openManualUpdate(),"development copy remains protected");
        updates.manualResult={status:"ahead"}; check(!updates.openManualUpdate(),"ahead copy remains protected");
        [{},{status:"current"},{status:"failed"}].forEach(function(result) {
            updates.manualResult=result; settle();
            check(action.visible && action.text==="Check now","no update result presents Check now");
            check(updates.manualCanUpdate,"native worker remains independent of metadata discovery");
        });
        updates.manualResult={status:"available",version:"0.7.3",commit:"a".repeat(40),verification:"unknown",lastCheck:Date.UTC(2026,8,28,10,30)/1000};
        host.persistSettings({language:"pl"}); flush(); settle();
        check(find(panel,"manualUpdateVerification").text.indexOf("Nie udało")>=0,"unknown verification distinct in Polish");
        assertFits(); screenshot(".available-pl.png");
        host.persistSettings({language:"en",autoUpdates:true,checkUpdates:true}); flush();
    }
    function footerAndFocus() {
        var updates=host.runtime.updates;
        updates.manualResult={status:"current"};
        panel.mode="windows"; settle();
        var toggle=find(panel,"updateSwitch"), credit=find(panel,"authorCredit");
        check(toggle.checked && host.autoUpdates,"notifications and auto-install retain enabled defaults");
        var checks=test.manualChecks, terminals=test.terminals;
        click(credit); check(panel.mode==="windows" && find(panel,"projectSupport").opened,"version opens project support, not duplicate Updates");
        click(panel,2);
        click(toggle, toggle.width-5); flush();
        var dialog=find(panel,"updateConfirmation"), primaryOff=find(panel,"cancelUpdateOff"), confirmOff=find(panel,"confirmUpdateOff");
        check(dialog.opened && dialog.notificationMode && toggle.checked,"footer asks before disabling notifications");
        check(confirmOff.width<primaryOff.width && confirmOff.fontSize===primaryOff.fontSize,
            "Turn off is narrower without shrinking its text");
        check(!find(panel,"panelHeader").enabled && !find(panel,"panelFooter").enabled,"confirmation blocks background controls");
        screenshot(".notification-off.png");
        click(primaryOff); flush();
        check(panel.mode==="updates" && toggle.checked && host.autoUpdates,"Open Updates navigates without changing either preference");
        panel.back(Qt.MouseFocusReason); settle();
        check(panel.mode==="windows","Back restores footer confirmation origin");
        click(toggle); events.keyClick(Qt.Key_Escape,Qt.NoModifier,0); settle();
        check(!dialog.opened && toggle.checked && toggle.keyboardFocusVisible,"Escape keeps notifications and returns keyboard focus: "
            + JSON.stringify({opened:dialog.opened,checked:toggle.checked,active:toggle.activeFocus,visual:toggle.visualFocus,
                pointer:toggle.pointerFocus,reason:toggle.focusReason,focused:window.activeFocusItem ? window.activeFocusItem.objectName : "none"}));
        click(toggle); click(panel,2);
        events.mouseMove(credit,credit.width/2,credit.height/2,0,Qt.NoButton,Qt.NoModifier); settle();
        check(!dialog.opened && toggle.checked && !toggle.hot,"mouse close leaves no stale footer focus");
        click(toggle); click(panel,panel.width-2);
        check(!dialog.opened && toggle.checked,"outside dismissal keeps notifications enabled");
        click(toggle); click(confirmOff); flush();
        check(!toggle.checked && host.autoUpdates && panel.mode==="windows","label toggles notifications only");
        click(toggle, 5); flush();
        check(toggle.checked && host.autoUpdates && !dialog.opened,"track enables immediately without a popup");
        check(test.manualChecks===checks && test.terminals===terminals,"footer toggle never starts a worker or terminal");
        find(panel,"hintsToggle").forceActiveFocus(Qt.OtherFocusReason);
        events.keyClick(Qt.Key_Tab,Qt.NoModifier,0);
        check(toggle.keyboardFocusVisible,"Tab visibly focuses notification toggle");
        var query = panel.searchField.text;
        events.keyClick(Qt.Key_Space,Qt.NoModifier,0); settle();
        check(panel.searchField.activeFocus && !dialog.opened,"space from the main-list footer continues typing");
        panel.searchField.text = query;
        toggle.forceActiveFocus(Qt.TabFocusReason);
        events.keyClick(Qt.Key_Return,Qt.NoModifier,0); settle();
        check(dialog.opened && toggle.checked,"Enter requests the same opt-out confirmation");
        events.keyClick(Qt.Key_Tab,Qt.NoModifier,0);
        events.keyClick(Qt.Key_Space,Qt.NoModifier,0); flush();
        check(!toggle.checked && toggle.keyboardFocusVisible,"notification toggle works with keyboard " + JSON.stringify({checked:toggle.checked, focus:toggle.activeFocus, visual:toggle.visualFocus, pointer:toggle.pointerFocus, key:toggle.keyboardFocusVisible}));
        click(toggle); flush(); events.mouseMove(credit,credit.width/2,credit.height/2,0,Qt.NoButton,Qt.NoModifier);
        check(toggle.checked && !toggle.hot,"mouse use clears old keyboard highlighting");
        panel.showSettings(); panel.showUpdates(); settle();
        var primary=find(panel,"primaryUpdateAction"), notifications=find(panel,"manualUpdateChecksToggle");
        check(!primary.hot,"opening Updates does not highlight primary action");
        click(notifications); flush(); check(!toggle.checked,"page and footer share notification setting");
        click(toggle); flush(); check(notifications.checked,"footer changes update page immediately");
        events.mouseMove(credit,credit.width/2,credit.height/2,0,Qt.NoButton,Qt.NoModifier);
        check(!primary.hot,"version hover cannot highlight primary action");
        find(panel,"viewUpdateChanges").forceActiveFocus(Qt.OtherFocusReason);
        events.keyClick(Qt.Key_Backtab,Qt.ShiftModifier,0);
        check(primary.keyboardFocusVisible,"primary action has a visible keyboard cue");
        checks=test.manualChecks;
        events.keyClick(Qt.Key_Return,Qt.NoModifier,0);
        check(test.manualChecks===checks+1,"keyboard checks once");
        click(primary); events.mouseMove(credit,credit.width/2,credit.height/2,0,Qt.NoButton,Qt.NoModifier);
        check(!primary.hot,"keyboard then mouse leaves no stale highlight");
    }
    function footerNavigation() {
        var toggle=find(panel,"updateSwitch"), dialog=find(panel,"updateConfirmation");
        panel.mode="labels"; settle();
        var editor=find(panel,"labelsEditor");
        editor.setStyle("custom");editor.setText("panelTitle","Unsaved title");
        var draft=JSON.stringify(editor.draft());
        click(toggle);click(find(panel,"cancelUpdateOff"));
        check(panel.mode==="updates" && !dialog.opened,"footer route works from a nested editor");
        panel.back(Qt.MouseFocusReason);settle();
        check(panel.mode==="labels" && find(panel,"labelsEditor")===editor
            && JSON.stringify(editor.draft())===draft,"Updates preserves the exact editor instance and unsaved draft: "
            + JSON.stringify({mode:panel.mode,origin:panel.updatesReturnMode,same:find(panel,"labelsEditor")===editor,
                expected:draft,actual:find(panel,"labelsEditor") ? JSON.stringify(find(panel,"labelsEditor").draft()) : "missing"}));
        editor.cancel(Qt.MouseFocusReason);settle();
        panel.mode="support";settle();
        find(panel,"supportSection0").expanded=true;
        click(toggle);click(find(panel,"cancelUpdateOff"));panel.back(Qt.MouseFocusReason);settle();
        check(panel.mode==="support" && find(panel,"supportSection0").expanded,"help expansion survives visiting Updates");
        panel.showSettings();panel.showUpdates();settle();
        click(toggle);click(find(panel,"cancelUpdateOff"));
        check(panel.mode==="updates" && !dialog.opened && toggle.checked,"Open Updates while already there closes the popup without changing state");
        click(toggle);host.persistSettings({checkUpdates:false});flush();click(find(panel,"confirmUpdateOff"));flush();
        check(!toggle.checked,"confirmation cannot re-enable another monitor's opt-out");
        click(toggle);flush();
        host.runtime.preferences.readBlocked=true;
        click(toggle);click(find(panel,"confirmUpdateOff"));flush();
        check(toggle.checked,"failed notification save preserves the original setting");
        host.runtime.preferences.readBlocked=false;
    }
    function automaticConfirmation() {
        var auto=find(panel,"automaticUpdatesToggle"), cancel=find(panel,"cancelUpdateOff"), confirm=find(panel,"confirmUpdateOff");
        var footer=find(panel,"updateSwitch"), credit=find(panel,"authorCredit");
        check(auto.checked && footer.checked,"default-on settings are independent");
        click(auto); check(cancel.visible && host.autoUpdates,"automatic opt-out asks for confirmation");
        events.keyClick(Qt.Key_Return,Qt.NoModifier,0); settle();
        check(!cancel.visible && host.autoUpdates && auto.visualFocus,"default Enter cancels and returns keyboard focus");
        click(auto); click(cancel);
        events.mouseMove(credit,credit.width/2,credit.height/2,0,Qt.NoButton,Qt.NoModifier); settle();
        check(!auto.hot && !footer.hot,"mouse Cancel leaves neither switch highlighted " + JSON.stringify({autoHot:auto.hot,autoVisual:auto.visualFocus,autoPointer:auto.pointerFocus,autoFocus:auto.activeFocus,footerHot:footer.hot,footerHovered:footer.hovered,footerVisual:footer.visualFocus,dialog:cancel.visible}));
        click(auto); click(confirm); flush();
        check(!host.autoUpdates && footer.checked,"auto opt-out preserves notifications");
        events.mouseMove(credit,credit.width/2,credit.height/2,0,Qt.NoButton,Qt.NoModifier); settle();
        check(!auto.hot,"mouse confirmation clears focus styling");
        click(auto); flush(); check(host.autoUpdates,"enabling automatic installation needs no confirmation");
        click(auto); click(panel, panel.width-2);
        check(!cancel.visible && host.autoUpdates,"outside dismissal preserves automatic choice");
        click(auto); host.persistSettings({autoUpdates:false}); flush(); click(confirm); flush();
        check(!host.autoUpdates,"confirmation cannot undo another monitor's opt-out");
        host.persistSettings({autoUpdates:true}); flush();
        host.runtime.preferences.readBlocked=true; click(auto); click(confirm); flush();
        check(host.autoUpdates && auto.checked,"failed save preserves saved state");
        host.runtime.preferences.readBlocked=false;
    }
    function stableCheckLayout() {
        var updates=host.runtime.updates, start=updates.startManualCheck;
        var button=find(panel,"primaryUpdateAction"), status=find(panel,"manualUpdateStatus"), toggle=find(panel,"manualUpdateChecksToggle");
        waiting=true;
        try {
            asyncWait.wait(30);
            var before={height:status.height,buttonY:button.y,toggleY:toggle.y};
            updates.startManualCheck=function(force) {
                updates.manualCheck.command=["python3","-c","import time; time.sleep(0.4)"]; updates.manualCheck.running=true;
            };
            button.clicked(); asyncWait.wait(50);
            check(updates.manualBusy && !button.enabled && button.text==="Check now","checking does not flash the button label");
            check(status.text==="Checking…" && status.height===before.height,"checking uses reserved status height");
            check(button.y===before.buttonY && toggle.y===before.toggleY,"controls stay put while checking");
            for(var i=0;i<200 && updates.manualBusy;i++) asyncWait.wait(5);
            check(status.text==="Checking…","fast result remains legible");
            for(var i=0;i<200 && !button.enabled;i++) asyncWait.wait(5);
            check(button.y===before.buttonY && toggle.y===before.toggleY,"same result preserves layout");
        } finally { updates.startManualCheck=start; waiting=false; }
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
        visible: true; width: 500 * test.scale; height: 540 * test.scale; color: Color.popups.background
        Rectangle { anchors.fill: parent; color: Color.popups.background }
        Plugin.Widget { id: host; bar: bar; visible: false }
        Plugin.PanelContent {
            id: panel; x:16*test.scale; y:16*test.scale; width: window.width / test.scale - 32; height: window.height / test.scale - 32
            scale: test.scale; transformOrigin: Item.TopLeft; hostWidget: host
        }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (test.runningStep || test.waiting || host.runtime.preferences.saving || !host.settingsReady || !host.runtime.updates.ready || !host.updatesAvailable) return;
            test.runningStep = true;
            try {
                switch (test.step++) {
                case 0:
                    Color.shellValues={}; Color.foreground="#c0caf5"; Color.background="#1a1b26"; Color.accent="#d898f5";
                    test.scheduler(); panel.begin(); break;
                case 1: test.manualUpdates(); break;
                case 2: test.footerAndFocus(); break;
                case 3: test.footerNavigation(); test.automaticConfirmation(); break;
                case 4: console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.callLater(Qt.quit); break;
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.callLater(Qt.quit); }
            finally { test.runningStep = false; }
        }
    }
}
