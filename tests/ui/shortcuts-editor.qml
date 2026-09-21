import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin
import "WindowPeek/Shortcuts.js" as Shortcuts

ShellRoot {
    id: test
    property int step: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    property var editor: null
    function check(ok,message) { if (!ok) throw new Error(message); }
    function key(code,modifiers) { events.keyClick(code,modifiers || Qt.NoModifier,0); }
    function find(item,name) {
        if (item.objectName === name) return item;
        for(var child of item.children || []) { var found=find(child,name); if(found) return found; }
        return null;
    }
    TestEvent { id: events }
    FakeHost { id: host }
    Window {
        id: window; visible:true; width:540*test.scale; height:900*test.scale
        color:Color.popups.background
        Plugin.PanelContent {
            id: panel; x:20*test.scale; y:20*test.scale; width:500; height:860
            scale:test.scale; transformOrigin:Item.TopLeft; hostWidget:host
        }
    }
    Timer {
        interval:180; running:true; repeat:true
        onTriggered: {
            try {
                switch(test.step++) {
                case 0: panel.begin(); panel.showSettings(); panel.mode="shortcuts"; break;
                case 1:
                    test.editor=test.find(panel,"shortcutsEditor");
                    test.check(!!test.editor && test.editor.probeReady,"editor loaded and probe ready");
                    test.check(!Object.keys(test.editor.errors).length,"default bindings valid");
                    var button=test.find(test.editor,"shortcut-numbers");
                    test.editor.edit(Shortcuts.definitions[1],button); break;
                case 2:
                    var r=test.editor.recorder;
                    test.check(r.visible && !r.recording,"stable popup opens without intercepting desktop shortcuts");
                    r.toggleModifier("Alt"); r.toggleModifier("Ctrl");
                    test.check(r.candidate==="Alt" && !r.problem,"compose modifier family with mouse");
                    r.accept();
                    test.check(test.editor.draft.numbers==="Alt" && host.shortcuts.numbers==="Ctrl","draft does not mutate preferences");
                    test.editor.setValue("next","Up");
                    test.check(!!test.editor.errors.next && !!test.editor.errors.previous,"duplicate local actions rejected");
                    test.editor.setValue("next","Ctrl+N");
                    test.editor.setValue("previous","Ctrl+B");
                    test.editor.setValue("move","Alt+M");
                    test.editor.setValue("privacy","Ctrl+Shift");
                    test.editor.apply(); break;
                case 3:
                    test.check(panel.mode==="settings" && host.shortcuts.numbers==="Alt","Apply saves and returns to settings");
                    panel.back(); break;
                case 4:
                    host.focused=""; test.key(Qt.Key_2,Qt.AltModifier);
                    test.check(host.focused===panel.shortcutAddresses[1],"custom modifier selects exact visible row");
                    host.focused=""; test.key(Qt.Key_Down,Qt.AltModifier|Qt.KeypadModifier);
                    test.check(host.focused===panel.shortcutAddresses[1],"Num Lock off uses same custom modifier");
                    var old=panel.selectedAddress;
                    test.key(Qt.Key_N,Qt.ControlModifier);
                    test.check(panel.selectedAddress!==old && !panel.searchField.text,"custom next action navigates without typing");
                    test.key(Qt.Key_M,Qt.AltModifier);
                    test.check(panel.mode==="move","custom move opens destination form");
                    panel.back(); break;
                case 5:
                    panel.showSettings(); panel.mode="shortcuts"; break;
                case 6:
                    test.editor=test.find(panel,"shortcutsEditor");
                    test.editor.setValue("numbers","Shift");
                    test.editor.cancel();
                    test.check(host.shortcuts.numbers==="Alt","Cancel discards draft");
                    panel.mode="shortcuts"; break;
                case 7:
                    test.editor=test.find(panel,"shortcutsEditor");
                    test.editor.draft=Shortcuts.normalize({}); host.rejectSave=true;
                    test.editor.apply();
                    test.check(panel.mode==="shortcuts" && test.editor.saveFailed && host.shortcuts.numbers==="Alt","save failure retains editor and previous settings");
                    host.rejectSave=false; test.editor.apply(); break;
                case 8:
                    test.check(host.shortcuts.numbers==="Ctrl" && host.shortcuts.privacy==="Shift","restore defaults is durable only on Apply");
                    panel.back(); break;
                case 9:
                    test.key(Qt.Key_Right); test.key(Qt.Key_Left); host.focused=""; test.key(Qt.Key_Return);
                    test.check(!!host.focused,"ordinary Enter still activates the focused window");
                    panel.showSettings(); panel.mode="shortcuts"; host.language="ar"; host.persistSettings({panelStyle:"wallpaper"}); host.wallpaperSource=Qt.resolvedUrl("dropdown-wallpaper.svg"); break;
                case 10:
                    test.editor=test.find(panel,"shortcutsEditor");
                    var path=Quickshell.env("WINDOWPEEK_TEST_IMAGE");
                    if(path) { window.contentItem.grabToImage(function(image) { image.saveToFile(path); console.log("WINDOWPEEK_TEST_PASS"); Qt.quit(); }); }
                    else { console.log("WINDOWPEEK_TEST_PASS"); Qt.quit(); }
                    stop(); break;
                }
            } catch(error) { console.error("FAIL step "+(test.step-1)+": "+error.stack); Qt.exit(1); }
        }
    }
}
