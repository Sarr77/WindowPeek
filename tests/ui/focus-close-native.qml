// Private compositor: closing must fade on one surface before native teardown.
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "HostBar" as Host
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    readonly property bool reviewCase: Quickshell.env("WP_CASE") === "review"
    readonly property bool temporary: reviewCase || Quickshell.env("WP_CASE") === "temporary"
    property real reviewHeight: 0
    property string reviewActions: ""
    property bool reviewChanged: false
    property int waitCount: 0
    property int step: 0
    property bool measuring: false
    readonly property string closeAction: Quickshell.env("WP_TARGET")
    function verifyClosed() {
        test.check(!panel.opened && !panel.mapped,"closed panel must unmap");
        test.check(test.closeSamples>5,"closing was observed");
        test.check(!test.earlyHandoff,"fading card must stay on its native surface");
        test.check(!test.opacityRose,"closing opacity must not restart");
        test.check(!test.reviewChanged,"review closes directly without revealing or resizing to search");
        test.check(!test.expandedChangedDuringFade,"expanded presentation must stay unchanged through fade-out");
        test.check(!test.statusChangedDuringFade,"protection status stays unchanged and visible throughout fade-out");
    }
    property var clients: []
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
    Rectangle {
        // A fixed-size marker also lets private compositor captures detect stretching.
        parent: panel ? panel.surface.cardItem : null
        x:4; y:4; width:12; height:12; color:"#11ee44"
        visible: test.measuring; z:1000009
    }
    Process {
        id: app
        command:["env","LD_PRELOAD="+Quickshell.env("WINDOWPEEK_TEST_POINTER_PRELOAD"),"quickshell","--no-color","-p",Quickshell.env("WINDOWPEEK_TEST_PROFILE")+"/receiver.qml"]
        running:true
    }
    QtObject {
        id:shell
        property var config: ({bar:{position:"top",transparent:false,layout:{left:[{
            id:"sarr.windowpeek",autoUpdates:false,windowPreviews:false,openOnHover:false,
            doubleClickExpand:true,keepSearchFocus:!test.temporary,uiScale:test.scale}],center:[],right:[]}}})
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
        stdout:SplitParser{onRead:function(line){
            if(line==="ready"){pointer.ready=true;return;}
            if(pointer.queuedCommand){
                var command=pointer.queuedCommand;pointer.queuedCommand="";
                pointer.write(command+"\n");
            }else pointer.pending=false;
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
            test.clients=JSON.parse(text).filter(function(c){return c.title.indexOf("Fictional ")===0 && c.title.indexOf("receiver")>=0;});
            test.clients.sort(function(a,b){return b.at[0]+b.size[0]/2-a.at[0]-a.size[0]/2;});
            if(test.clients.length===2) {
                test.wheelTarget=test.clients[0];
            }
        }}
    }
    property string leaseState: ""
    Process {
        id:checkLease
        command:["hyprctl","eval","assert(not (_windowpeek_native_focus_v2 and _windowpeek_native_focus_v2.owner), 'native rule still owned'); return 'ok'"]
        stdout:StdioCollector {onStreamFinished:{test.leaseState=text.trim();console.log("LEASE_RESULT:"+JSON.stringify(test.leaseState));}}
    }
    property string selectedAddress: ""
    property string activeAddress: ""
    Process {
        id:activeWindow; command:["hyprctl","-j","activewindow"]
        stdout:StdioCollector {onStreamFinished:test.activeAddress=JSON.parse(text).address || ""}
    }
    readonly property bool toggling: closeAction === "toggle"
    property bool checkingHandoff: false
    property int screenSamples: 0
    property int missingFrames: 0
    property bool stateLost: false
    property Process frameProbe: Process {
        command:["python3",Qt.resolvedUrl("WindowPeek/tests/ui/frame-marker.py").toString().replace(/^file:\/\//, "")]
        running: test.toggling && test.measuring
        stdout: SplitParser {onRead:function(line) {
            if(test.checkingHandoff) {test.screenSamples++; if(line === "absent")test.missingFrames++;}
        }}
    }
    property Timer handoffState: Timer {
        interval:4; repeat:true; running:test.checkingHandoff
        onTriggered: if(!panel.opened || panel.surface.cardItem.opacity<0.99 || panel.body.searchField.text!=="a") test.stateLost=true
    }
    property bool closing: false
    property bool earlyHandoff: false
    property int closeSamples: 0
    property real previousOpacity: 1
    property bool opacityRose: false
    property string closingStatus: ""
    property bool closingStatusVisible: false
    property bool statusChangedDuringFade: false
    property bool expandedChangedDuringFade: false
    property bool closingExpanded: true
    Timer {
        interval:4; repeat:true; running:test.closing
        onTriggered: {
            var surface=panel.surface;
            var opacity=surface.cardItem.opacity;
            if(!test.reviewCase && opacity>0.01 && panel.body.expanded!==test.closingExpanded)test.expandedChangedDuringFade=true;
            if(!test.reviewCase && opacity>0.01 && !surface.usingNative)test.earlyHandoff=true;
            var status=test.find(panel.body,"focusProtectionStatus");
            if(!test.reviewCase && opacity>0.01 && (!status || status.parent.visible!==test.closingStatusVisible || status.text!==test.closingStatus))
                test.statusChangedDuringFade=true;
            if(test.reviewCase && opacity>0.01 && (!panel.body.recoveryOpen || surface.contentHeight!==test.reviewHeight
                || JSON.stringify(test.find(panel.body,"focusRecoveryDialog").actionItems)!==test.reviewActions))test.reviewChanged=true;
            if(opacity>test.previousOpacity+0.01)test.opacityRose=true;
            test.previousOpacity=opacity;test.closeSamples++;
            console.log("CLOSING:"+JSON.stringify({opacity:opacity,native:surface.usingNative,mapped:panel.mapped,open:panel.opened,hover:panel.hoverOpened,size:[surface.contentWidth,surface.contentHeight],parentLayer:surface.cardItem.parent===surface.layerScene}));
        }
    }
    Timer {
        interval:350;running:true;repeat:true
        onTriggered: {
            if(!widget || !panel || !widget.settingsReady || !pointer.ready || !keys.ready || pointer.pending)return;
            try {
                switch(test.step++) {
                case 0:
                    if(test.toggling)Hyprland.dispatch("(function() hl.config({animations={enabled=true}}); return hl.dsp.no_op() end)()");
                    inspectClients.running=true;break;
                case 1:test.outside("click");break;
                case 2:test.over(widget,"double");if(test.temporary)test.step=100;break;
                case 100:test.outside("frame");break;
                case 101:
                    if(!widget.focusRecovery.offered && ++test.waitCount<12){test.step--;break;}
                    test.check(widget.focusRecovery.offered,"temporary source detected");
                    test.over(test.find(panel.body,"focusRecoveryNotice"),"click");break;
                case 102:
                    test.check(panel.body.recoveryOpen,"temporary consent dialog opened");
                    if(test.reviewCase) {
                        test.reviewHeight=panel.surface.contentHeight;
                        test.reviewActions=JSON.stringify(test.find(panel.body,"focusRecoveryDialog").actionItems);
                        test.closing=true;test.outside("click");test.step=6;break;
                    }
                    test.over(test.find(panel.body,"approveFocusProtection"),"click");break;
                case 103:
                    if(widget.focusRecovery.pendingApproval && ++test.waitCount<20) {test.step--;break;}
                    test.check(widget.focusRecovery.granted && !widget.keepSearchFocus,"temporary consent retained");
                    test.step=3;break;
                case 3:
                    if(!panel.surface.usingNative && ++test.waitCount<20) {test.step--;break;}
                    test.check(panel.surface.usingNative && panel.body.expanded,"protected expanded search");
                    test.measuring=true;
                    if(test.closeAction==="clear-outside") {panel.collapse();test.step=300;break;}
                    test.over(panel.body.searchField,"click");break;
                case 300:
                    test.check(!panel.body.expanded && panel.surface.usingNative,"protected compact panel");
                    keys.write("key A\n");break;
                case 301:
                    test.check(panel.body.expanded && panel.body.searchField.text==="a","typing expanded the compact panel");
                    keys.write("key Backspace\n");break;
                case 302:
                    test.check(panel.body.expanded && panel.body.searchField.text==="","cleared expanded search");
                    test.step=5;break;
                case 4:keys.write("key A\n");break;
                case 5:
                    if(test.toggling) {
                        test.check(panel.body.searchField.text==="a","search text before handoff");
                        test.checkingHandoff=true;
                        if(test.temporary)test.over(test.find(panel.body,"turnOffFocusProtection"),"click");
                        else widget.persistSettings({keepSearchFocus:false});
                        test.step=200;break;
                    }
                    test.closingStatus=test.find(panel.body,"focusProtectionStatus").text;
                    test.closingStatusVisible=test.find(panel.body,"focusProtectionStatus").parent.visible;
                    test.closingExpanded=panel.body.expanded;
                    test.measuring=true;test.closing=true;
                    if(test.closeAction==="outside" || test.closeAction==="clear-outside")test.outside("click");
                    else if(test.closeAction==="bar")widget.pressBarButton(Qt.LeftButton);
                    else if(test.closeAction==="row") {
                        var row=test.find(panel.body,"windowFocus");
                        test.selectedAddress=row.parent.window.address;
                        test.over(row,"click");
                    }
                    else keys.write("key Esc\n");
                    break;
                case 200:
                    test.check(panel.opened && !panel.surface.usingNative,"disabled protection preserves the panel");
                    widget.persistSettings({keepSearchFocus:true});break;
                case 201:
                    test.check(panel.opened && panel.surface.usingNative,"enabling protection preserves the panel");
                    widget.persistSettings({keepSearchFocus:false});break;
                case 202:
                    test.checkingHandoff=false;
                    test.check(!test.stateLost,"handoff never closes, fades or clears search");
                    test.check(test.screenSamples>=5,"compositor frames sampled");
                    console.log("HANDOFF_FRAMES:"+JSON.stringify({samples:test.screenSamples,missing:test.missingFrames}));
                    test.check(test.missingFrames===0,"panel marker remains visible during surface changes");
                    panel.close();test.measuring=false;checkLease.running=true;break;
                case 203:
                    test.check(test.leaseState==="ok","native lease released after repeated toggles");
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                case 6:checkLease.running=true;if(test.closeAction==="row")activeWindow.running=true;break; // Include the bar's single/double-click decision delay.
                case 7:
                    test.closing=false;
                    test.verifyClosed();
                    test.check(test.leaseState==="ok","native rule lease released after close");
                    if(test.closeAction==="row")test.check(test.activeAddress===test.selectedAddress,"selected window receives focus after native unmap");
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            }catch(e){console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+e);stop();Qt.quit();}
        }
    }
}
