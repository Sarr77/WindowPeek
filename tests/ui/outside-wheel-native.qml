import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "HostBar" as Host
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property int received: 0
    property int clicks: 0
    property int initialFollow: -1
    property int currentFollow: -1
    property real expiryStarted: 0
    property real savedScroll: 0
    property string scrollMode: "settings"
    property int previous: 0
    property string command: "frame"
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var widget: hostBar.moduleWidgets("sarr.windowpeek")[0] || null
    readonly property var panel: find(widget,"windowPeekController")
    function find(item,name) {
        if (!item) return null;
        if (item.objectName===name) return item;
        for (var child of item.children || []) { var result=find(child,name);if(result)return result; }
        return null;
    }
    function check(ok,message) {if(!ok)throw new Error(message);}
    function move(x,y,next) {
        command=next;pointer.pending=true;
        mover.command=["hyprctl","eval","hl.dispatch(hl.dsp.cursor.move({x="+Math.round(x)+",y="+Math.round(y)+"}))"];
        mover.running=true;
    }
    function outside(next) {move(1750,800,next);}
    function over(item,next) {var p=item.mapToGlobal(item.width/2,item.height/2);move(p.x,p.y,next);}
    Window {
        id: app; visible:true; width:1600;height:1000;title:"Fictional scroll receiver"
        color:"#112233"
        MouseArea {
            anchors.fill:parent
            onWheel:function(event){test.received+=event.angleDelta.y;event.accepted=true;}
            onClicked:test.clicks++
        }
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
    Plugin.SearchFocus { id: focusLease }
    Process {
        id: followMode
        command: ["hyprctl", "-j", "getoption", "input:follow_mouse"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                test.currentFollow = JSON.parse(text).int;
                if (test.initialFollow < 0) test.initialFollow = test.currentFollow;
            }
        }
    }
    Process {
        id:mover
        onExited:function(code){test.check(code===0,"private pointer move");pointer.write(test.command+"\n");}
    }
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
        interval:400;running:true;repeat:true
        onTriggered:{
            if(test.initialFollow<0 || followMode.running || !test.widget || !test.widget.settingsReady || !test.panel || !pointer.ready || !keys.ready || pointer.pending)return;
            try {
                switch(test.step++) {
                case 0:test.outside("scroll");break;
                case 1:test.check(test.received!==0,"underlying app receives baseline wheel");test.previous=test.received;test.over(test.widget,"click");break;
                case 2:test.check(panel.compactPinned,"bar click pins compact");test.outside("scroll");break;
                case 3:
                    test.check(test.received!==test.previous,"first outside wheel reaches app with compact panel open");
                    test.check(panel.opened,"outside wheel leaves compact panel open");
                    test.previous=test.received;test.over(test.widget,"double");break;
                case 4:test.check(panel.body.expanded,"bar double-click expands: "+JSON.stringify({opened:panel.opened,pinned:panel.compactPinned,hover:widget.barLabelHovered,pending:widget.barClickPending,focus:panel.surface.keyboardActive}));test.outside("scroll");break;
                case 5:
                    test.check(test.received!==test.previous,"first outside wheel reaches app with expanded panel open: "+JSON.stringify({keyboard:panel.surface.keyboardActive,prime:panel.surface.primeInput,ready:panel.surface.pointerReady,mask:[panel.surface.mask.x,panel.surface.mask.y,panel.surface.mask.width,panel.surface.mask.height],pending:widget.barClickPending}));
                    test.check(panel.opened,"outside wheel leaves expanded panel open");
                    test.outside("click");break;
                case 6:
                    test.check(!panel.opened,"outside click dismisses panel");
                    test.check(test.clicks>0,"outside click reaches app");
                    test.over(test.widget,"double");break;
                case 7:test.check(panel.body.expanded,"panel reopens");panel.showSettings();break;
                case 8:
                    test.previous=test.received;
                    find(panel.body,"settingsPersonalizationSection").expanded=true;
                    panel.body.ensureVisible(find(panel.body,"panelStylePicker"));break;
                case 9:test.over(find(panel.body,"panelStylePicker"),"click");break;
                case 10:test.check(!!panel.body.currentPopup,"dropdown opens");test.outside("scroll");break;
                case 11:
                    test.check(test.received!==test.previous,"wheel outside Settings and dropdown reaches app");
                    test.over(find(panel.body,"settingsButton"),"right");break;
                case 12:
                    test.check(!panel.body.currentPopup && panel.body.mode==="settings"
                        && find(panel.body,"settingsPersonalizationSection").expanded,"right-click outside picker closes one level");
                    test.over(find(panel.body,"settingsButton"),"right");break;
                case 13:
                    test.check(panel.body.mode==="settings" && !find(panel.body,"settingsPersonalizationSection").expanded,
                        "next right-click collapses its section");
                    test.over(find(panel.body,"settingsButton"),"right");break;
                case 14:
                    test.check(panel.body.mode==="windows","final right-click returns to list");
                    test.check(panel.showMoveMenu(widget.inventory.windows[0].address),"move menu opens for a fictional window");break;
                case 15:
                    test.check(panel.destinationMenu.opened,"move menu remains open");
                    test.previous=test.received;test.outside("scroll");break;
                case 16:
                    test.check(test.received!==test.previous,"outside wheel also passes a move menu");
                    test.check(panel.destinationMenu.opened,"outside wheel preserves move menu");
                    test.outside("click");break;
                case 17:
                    test.check(!panel.destinationMenu.opened && panel.opened,"outside click closes only move menu");
                    panel.close();break;
                case 18: widget.open(true);break;
                case 19:
                    test.check(panel.body.expanded && panel.body.quickSelection,"keyboard opening starts quick selection with pointer outside");
                    keys.write("key Esc\n");break;
                case 20:
                    test.check(!panel.opened,"keyboard input reaches a freshly opened panel even with pointer outside");
                    widget.open(true);test.previous=test.received;break;
                case 21: pointer.write("scroll\n");break;
                case 22:
                    test.check(test.received!==test.previous,"outside wheel passes without any pointer motion after keyboard opening");
                    keys.write("key A\n");break;
                case 23:
                    test.check(panel.body.searchField.text==="a","outside wheel preserves search keyboard focus");
                    panel.showSettings();break;
                case 24:
                    find(panel.body,"settingsPersonalizationSection").expanded=true;
                    find(panel.body,"settingsPanelSection").expanded=true;
                    find(panel.body,"settingsListSection").expanded=true;
                    break;
                case 25:
                    panel.body.ensureVisible(find(panel.body,"openPicturesButton"));
                    test.savedScroll=find(panel.body,"editorScroll").contentY;
                    test.check(test.savedScroll>0,"settings was scrolled down");
                    test.outside("frame");break;
                case 26: test.over(find(panel.body,"settingsButton"),"frame");break;
                case 27:
                    test.check(Math.abs(find(panel.body,"editorScroll").contentY-test.savedScroll)<1,"returning from outside preserves "+test.scrollMode+" scroll position");
                    if(test.scrollMode==="settings") {
                        test.scrollMode="pictures";
                        test.over(find(panel.body,"openPicturesButton"),"click");break;
                    }
                    panel.close();test.step=30;break;
                case 28:
                    test.check(panel.body.mode==="pictures","pictures editor opens");
                    widget.persistSettings({hoverLogoImage:"builtin:omarchy-pixel",settingsLogoImage:"builtin:omarchy-pixel"});break;
                case 29:
                    panel.body.ensureVisible(find(panel.body,"settingsLogoCooldown"));
                    test.savedScroll=find(panel.body,"editorScroll").contentY;
                    test.outside("frame");test.step=26;break;
                case 30: followMode.running=true;break;
                case 31:
                    test.check(test.currentFollow===test.initialFollow,"panel close restores original mouse focus behavior");
                    focusLease.active=true;break;
                case 32: followMode.running=true;break;
                case 33:
                    test.check(test.currentFollow===3,"search uses temporary click-to-focus");
                    focusLease.lease.stop();test.expiryStarted=Date.now();break;
                case 34:
                    if(Date.now()-test.expiryStarted<1100){test.step--;break;}
                    followMode.running=true;break;
                case 35:
                    test.check(test.currentFollow===test.initialFollow,"compositor restores mouse behavior if the shell stops renewing");
                    focusLease.active=false;
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            } catch(error){console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error);stop();Qt.quit();}
        }
    }
}
