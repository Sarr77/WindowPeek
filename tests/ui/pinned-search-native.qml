import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "HostBar" as Host
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property string backgroundText: ""
    property real pointerY: 0
    property int hoverRound: 0
    property double handoffStarted: 0
    property double handoffMs: -1
    property int backgroundNavigation: 0
    property Connections nativeFocus: Connections {
        target: test.panel ? test.panel.surface : null
        function onNativeActiveChanged() {
            if (test.handoffStarted && !test.panel.surface.nativeActive && test.handoffMs < 0)
                test.handoffMs = Date.now() - test.handoffStarted;
        }
    }
    function leaveCompact() {
        handoffStarted = Date.now(); handoffMs = -1;
        outside("frame");
    }
    function checkHandoff() {
        check(!panel.surface.nativeActive && handoffMs >= 0 && handoffMs < 400,
            "compact hover releases keyboard promptly: " + handoffMs + "ms");
        console.log("COMPACT_HANDOFF_MS:" + handoffMs);
        handoffStarted = 0;
        check(panel.compactPinned && !widget.focusRecovery.interrupted,
            "ordinary pointer exit keeps compact pinned without interruption warning");
    }
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var widget: hostBar.moduleWidgets("sarr.windowpeek")[0] || null
    readonly property var panel: find(widget,"windowPeekController")
    function find(item,name) {
        if (!item) return null;
        if (item.objectName===name) return item;
        for (var child of item.children || []) { var result=find(child,name);if(result)return result; }
        return null;
    }
    function state() {return JSON.stringify({expanded:panel.body.expanded,text:panel.body.searchField.text,focus:panel.body.searchField.focus,active:panel.body.searchField.activeFocus,background:test.backgroundText});}
    function check(ok,message) {if(!ok)throw new Error(message);}
    function move(x,y,next) {
        pointer.pending=true;
        pointer.write("move "+Math.round(x)+" "+Math.round(y)+" 1920 1080\n");
        // Two motion frames cross Hyprland's focus-follows-mouse threshold after idle.
        if(next==="frame") pointer.write("move "+Math.round(x+2)+" "+Math.round(y)+" 1920 1080\n");
        else pointer.write(next+"\n");
    }
    function outside(next) {move(1750,800,next);}
    function over(item,next) {var p=item.mapToGlobal(item.width/2,item.height/2);move(p.x,p.y,next);}
    Process {
        id: app; command:["quickshell","--no-color","-p",Quickshell.env("WINDOWPEEK_TEST_PROFILE")+"/receiver.qml"]
        running:true
        stdout:SplitParser {onRead:function(line) {
            if(line.indexOf("BACKGROUND_KEY:")>=0)test.backgroundText+=line.split("BACKGROUND_KEY:")[1].trim();
            if(line.indexOf("BACKGROUND_KEYCODE:")>=0 && Number(line.split("BACKGROUND_KEYCODE:")[1])===Qt.Key_Right)
                test.backgroundNavigation++;
        }}
    }
    QtObject {
        id:shell
        property var config: ({bar:{position:"top",transparent:false,layout:{left:[{
            id:"sarr.windowpeek",autoUpdates:false,windowPreviews:false,openOnHover:false,
            doubleClickExpand:true,uiScale:test.scale}],center:[],right:[]}}})
        function updateEntryInline(id,entry){return true;}
        function pluginShellForId(id){return shell;}
    }
    Component{id:factory;Plugin.Widget{}}
    QtObject {
        id:registry
        property var widgets: ({"sarr.windowpeek":{component:factory}})
        property int revision:0
        function metadataFor(id){return {firstParty:false};}
    }
    Host.Bar{id:hostBar;shell:shell;barConfig:shell.config.bar;barWidgetRegistry:registry;omarchyPath:"/usr/share/omarchy"}

    Process {
        id:pointer;command:[Quickshell.env("WINDOWPEEK_TEST_POINTER_FRAME"),"--listen"]
        running:true;stdinEnabled:true
        property bool ready:false
        property bool pending:false
        stdout:SplitParser{onRead:function(line){if(line==="ready")pointer.ready=true;else pointer.pending=false;}}
    }
    Process {
        id: keys; command:[Quickshell.env("WINDOWPEEK_TEST_KEYBOARD"),"None"]
        running:true;stdinEnabled:true
        property bool ready:false
        stdout:SplitParser{onRead:function(line){if(line==="pressed")keys.ready=true;}}
    }
    Timer {
        interval:450; running:true; repeat:true
        onTriggered: {
            if (!keys.running) {keys.ready=false;keys.running=true;return;}
            if(!widget || !widget.settingsReady || !panel || !pointer.ready || pointer.pending || !keys.ready) return;
            try {
                switch(test.step++) {
                case 0: test.over(widget,"frame");break;
                case 1: pointer.write("click\n");break;
                case 2:
                    test.check(panel.compactPinned,"fresh bar click pins compact: "+JSON.stringify({opened:panel.opened,hover:panel.hoverOpened,pending:widget.barClickPending}));
                    test.leaveCompact();test.step=100;break;
                case 100:
                    test.checkHandoff();
                    keys.write("key Right\n");break;
                case 101:
                    test.check(test.backgroundNavigation===test.hoverRound+1,
                        "compact navigation keys belong to the focused background window");
                    test.over(test.find(panel.body,"panelHeader"),"frame");break;
                case 102:
                    test.check(panel.surface.nativeActive,"hover alone reacquires compact keyboard");
                    if (++test.hoverRound < 4) {test.leaveCompact();test.step=100;break;}
                    keys.write("key A\nkey B\nkey C\n");test.step=3;break;
                case 3:
                    test.check(panel.body.expanded && panel.body.searchField.text==="abc","fresh pinned typing: "+test.state());
                    panel.body.searchField.clear();break;
                case 4:
                    test.pointerY=panel.surface.cardItem.mapToGlobal(40,panel.surface.cardItem.height-10).y;
                    test.move(40,test.pointerY,"frame");break;
                case 5: keys.write("key A\nkey B\nkey C\n");break;
                case 6:
                    test.check(panel.body.searchField.text==="abc","typing shrinks panel: "+test.state());
                    test.check(panel.surface.cardItem.mapToGlobal(40,panel.surface.cardItem.height).y < test.pointerY,"filter moves panel bottom above stationary cursor");
                    keys.write("key D\n");break;
                case 7:
                    test.check(panel.body.searchField.text==="abcd" && panel.body.searchField.activeFocus,"typing outside shrinking panel: "+test.state());
                    test.outside("frame");break;
                case 8: keys.write("key E\n");break;
                case 9:
                    test.check(panel.body.searchField.text==="abcde","typing after real mouse movement outside: "+test.state());
                    panel.body.searchField.clear();widget.persistSettings({windowPreviews:true,previewHoverDelay:0});break;
                case 10:
                    var row=test.find(panel.body,"windowFocus");
                    test.check(!!row,"fictional window row exists");test.over(row,"frame");break;
                case 11:
                    test.check(widget.windowPreview.backingWindowVisible,"native window preview opened");test.outside("frame");break;
                case 12: keys.write("key D\n");break;
                case 13:
                    test.check(!widget.windowPreview.backingWindowVisible,"leaving panel dismisses preview");
                    test.check(panel.body.searchField.text==="d" && panel.body.searchField.activeFocus,"preview dismissal preserves search: "+test.state());
                    test.check(test.backgroundText==="","no text escaped search");
                    test.move(1,800,"frame");break;
                case 14: keys.write("key E\n");break;
                case 15:
                    test.check(panel.body.searchField.text==="de" && panel.body.searchField.activeFocus,"typing after crossing empty desktop gap: "+test.state());
                    test.outside("frame");break;
                case 16: keys.write("key F\n");break;
                case 17:
                    test.check(panel.body.searchField.text==="def" && panel.body.searchField.activeFocus,"pointer activation must not strand keyboard: "+test.state());
                    test.over(test.find(panel.body,"panelTitle"),"frame");test.step=199;break;
                case 199: pointer.write("double\n");break;
                case 200:
                    test.check(panel.compactPinned,"collapsing returns to compact browsing: "+test.state()+" opened="+panel.opened+" allowed="+panel.body.backgroundToggleAllowed);
                    test.leaveCompact();break;
                case 201:
                    test.checkHandoff();
                    test.step=18;break;
                case 18: pointer.write("click\n");break;
                case 19:
                    test.check(!panel.opened,"outside click still dismisses the panel");
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            } catch(error){console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error);stop();Qt.quit();}
        }
    }
}
