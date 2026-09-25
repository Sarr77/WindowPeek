// Compact browsing is quiet; visible Search still reports real keyboard loss.
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "HostBar" as Host
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    readonly property bool unknownSource: Quickshell.env("WP_CASE") === "unknown"
    property int step: 0
    property int attempts: 0
    property string backgroundText: ""
    property int backgroundWheel: 0
    property var clients: []
    property var resizeSource: null
    property var companion: null
    property var wheelTarget: null
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var widget: hostBar.moduleWidgets("sarr.windowpeek")[0] || null
    readonly property var panel: find(widget,"windowPeekController")
    function find(item,name) {
        if (!item) return null;
        if (item.objectName===name) return item;
        for (var child of item.children || []) { var r=find(child,name);if(r)return r; }
        return null;
    }
    function state() {return JSON.stringify({expanded:panel.body.expanded,text:panel.body.searchField.text,active:panel.body.searchField.activeFocus,background:backgroundText});}
    function check(ok,message) {if(!ok)throw new Error(message);}
    function move(x,y,next) {
        pointer.pending=true;
        pointer.queuedCommand=next==="frame"?"":next;
        pointer.write("move "+Math.round(x)+" "+Math.round(y)+" 1920 1080\n");
    }
    function outside(next) {move(wheelTarget.at[0]+wheelTarget.size[0]*0.75,wheelTarget.at[1]+wheelTarget.size[1]*0.75,next);}
    function over(item,next) {
        var p=item.mapToGlobal(item.width/2,item.height/2);
        if (panel && panel.surface.usingNative && item !== widget) {
            p=item.mapToItem(panel.surface.cardItem,item.width/2,item.height/2);
            p=Qt.point(p.x+panel.surface.nativeGlobalOrigin.x,p.y+panel.surface.nativeGlobalOrigin.y);
        }
        move(p.x,p.y,next);
    }
    Process {
        id: app
        command:["env","LD_PRELOAD="+Quickshell.env("WINDOWPEEK_TEST_POINTER_PRELOAD"),"quickshell","--no-color","-p",Quickshell.env("WINDOWPEEK_TEST_PROFILE")+"/receiver.qml"]
        running:true
        stdout:SplitParser {onRead:function(line) {
            if(line.indexOf("BACKGROUND_WHEEL:")>=0)test.backgroundWheel+=Number(line.split("BACKGROUND_WHEEL:")[1].trim());
            if(line.indexOf("BACKGROUND_KEY:")>=0)test.backgroundText+=line.split("BACKGROUND_KEY:")[1].trim();
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
        property string queuedCommand:""
        property string afterClickKey:""
        stdout:SplitParser{onRead:function(line){
            if(line==="ready"){pointer.ready=true;return;}
            if(pointer.queuedCommand){
                var command=pointer.queuedCommand;pointer.queuedCommand="";
                pointer.write(command+"\n");
            }else {
                pointer.pending=false;
                if(pointer.afterClickKey) {keys.write("key "+pointer.afterClickKey+"\n");pointer.afterClickKey="";}
            }
        }}
    }
    Process {
        id:keys;command:[Quickshell.env("WINDOWPEEK_TEST_KEYBOARD"),"None"]
        running:true;stdinEnabled:true
        property bool ready:false
        stdout:SplitParser{onRead:function(line){if(line==="pressed")keys.ready=true;}}
    }
    Process {
        id:inspectClients;command:["hyprctl","-j","clients"]
        stdout:StdioCollector {onStreamFinished: {
            test.companion=JSON.parse(text).find(function(c){return c.class==="WindowPeekCompanionFixture";}) || null;
            test.resizeSource=JSON.parse(text).find(function(c){return c.class==="WindowPeekFocusFixture";}) || null;
            test.clients=JSON.parse(text).filter(function(c){return c.title.indexOf("Fictional ")===0 && c.title.indexOf("receiver")>=0;});
            test.clients.sort(function(a,b){return b.at[0]+b.size[0]/2-a.at[0]-a.size[0]/2;});
            if(test.clients.length===2) {
                test.wheelTarget=test.clients[0];
            }
        }}
    }
    Timer {
        interval:500;running:true;repeat:true
        onTriggered: {
            if(!widget || !panel || !widget.settingsReady || !pointer.ready || !keys.ready || pointer.pending) return;
            try {
                console.log("STEP:"+test.step+":"+test.state()+" native="+panel.surface.nativeActive);
                switch(test.step++) {
                case 0: inspectClients.running=true;break;
                case 1:
                    test.check(!!test.resizeSource && !!test.wheelTarget,"fictional source and receiver available");
                    if(Quickshell.env("WP_COMPANION")==="1")test.check(test.companion && test.companion.floating && test.companion.mapped,"floating companion actually present");
                    test.outside("click");break;
                case 2: test.over(widget,"click");break;
                case 3:
                    test.check(panel.compactPinned && panel.surface.nativeActive,"compact panel acquired focus");
                    if(test.unknownSource)widget.focusRecovery.observerFailed=true;
                    test.outside("frame");break;
                case 4: break;
                case 5:
                    if(test.attempts++<3){test.step=5;break;}
                    test.check(!panel.surface.nativeActive,"compact actually lost keyboard focus");
                    test.check(!widget.focusRecovery.interrupted && !widget.focusRecovery.offered && !widget.focusRecovery.suggested,
                        "browsing pinned compact panel never claims typing was interrupted");
                    test.check(widget.focusRecovery.session.lostAt===null && widget.focusRecovery.interruptions.events.length===0,
                        "compact loss is neither queued nor counted toward repeated-loss suggestions");
                    test.over(test.find(panel.body,"panelHeader"),test.unknownSource?"click":"double");
                    test.step=20;break;
                case 20:
                    test.check(panel.surface.nativeActive,"deliberate header click reacquires keyboard focus");
                    test.check(!widget.focusRecovery.offered && !widget.focusRecovery.interrupted,"opening Search does not replay compact loss");
                    if(test.unknownSource)keys.write("key A\n");
                    break;
                case 21:
                    test.check(panel.body.expanded && panel.body.searchField.text===(test.unknownSource?"a":""),
                        "Search opens by explicit expansion or first typed character, without losing that character");
                    test.attempts=0;test.outside("frame");break;
                case 22: break;
                case 23:
                    if((panel.surface.nativeActive || !(test.unknownSource?widget.focusRecovery.interrupted:widget.focusRecovery.offered)) && test.attempts++<6){test.step=23;break;}
                    test.check(!panel.surface.nativeActive && (widget.focusRecovery.interrupted || widget.focusRecovery.offered),
                        "visible Search reports a fresh loss, with or without typed text");
                    test.check(!widget.focusRecovery.granted && !widget.keepSearchFocus,"notice never enables protection");
                    test.over(test.find(panel.body,"focusRecoveryNotice"),"click");test.step=6;break;
                case 6:
                    if(test.unknownSource){
                        test.check(panel.body.recoveryOpen && !widget.focusRecovery.offered,"unknown source opens brief review");
                    } else {
                        test.check(panel.body.recoveryOpen,"known source opens specific explanation");
                        test.over(test.find(panel.body,"declineFocusProtection"),"click");
                    }
                    break;
                case 7:
                    panel.body.showTroubleshooting();
                    test.check(!widget.focusRecovery.interrupted && !widget.focusRecovery.suggested,"review acknowledges status and mutes reminders");
                    panel.close();break;
                case 8: test.over(widget,"double");break;
                case 9:
                    test.check(panel.opened && panel.body.expanded && panel.surface.nativeActive,"double-click opens expanded search");
                    if(test.unknownSource)widget.focusRecovery.observerFailed=true;
                    keys.write("key A\n");break;
                case 10:
                    test.check(panel.body.searchField.text==="a","typed query shrinks expanded panel");
                    test.attempts=0;
                    test.outside("frame");break;
                case 11: break;
                case 12:
                    if((panel.surface.nativeActive || !widget.focusRecovery.interrupted) && test.attempts++<6){test.step=12;break;}
                    test.check(!panel.surface.nativeActive,"expanded search actually lost focus");
                    test.check(!widget.focusRecovery.offered && !widget.focusRecovery.suggested,"source dismissal and reminder mute respected");
                    test.check(widget.focusRecovery.interrupted && test.find(panel.body,"focusRecoveryNotice").visible,
                        "new expanded loss still shows review despite previous dismissal and mute");
                    test.check(!widget.focusRecovery.granted && !widget.keepSearchFocus,"no automatic protection");
                    panel.surface.cardItem.grabToImage(function(image){if(Quickshell.env("WINDOWPEEK_TEST_IMAGE"))image.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE"));});
                    test.over(test.find(panel.body,"focusRecoveryNotice"),"click");break;
                case 13:
                    test.check(panel.body.recoveryOpen && !widget.keepSearchFocus,"expanded review uses the same brief dialog");
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            }catch(e){console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+e);stop();Qt.quit();}
        }
    }
}
