import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property real fullHeight: 0
    property real logoHeight: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function key(code, mods) { events.keyClick(code, mods || Qt.NoModifier, 0); }
    FakeHost {
        id: host
        Component.onCompleted: {
            persistSettings({hintsMode:"off"});
            var data=JSON.parse(JSON.stringify(snapshot));
            for (var i=6;i<=30;i++) data.clients.push({address:"0x"+i.toString(16),title:"Fictional document "+i,workspace:{id:4,name:"4"}});
            snapshot=data;
        }
    }
    Window {
        visible: true; width: 540*test.scale; height: 900*test.scale
        TestEvent { id: events }
        Plugin.PanelContent {
            id: panel; hostWidget: host; width: 466; height: implicitHeight
            scale: test.scale; transformOrigin: Item.TopLeft
            onExpandRequested: { expanded=true; promote(); }
            onCloseRequested: dismiss()
        }
    }
    Timer {
        interval:160; running:true; repeat:true
        onTriggered: {
            try {
                switch(test.step++) {
                case 0: panel.begin(); break;
                case 1: test.fullHeight=panel.height; panel.expanded=false; panel.demote(); break;
                case 2:
                    test.check(Math.abs(test.fullHeight-panel.height)<1,"logo keeps hover and expanded heights equal");
                    test.logoHeight=panel.height; panel.forceActiveFocus(); test.key(Qt.Key_End); break;
                case 3:
                    test.check(panel.selectedAddress===panel.matches[panel.matches.length-1].address && panel.contentY>0,"hover End reaches last window");
                    test.key(Qt.Key_Home); test.check(panel.selectedAddress===panel.matches[0].address && panel.contentY===0,"hover Home");
                    test.key(Qt.Key_PageDown); test.check(panel.contentY>0,"hover Page Down");
                    test.key(Qt.Key_PageUp); test.check(panel.contentY===0,"hover Page Up");
                    test.key(Qt.Key_Down); test.check(panel.selectedAddress===panel.matches[1].address,"hover Down");
                    test.key(Qt.Key_Up); test.check(panel.selectedAddress===panel.matches[0].address,"hover Up");
                    host.focused=""; test.key(Qt.Key_Return); test.check(host.focused===panel.selectedAddress,"hover Enter");
                    host.focused=""; test.key(Qt.Key_Space); test.check(host.focused===panel.selectedAddress,"hover Space");
                    host.persistSettings({shortcuts:{last:"F6"}}); break;
                case 4:
                    test.check(panel.shortcutModifierState.hoverBindings.some(function(b){return b.id==="last" && b.chord==="F6";}),"native hover lease follows changed shortcut");
                    test.key(Qt.Key_F6); test.check(panel.selectedAddress===panel.matches[panel.matches.length-1].address,"hover remapped End");
                    test.key(Qt.Key_Return,Qt.ShiftModifier); break;
                case 5:
                    test.check(panel.expanded && panel.mode==="move","Shift Enter expands the move editor");
                    panel.back(); panel.expanded=false; panel.demote(); panel.forceActiveFocus(); test.key(Qt.Key_Tab); break;
                case 6:
                    test.check(panel.expanded,"Tab enters full keyboard controls");
                    panel.expanded=false; panel.demote(); host.persistSettings({hoverLogo:false}); break;
                case 7:
                    test.check(panel.height<test.logoHeight-50,"turning logo off restores compact hover height");
                    panel.maximumHeight=270; break;
                case 8:
                    test.check(panel.height<=270,"short display limits hover height");
                    panel.forceActiveFocus(); test.key(Qt.Key_Escape);
                    test.check(!panel.opened,"hover Escape dismisses");
                    panel.begin(false);break;
                case 9:
                    panel.searchField.forceActiveFocus();
                    test.key(Qt.Key_A,Qt.ControlModifier);
                    test.check(!panel.expanded && !panel.searchField.text,"non-text chord does not expand or insert text");
                    test.key(Qt.Key_P);test.key(Qt.Key_R);test.key(Qt.Key_O);break;
                case 10:
                    test.check(panel.expanded && panel.searchField.activeFocus && panel.searchField.text==="pro","typing expands immediately without losing fast keystrokes");
                    test.key(Qt.Key_Backspace);
                    test.check(panel.searchField.text==="pr","search editing continues after expansion");
                    test.check(panel.shortcutModifierState.hoverBindings.length===0,"expanded panel releases hover shortcuts");
                    host.persistSettings({shortcuts:{last:"F7"}}); host.language="ar"; break;
                case 11:
                    panel.expanded=false; panel.demote();
                    var bindings=panel.shortcutModifierState.hoverBindings;
                    test.check(bindings.some(function(b){return b.id==="last" && b.chord==="F7";})
                        && !bindings.some(function(b){return b.id==="last" && b.chord==="F6";}),"collapse uses shortcut edited while expanded");
                    test.check(bindings.some(function(b){return b.id==="windowside" && b.chord==="RIGHT";}),"cached hover shortcuts follow RTL language changes");
                    console.log("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch(error) { console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error); stop(); Qt.quit(); }
        }
    }
}
