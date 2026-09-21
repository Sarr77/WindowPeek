import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import "WindowPeek" as Plugin
import "WindowPeek/Shortcuts.js" as Shortcuts
import "WindowPeek/ShortcutBindings.js" as Lua

ShellRoot {
    id: test
    property int step: 0
    property int attempts: 0
    property int fired: 0
    property var editor: null
    readonly property string token: Date.now().toString(36)
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property bool compileOnly: Quickshell.env("WINDOWPEEK_TEST_COMPILE_ONLY") === "1"
    function check(ok,message) { if(!ok) throw new Error(message); }
    function find(item,name) { if(item.objectName===name) return item; for(var child of item.children||[]) { var found=find(child,name); if(found) return found; } return null; }
    function wait(ok,message) { if(ok) { attempts=0; return false; } if(++attempts>15) throw new Error(message); step--; return true; }
    function cleanup() {
        keys.running=false; panel.dismiss();
        Hyprland.dispatch(Lua.dispatch("local s=_windowpeek_recorder_test; if s then s.stop(); _windowpeek_recorder_test=nil end; "));
    }
    function hold(modifier) { keys.command=[Quickshell.env("WINDOWPEEK_TEST_KEYBOARD"),modifier]; keys.running=true; }
    FakeHost {
        id: host
        function chooseDestination(address,position) {
            destinationRequested=address; moveMenuOpen=true; menu.show(address,position);
        }
    }
    TestEvent { id: events }
    Process {
        id: keys; stdinEnabled:true
        property bool ready:false
        stdout: SplitParser { onRead:function(line) { if(line==="pressed") keys.ready=true; } }
        onExited: ready=false
    }
    Connections {
        target:Hyprland
        function onRawEvent(event) { if(event.name==="custom" && event.data==="windowpeek-recorder-test,"+test.token) test.fired++; }
    }
    PanelWindow {
        id: window; visible:!test.compileOnly
        WlrLayershell.namespace:"windowpeek-shortcuts-test"
        WlrLayershell.layer:WlrLayer.Overlay; WlrLayershell.keyboardFocus:WlrKeyboardFocus.Exclusive
        exclusionMode:ExclusionMode.Ignore
        implicitWidth:Math.min(screen.width,540*test.scale); implicitHeight:Math.min(screen.height,940*test.scale)
        color:Color.popups.background
        Plugin.PanelContent {
            id:panel; x:20; y:20; width:(window.width-40)/test.scale; height:(window.height-40)/test.scale
            scale:test.scale; transformOrigin:Item.TopLeft; hostWidget:host
        }
    }
    Plugin.MoveMenu {
        id: menu; parent: window.contentItem; hostWidget: host
        onOpenedChanged: host.moveMenuOpen=opened
    }
    Component.onDestruction: if(!compileOnly) cleanup()
    Timer {
        interval:180; running:true; repeat:true
        onTriggered: {
            try {
                if(test.compileOnly) { console.info("WINDOWPEEK_TEST_PASS compile only"); stop(); Qt.quit(); return; }
                switch(test.step++) {
                case 0: host.saveAppearance({uiScale:test.scale}); panel.begin(); panel.showSettings(); panel.mode="shortcuts"; break;
                case 1:
                    test.editor=test.find(panel,"shortcutsEditor");
                    if(test.wait(test.editor && test.editor.probeReady,"editor binding probe")) break;
                    test.check(!test.editor.systemBindings.some(function(b) { return b.modmask===4 && String(b.key).toLowerCase()==="f24"; }),"test chord must be unused");
                    Hyprland.dispatch(Lua.dispatch("local s={}; _windowpeek_recorder_test=s; s.bind=hl.bind('CTRL + F24',function() hl.dispatch(hl.dsp.event('windowpeek-recorder-test,"+test.token+"')) end,{auto_consuming=true,description='WindowPeek recorder test'}); function s.stop() if s.bind then s.bind:unbind(); s.bind=nil end; s.timer:set_enabled(false) end; s.timer=hl.timer(function() s.stop() end,{timeout=15000,type='repeat'}); "));
                    test.editor.edit(Shortcuts.definitions[0],test.find(test.editor,"shortcut-open")); break;
                case 2:
                    test.editor.recorder.recording=true;
                    test.editor.recorder.contentItem.forceActiveFocus(); break;
                case 3:
                    if(test.wait(test.editor.recorder.captureReady,"compositor grants recording protection")) break;
                    test.hold("Control_L"); break;
                case 4:
                    if(test.wait(keys.ready,"virtual Control held")) break;
                    keys.write("f24\n"); break;
                case 5:
                    if(test.wait(test.editor.recorder.candidate==="Ctrl+F24","physical chord reaches recorder")) break;
                    test.check(test.fired===0,"recording must not execute compositor shortcut");
                    keys.write("\n"); test.editor.recorder.close(); break;
                case 6:
                    if(test.wait(!keys.running,"Control released")) break;
                    test.hold("Control_L"); break;
                case 7:
                    if(test.wait(keys.ready,"Control after recording")) break;
                    keys.write("f24\n"); break;
                case 8:
                    if(test.wait(test.fired===1,"closing recorder restores compositor shortcuts")) break;
                    keys.write("\n"); test.editor.cancel(); panel.back(); break;
                case 9:
                    if(test.wait(!keys.running,"release before custom digits")) break;
                    host.persistSettings({shortcuts:{numbers:"Alt"}});
                    panel.expanded=false; panel.demote();
                    host.focused=""; test.hold("Alt_L"); break;
                case 10:
                    if(test.wait(keys.ready && panel.controlHeld,"custom modifier held in hover")) break;
                    keys.write("numlock off\nkeypad 2\n"); break;
                case 11:
                    if(test.wait(host.focused==="0x2","custom Alt+numpad selects grouped window")) break;
                    host.focused=""; keys.write("numlock on\nkeypad 3\n"); break;
                case 12:
                    if(test.wait(host.focused==="0x3","Num Lock on selects exact row")) break;
                    keys.write("\n"); panel.expanded=true; panel.promote(); break;
                case 13:
                    if(test.wait(!keys.running,"release before expanded view")) break;
                    host.focused=""; test.hold("Alt_R"); break;
                case 14:
                    if(test.wait(keys.ready,"right Alt held")) break;
                    keys.write("tap 4\n"); break;
                case 15:
                    if(test.wait(host.focused==="0x4","expanded view uses custom modifier")) break;
                    keys.write("\n"); panel.expanded=false; panel.demote();
                    host.focused="";
                    host.persistSettings({shortcuts:{},panelStyle:"wallpaper"});
                    host.wallpaperSource=Qt.resolvedUrl("dropdown-wallpaper.svg"); break;
                case 16:
                    if(test.wait(!keys.running,"release Alt before Ctrl click")) break;
                    test.hold("Control_L"); break;
                case 17:
                    if(test.wait(keys.ready && panel.controlHeld,"pre-held Ctrl while hover already has focus")) break;
                    var pointer=test.find(panel,"windowFocusPointer");
                    test.check(pointer.Window.window.active && pointer.needsCompositor,"focused hover still samples compositor modifiers");
                    // Deliberately stale Qt modifiers reproduce the reported focus handoff.
                    events.mouseClick(pointer,15,pointer.height/2,Qt.LeftButton,Qt.NoModifier,0); break;
                case 18:
                    if(test.wait(menu.opened,"Ctrl click opens destination menu")) break;
                    test.check(host.destinationRequested === "0x1" && !host.focused,"Ctrl click must not focus window");
                    test.check(menu.card.wallpaperMode && !!test.find(menu.card,"dropdownWallpaper"),"destination menu uses wallpaper dropdown surface");
                    var path=Quickshell.env("WINDOWPEEK_TEST_IMAGE");
                    if(path) menu.card.grabToImage(function(image) { image.saveToFile(path); });
                    keys.write("\n"); break;
                case 19:
                    menu.close(); panel.expanded=true; panel.promote(); panel.showSettings(); panel.mode="shortcuts"; break;
                case 20:
                    test.editor=test.find(panel,"shortcutsEditor");
                    test.editor.edit(Shortcuts.definitions[1],test.find(test.editor,"shortcut-numbers")); break;
                case 21:
                    test.check(test.editor.recorder.background.wallpaperMode,"shortcut chooser uses selected wallpaper too");
                    test.cleanup(); console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit(); break;
                }
            } catch(error) {
                console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error+" · "+error.stack);
                test.cleanup(); stop(); Qt.quit();
            }
        }
    }
}
