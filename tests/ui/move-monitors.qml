import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import QtTest
import Quickshell
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

ShellRoot {
    id: test
    property int step: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    property var original
    function check(ok, text) { if (!ok) throw new Error(text); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    function click(item, modifiers) { events.mouseClick(item,item.width/2,item.height/2,Qt.LeftButton,modifiers || Qt.NoModifier,0); }
    function choose(key, modifiers) { events.keyClick(key,Qt.NoModifier,0); events.keyClick(Qt.Key_Return,modifiers || Qt.NoModifier,0); }
    function openMenu() { host.moved=""; menu.show("0x1",Qt.point(100,100)); }
    FakeHost { id: host; Component.onCompleted: savedAppearance=Appearance.normalize({uiScale:test.scale}) }
    TestEvent { id: events }
    Window {
        id: window; visible:true; width:550*test.scale; height:1000*test.scale
        Plugin.PanelContent {
            id:panel; x:20*test.scale; y:20*test.scale; width:500; height:900; maximumHeight:900
            scale:test.scale; transformOrigin:Item.TopLeft; hostWidget:host
            Binding { target:panel.QQC.Overlay.overlay; property:"transformOrigin"; value:Item.TopLeft }
            Binding { target:panel.QQC.Overlay.overlay; property:"scale"; value:test.scale }
        }
        Plugin.MoveMenu { id:menu; hostWidget:host }
    }
    Timer {
        interval:130; running:true; repeat:true
        onTriggered: {
            try {
                var picker=test.find(panel,"destinationPicker"), monitors=test.find(panel,"moveMonitorPicker");
                switch(test.step++) {
                case 0: test.original=JSON.parse(JSON.stringify(host.snapshot)); panel.begin(false); test.openMenu(); break;
                case 1: test.choose(Qt.Key_2); break;
                case 2:
                    test.check(menu.choosingMonitor && !host.moved && menu.filtered.length===2,"new workspace waits for explicit monitor");
                    test.click(menu.list.itemAtIndex(1));
                    test.check(host.moved==="0x1:2" && host.movedMonitor==="TEST-B","mouse monitor choice dispatches exact target");
                    host.moveCompleted(); test.openMenu(); break;
                case 3: test.choose(Qt.Key_3,Qt.ShiftModifier); break;
                case 4:
                    test.check(host.moved==="0x1:3" && host.movedMonitor==="TEST-A" && !menu.choosingMonitor,"Shift+Enter uses invoking monitor for new workspace");
                    host.moveCompleted(); test.openMenu(); break;
                case 5: menu.searchField.text="3"; break;
                case 6:
                    test.click(menu.list.itemAtIndex(0),Qt.ShiftModifier);
                    test.check(host.moved==="0x1:3" && host.movedMonitor==="TEST-A","Shift+click has the same behavior");
                    host.moveCompleted(); test.openMenu(); break;
                case 7: test.choose(Qt.Key_4,Qt.ShiftModifier); break;
                case 8:
                    test.check(host.moved==="0x1:4" && host.movedMonitor==="TEST-B","Shift never relocates an existing workspace");
                    host.moveCompleted(); test.openMenu(); break;
                case 9: test.choose(Qt.Key_2); break;
                case 10: events.keyClick(Qt.Key_Escape,Qt.NoModifier,0); break;
                case 11:
                    test.check(menu.opened && !menu.choosingMonitor && menu.searchField.text==="2" && !host.moved,"Back restores workspace step and its search");
                    events.keyClick(Qt.Key_Return,Qt.NoModifier,0); break;
                case 12: test.click(test.find(menu,"moveMenuBack")); break;
                case 13:
                    test.check(menu.opened && !menu.choosingMonitor,"visible Back returns through actual steps");
                    events.keyClick(Qt.Key_Return,Qt.NoModifier,0); break;
                case 14:
                    events.mouseClick(menu.card,20,20,Qt.RightButton,Qt.NoModifier,0); break;
                case 15:
                    test.check(menu.opened && !menu.choosingMonitor,"right-click returns to workspace choice");
                    menu.close(); panel.openMove("0x1"); break;
                case 16: test.check(picker.popupOpen,"Move form opens workspace picker"); test.choose(Qt.Key_2); break;
                case 17:
                    test.check(monitors.popupOpen && !panel.moveDestinationReady && !host.moved,"Move form requests monitor and cannot submit early");
                    test.choose(Qt.Key_B); break;
                case 18:
                    test.check(panel.destinationMonitor==="TEST-B" && panel.moveDestinationReady,"monitor is selected by keyboard");
                    test.check(host.moved==="0x1:2" && host.movedMonitor==="TEST-B","monitor selection immediately moves without confirmation");
                    host.moveCompleted(); host.moved=""; panel.openMove("0x1"); break;
                case 19:
                    test.check(picker.value==="" && monitors.value==="","reopening does not display an old destination or monitor");
                    test.choose(Qt.Key_3,Qt.ShiftModifier); break;
                case 20:
                    test.check(panel.destinationMonitor==="TEST-A" && !monitors.popupOpen && panel.moveDestinationReady,"Shift selects monitor without another popup in Move form");
                    test.check(host.movedMonitor==="TEST-A","Shift selection immediately moves to the invoking monitor");
                    host.moveCompleted(); host.moved=""; panel.openMove("0x1"); break;
                case 21: test.choose(Qt.Key_4,Qt.ShiftModifier); break;
                case 22:
                    test.check(!monitors.visible && panel.destinationMonitor==="TEST-B" && test.find(panel,"moveDestinationMonitor").text.indexOf("TEST-B")>=0,"existing workspace displays its monitor");
                    test.check(host.moved === "0x1:4" && host.movedMonitor === "TEST-B", "existing workspace moves immediately without relocating it");
                    host.moveCompleted(); host.moved=""; panel.openMove("0x1"); break;
                case 23: test.choose(Qt.Key_2); break;
                case 24:
                    test.click(test.find(panel.QQC.Overlay.overlay,"dropdownCancel")); break;
                case 25:
                    test.check(panel.mode === "windows" && !host.moved,"mouse Cancel in monitor list aborts the whole move");
                    panel.openMove("0x1"); break;
                case 26:
                    test.click(test.find(panel.QQC.Overlay.overlay,"dropdownCancel")); break;
                case 27:
                    test.check(panel.mode === "windows" && !host.moved,"mouse Cancel in workspace list aborts without moving");
                    panel.openMove("0x1"); break;
                case 28: test.choose(Qt.Key_2); break;
                case 29:
                    events.keyClick(Qt.Key_Escape,Qt.NoModifier,0); break;
                case 30:
                    test.check(!monitors.popupOpen && !host.moved,"Escape closes monitor selection without moving");
                    test.click(test.find(panel,"moveWorkspaceBack")); break;
                case 31:
                    test.check(picker.popupOpen && panel.destination==="" && !host.moved,"mouse Back returns to workspace step");
                    events.keyClick(Qt.Key_Escape,Qt.NoModifier,0); break;
                case 32: test.click(test.find(panel,"cancelMove")); break;
                case 33:
                    test.check(panel.mode==="windows" && !host.moved,"visible Cancel aborts with pickers closed");
                    test.openMenu(); break;
                case 34: test.click(test.find(menu,"moveMenuCancel")); break;
                case 35:
                    test.check(!menu.opened && !host.moved,"compact menu Cancel aborts workspace step");
                    test.openMenu(); break;
                case 36: test.choose(Qt.Key_2); break;
                case 37: test.click(test.find(menu,"moveMenuCancel")); break;
                case 38:
                    test.check(!menu.opened && !host.moved,"compact menu Cancel aborts monitor step");
                    var data=JSON.parse(JSON.stringify(host.snapshot)); data.monitors=[data.monitors[0]]; host.snapshot=data;
                    test.openMenu(); break;
                case 39: test.choose(Qt.Key_3); break;
                case 40:
                    test.check(host.moved==="0x1:3" && host.movedMonitor==="TEST-A" && !menu.choosingMonitor,"one-monitor setup needs no redundant choice");
                    host.moveCompleted(); host.snapshot=test.original; host.moved=""; panel.openMove("0x1"); break;
                case 41:
                    test.find(panel.QQC.Overlay.overlay,"dropdownSearchField").text="2"; break;
                case 42:
                    test.click(test.find(panel.QQC.Overlay.overlay,"resultList").itemAtIndex(0)); break;
                case 43:
                    test.check(monitors.popupOpen && !host.moved,"mouse workspace choice waits for monitor");
                    test.click(test.find(panel.QQC.Overlay.overlay,"resultList").itemAtIndex(1)); break;
                case 44:
                    test.check(host.moved==="0x1:2" && host.movedMonitor==="TEST-B","mouse monitor choice moves immediately in full wizard");
                    host.moveCompleted(); host.moved=""; panel.openMove("0x1"); break;
                case 45: test.choose(Qt.Key_2); break;
                case 46:
                    var reduced=JSON.parse(JSON.stringify(host.snapshot)); reduced.monitors=[reduced.monitors[0]]; host.snapshot=reduced; break;
                case 47:
                    test.check(monitors.filtered.length===1 && monitors.filtered[0].value==="TEST-A" && !host.moved,"disconnected monitor disappears before any move is dispatched");
                    test.choose(Qt.Key_A); break;
                case 48:
                    test.check(host.moved==="0x1:2" && host.movedMonitor==="TEST-A","remaining monitor can be chosen after disconnect");
                    host.moveCompleted(); host.snapshot=test.original;
                    console.log("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch(e) { console.error("WINDOWPEEK_TEST_FAIL: " + e + " step="+(test.step-1)); stop(); Qt.quit(); }
        }
    }
}
