import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui as Ui
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

ShellRoot {
    id: test
    readonly property bool compileOnly: Quickshell.env("WINDOWPEEK_TEST_COMPILE_ONLY")==="1"
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    property int step: 0
    property int waits: 0
    property var received: []
    property real expandedHeight: 0
    property bool secondCollapse: false
    function check(ok, message) { if(!ok) throw new Error(message); }
    function wait(ok, message) { if(ok) { waits=0; return false; } if(++waits>12) throw new Error(message); step--; return true; }
    function hold(modifier) { keys.command=[Quickshell.env("WINDOWPEEK_TEST_KEYBOARD"),modifier]; keys.running=true; }
    function tap(name) { keys.write("key "+name+"\n"); }
    function move(item,x,y) {
        check(!mover.running && frame.ready && !frame.pending,"previous pointer move finished");
        frame.pending=true;
        var p=item.mapToGlobal(x,y);
        mover.command=["hyprctl","eval","hl.dispatch(hl.dsp.cursor.move({x="+Math.round(p.x)+",y="+Math.round(p.y)+"}))"];
        mover.running=true;
    }
    function last() { return panel.body.matches[panel.body.matches.length-1].address; }
    function cleanup() { keys.running=false; panel.close(); frame.running=false; }
    Component.onDestruction: if(!compileOnly) cleanup()
    Component.onCompleted: if(compileOnly) Qt.callLater(function() { console.log("WINDOWPEEK_TEST_PASS compile only"); Qt.quit(); })
    Process { id: mover; onExited: function(code) { if(code===0) frame.write("frame\n"); } }
    Process {
        id: frame; command:[Quickshell.env("WINDOWPEEK_TEST_POINTER_FRAME"),"--listen"]
        running: !test.compileOnly; stdinEnabled:true
        property bool ready:false
        property bool pending:false
        stdout: SplitParser { onRead:function(line) { if(line==="ready")frame.ready=true;else if(line==="framed")frame.pending=false; } }
    }
    Process {
        id: keys; stdinEnabled:true; property bool ready:false
        stdout: SplitParser { onRead:function(line) { if(line==="pressed") keys.ready=true; } }
        onExited: ready=false
    }
    FakeHost {
        id: host; bar:barApi
        function open() { panel.open(); }
        Component.onCompleted: {
            persistSettings({hintsMode:"off",windowPreviews:false,panelStyle:"wallpaper",backgroundTexture:true});
            wallpaperSource=Qt.resolvedUrl("dropdown-wallpaper.svg");
            savedAppearance=Appearance.normalize({uiScale:test.scale});
            var data=JSON.parse(JSON.stringify(snapshot));
            for(var i=6;i<=30;i++) data.clients.push({address:"0x"+i.toString(16),title:"Fictional document "+i,workspace:{id:4,name:"4"}});
            snapshot=data;
        }
    }
    Ui.PluginBarApi {
        id: barApi; pluginId:"sarr.windowpeek.navigation.test"; moduleName:panel.moduleName
        position:"top"; barSize:28
        _requestPopout:function(owner) { activePopout=owner; }
        _releasePopout:function(owner) { if(activePopout===owner) activePopout=null; }
    }
    PanelWindow {
        id:bar; visible:!test.compileOnly
        anchors { top:true; left:true; right:true }
        implicitHeight:28; color:"transparent"; exclusionMode:ExclusionMode.Ignore
        Item { id:anchor; x:100; width:150; height:28 }
    }
    Window {
        id:probe; visible:!test.compileOnly && shown
        property bool shown:true
        title: "WindowPeek fictional keyboard receiver"
        width:1600; height:1000; color:"#202030"
        Item {
            id:receiver; anchors.fill:parent; focus:true
            Text { anchors.centerIn:parent; color:"white"; text:"WindowPeek keyboard test" }
            Keys.onPressed:function(event) { test.received=test.received.concat([event.key]); event.accepted=true; }
        }
    }
    Plugin.Panel { id:panel; bar:barApi; anchorItem:anchor; hostWidget:host }
    Timer {
        id:timer; interval:250; repeat:true; running:!test.compileOnly
        onTriggered: {
            try {
                switch(test.step++) {
                case 0: panel.hoverRequested=true; test.hold("None"); break;
                case 1:
                    if(test.wait(keys.ready && panel.hoverOpened && panel.body.shortcutModifierState.known,"hover and lease ready")) break;
                    test.check(panel.surface.WlrLayershell.keyboardFocus===WlrKeyboardFocus.OnDemand,"compact panel receives typing");
                    break;
                case 2:
                    test.received=[]; test.tap("End"); break;
                case 3:
                    if(test.wait(panel.body.selectedAddress===test.last(),"native hover End")) break;
                    test.tap("Home"); break;
                case 4:
                    if(test.wait(panel.body.contentY===0 && panel.body.selectedAddress==="0x1","native hover Home")) break;
                    test.tap("PageDown"); break;
                case 5:
                    if(test.wait(panel.body.contentY>0,"native hover PageDown")) break;
                    test.tap("PageUp"); break;
                case 6:
                    if(test.wait(panel.body.contentY===0,"native hover PageUp")) break;
                    test.tap("Down"); break;
                case 7:
                    if(test.wait(panel.body.selectedAddress==="0x2","native hover Down")) break;
                    test.tap("Enter"); break;
                case 8:
                    if(test.wait(host.focused==="0x2","native hover Enter activates hidden tab")) break;
                    test.check(test.received.length===0,"navigation never leaks to background");
                    host.persistSettings({shortcuts:{last:"F6"}}); break;
                case 9: test.tap("F6"); break;
                case 10:
                    if(test.wait(panel.body.selectedAddress===test.last(),"native remapped End")) break;
                    test.tap("Tab"); break;
                case 11:
                    if(test.wait(panel.opened,"native Tab expands into controls")) break;
                    test.expandedHeight=panel.surface.cardItem.height;
                    test.tap("Esc"); break;
                case 12:
                    if(test.wait(!panel.mapped,"native Escape closes panel")) break;
                    receiver.forceActiveFocus(); break;
                case 13: test.tap("Home"); break;
                case 14:
                    if(test.wait(test.received.indexOf(Qt.Key_Home)>=0,"closed hover returns keys to background")) break;
                    keys.write("\n"); panel.open(); break;
                case 15:
                    test.move(panel.surface.cardItem,panel.surface.cardItem.width-10,panel.surface.cardItem.height-10); break;
                case 16:
                    panel.hoverRequested=false;
                    if(test.wait(!mover.running && !frame.pending && !panel.canHideHover,"native pointer entered expanded footprint")) break;
                    panel.collapse();
                    break;
                case 17:
                    if(test.wait(panel.expansion===0,"collapse animation settled")) break;
                    test.check(panel.hoverOpened && panel.mapped,"stationary pointer retains collapsed hover");
                    if(!test.secondCollapse) test.check(Math.abs(panel.surface.cardItem.height-test.expandedHeight)<2,"native logo matches expanded height");
                    test.check(panel.surface.hoverHandoffActive,"old right edge retains hover across shrinking width");
                    var imagePath=Quickshell.env("WINDOWPEEK_TEST_IMAGE");
                    if(imagePath && !test.secondCollapse) panel.surface.cardItem.grabToImage(function(image) { image.saveToFile(imagePath); });
                    test.move(panel.surface.cardItem,15,15); break;
                case 18:
                    if(test.wait(!panel.surface.hoverHandoffActive,"entering resized card releases old footprint")) break;
                    test.check(panel.hoverOpened,"entering card keeps hover open");
                    test.move(bar.contentItem,bar.width-15,bar.screen.height-15); break;
                case 19:
                    if(test.wait(!panel.mapped,"leaving resized card dismisses normally")) break;
                    if(!test.secondCollapse) {
                        test.secondCollapse=true; host.persistSettings({hoverLogo:false,popupAnimations:false});
                        panel.open(); test.step=15; break;
                    }
                    panel.hoverRequested=true; test.hold("Control_L"); break;
                case 20:
                    if(test.wait(keys.ready && panel.body.controlHeld,"Ctrl ready after collapse")) break;
                    host.focused=""; keys.write("numlock off\nkeypad 2\n"); break;
                case 21:
                    if(test.wait(host.focused==="0x2","Ctrl numpad with Num Lock off keeps ordinal selection")) break;
                    host.focused=""; keys.write("numlock on\nkeypad 2\n"); break;
                case 22:
                    if(test.wait(host.focused==="0x2","Ctrl numpad with Num Lock on")) break;
                    keys.write("\n"); panel.close(); break;
                case 23:
                    test.check(!panel.mapped,"final cleanup");
                    test.received=[];probe.shown=true;panel.hoverRequested=false;panel.hoverRequested=true;test.hold("None");break;
                case 24:
                    if(test.wait(keys.ready && panel.hoverOpened && panel.body.searchField.activeFocus,"hover receives text input")) break;
                    keys.write("key A\nkey B\nkey C\n");break;
                case 25:
                    if(test.wait(panel.opened && panel.body.searchField.text==="abc","fast typing expands and keeps every character: opened="+panel.opened+" text="+panel.body.searchField.text+" focused="+panel.body.searchField.activeFocus+" background="+test.received))break;
                    test.check(test.received.length===0,"query does not leak to background");
                    test.move(bar.contentItem,bar.width-15,bar.screen.height-15);break;
                case 26:
                    if(test.wait(!mover.running && !frame.pending,"pointer moved outside expanded panel"))break;
                    test.tap("D");break;
                case 27:
                    if(test.wait(panel.body.searchField.text==="abcd","search keeps typing focus with pointer outside: "+JSON.stringify({text:panel.body.searchField.text,active:panel.body.searchField.activeFocus,local:panel.body.searchField.focus,opened:panel.opened,keyboard:panel.surface.WlrLayershell.keyboardFocus,probe:receiver.activeFocus,background:test.received,keys:keys.running})))break;
                    test.check(test.received.length===0,"outside-pointer typing stays in search");
                    host.persistSettings({doubleClickExpand:true});panel.collapse();break;
                case 28:
                    if(test.wait(panel.compactPinned && panel.body.searchField.activeFocus,"pinned compact receives typing"))break;
                    test.tap("E");break;
                case 29:
                    if(test.wait(panel.opened && !panel.compactPinned && panel.body.searchField.text==="e","typing also expands pinned compact"))break;
                    panel.close();break;
                case 30:
                    if(test.wait(!panel.mapped && receiver.activeFocus,"typed panel closes and returns focus"))break;
                    test.tap("F");break;
                case 31:
                    if(test.wait(test.received.indexOf(Qt.Key_F)>=0,"closing typed panel returns keyboard to background: "+JSON.stringify({keys:keys.running,active:receiver.activeFocus,mapped:panel.mapped,received:test.received})))break;
                    console.log("WINDOWPEEK_TEST_PASS: native hover navigation, type-to-search, outside-pointer typing, keyboard release, collapse footprint and logo"); stop(); Qt.quit();
                }
            } catch(error) { console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error); stop(); test.cleanup(); Qt.quit(); }
        }
    }
}
