// Private compositor: monitor actual protected-window geometry during typing and expansion.
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "HostBar" as Host
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    readonly property bool temporary: Quickshell.env("WP_CASE") === "temporary"
    property int waitCount: 0
    property int step: 0
    property bool measuring: false
    property int samples: 0
    property real drift: 0
    property int cycles: 0
    property var lastGeometry: null
    property string backgroundText: ""
    property int backgroundWheel: 0
    property var clients: []
    property var resizeSource: null
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
    function state() {return JSON.stringify({expanded:panel.body.expanded,text:panel.body.searchField.text,opened:panel.opened,compact:panel.compactPinned,allowed:panel.body.backgroundToggleAllowed,interacting:panel.body.interacting,pending:widget.barClickPending,barHovered:widget.barLabelHovered,active:panel.body.searchField.activeFocus,background:backgroundText});}
    function sizeMatches() {
        var w=test.lastGeometry;
        test.check(w && Math.abs(w.size[0]-panel.surface.screenW)<=1 && Math.abs(w.size[1]-panel.surface.screenH)<=1,"native viewport must stay at the monitor size: "+JSON.stringify(w && {size:w.size,card:[panel.surface.contentWidth,panel.surface.contentHeight]}));
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
        stdout:SplitParser {onRead:function(line) {
            if(line.indexOf("BACKGROUND_WHEEL:")>=0)test.backgroundWheel+=Number(line.split("BACKGROUND_WHEEL:")[1].trim());
            if(line.indexOf("BACKGROUND_KEY:")>=0)test.backgroundText+=line.split("BACKGROUND_KEY:")[1].trim();
        }}
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
            test.resizeSource=JSON.parse(text).find(function(c){return c.class==="WindowPeekFocusFixture";}) || null;
            test.clients=JSON.parse(text).filter(function(c){return c.title.indexOf("Fictional ")===0 && c.title.indexOf("receiver")>=0;});
            test.clients.sort(function(a,b){return b.at[0]+b.size[0]/2-a.at[0]-a.size[0]/2;});
            if(test.clients.length===2) {
                test.wheelTarget=test.clients[0];
            }
        }}
    }
    Process {
        id: geometry
        command:["hyprctl","-j","clients"]
        stdout: StdioCollector {onStreamFinished:{
            if(!test.measuring)return;
            var w=JSON.parse(text).find(function(c){return c.title.indexOf("WindowPeek protection ")===0;});
            if(!w)return;
            test.lastGeometry=w;
            var p=panel.surface.nativeSurfaceOrigin;
            var d=Math.max(Math.abs(w.at[0]-p.x),Math.abs(w.at[1]-p.y));
            test.drift=Math.max(test.drift,d);test.samples++;
            console.log("GEOMETRY:"+JSON.stringify({at:w.at,size:w.size,expected:[p.x,p.y],card:[panel.surface.contentWidth,panel.surface.contentHeight],text:panel.body.searchField.text}));
        }}
    }
    Timer{interval:8;repeat:true;running:test.measuring;onTriggered:if(!geometry.running)geometry.running=true}
    Timer {
        interval:350;running:true;repeat:true
        onTriggered: {
            if(!widget || !panel || !widget.settingsReady || !pointer.ready || !keys.ready || pointer.pending)return;
            try {
                switch(test.step++) {
                case 0: inspectClients.running=true;break;
                case 1:test.outside("click");break;
                case 2:test.over(widget,"double");if(test.temporary)test.step=100;break;
                case 100:test.outside("frame");break;
                case 101:
                    if(!widget.focusRecovery.offered && ++test.waitCount<12){test.step--;break;}
                    test.check(widget.focusRecovery.offered,"temporary source detected");
                    test.over(test.find(panel.body,"focusRecoveryNotice"),"click");break;
                case 102:
                    test.check(panel.body.recoveryOpen,"temporary consent dialog opened");
                    test.over(test.find(panel.body,"approveFocusProtection"),"click");break;
                case 103:
                    test.check(widget.focusRecovery.granted && !widget.keepSearchFocus,"temporary consent retained");
                    test.step=3;break;
                case 3:
                    test.check(panel.surface.usingNative && panel.body.expanded,"protected expanded search");
                    test.measuring=true;keys.write("key A\n");break;
                case 4:test.sizeMatches();keys.write("key B\n");break;
                case 5:
                    test.sizeMatches();keys.write("key Backspace\n");
                    if(++test.cycles<5)test.step=4;
                    break;
                case 6:var p=panel.surface.nativeGlobalOrigin;test.move(p.x+120*test.scale,p.y+25*test.scale,"double");break;
                case 7:test.check(!panel.body.expanded,"double click must collapse: "+test.state());test.sizeMatches();break;
                case 8:var p=panel.surface.nativeGlobalOrigin;test.move(p.x+120*test.scale,p.y+25*test.scale,"double");break;
                case 9:test.check(panel.body.expanded,"double click must expand: "+test.state());test.sizeMatches();break;
                case 10:
                    test.measuring=false;
                    console.log("MAX_DRIFT:"+test.drift+" SAMPLES:"+test.samples);
                    test.check(test.samples>50 && test.drift<=1,"protected panel must stay anchored throughout resize: drift="+test.drift);
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            }catch(e){console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+e);stop();Qt.quit();}
        }
    }
}
