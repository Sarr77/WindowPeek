import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "HostBar" as Host
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property int disappearances: 0
    property bool counting: false
    property Connections mapping: Connections {
        target: panel ? panel.surface : null
        function onHoverOpenChanged() {
            if(test.counting && !test.panel.surface.hoverOpen) test.disappearances++;
        }
    }
    property var rawFrame: []
    property var rawFrames: []
    property string baselineProtocol: ""
    property string backgroundText: ""
    property int backgroundWheel: 0
    property var clients: []
    property var wheelTarget: null
    property var priorTarget: null
    property string confirmedPrior: ""
    property var results: ({})
    readonly property int expectedWheel: 240
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var widget: hostBar.moduleWidgets("sarr.windowpeek").find(function(w) { return w.screenName === (Quickshell.env("WP_TWO")==="1" ? "WPTEST2" : "WPTEST"); }) || null
    readonly property var panel: find(widget,"windowPeekController")
    function find(item,name) {
        if (!item) return null;
        if (item.objectName===name) return item;
        for (var child of item.children || []) { var r=find(child,name);if(r)return r; }
        return null;
    }
    function state() {return JSON.stringify({expanded:panel.body.expanded,text:panel.body.searchField.text,active:panel.body.searchField.activeFocus,background:backgroundText});}
    function check(ok,message) {if(!ok)throw new Error(message);}
    function result(name,ok,detail) {results[name]=ok;console.log("RESULT:"+name+":"+ok+":"+detail);}
    function recordWheel(line) {
        var match=line.match(/wl_pointer[^.]*\.(axis(?:_source|_discrete|_value120|_relative_direction|_stop)?|frame)\((.*)\)/);
        if(!match)return;
        var name=match[1];
        if(name==="frame") {
            if(rawFrame.length){rawFrames=rawFrames.concat([rawFrame]);rawFrame=[];}
            return;
        }
        var args=match[2].split(",").map(function(v){return Number(v.trim());});
        if(name==="axis" || name==="axis_stop")args.shift();
        rawFrame=rawFrame.concat([{event:name,args:args}]);
    }
    function move(x,y,next) {
        pointer.pending=true;
        pointer.queuedCommand=next==="frame"?"":next;
        warp.command=["hyprctl","dispatch","hl.dsp.cursor.move({x="+Math.round(x)+",y="+Math.round(y)+"})"];warp.running=true;
    }
    Process { id: warp; onExited: pointer.write("frame\n") }
    function outside(next) {move(wheelTarget.at[0]+wheelTarget.size[0]*0.75,wheelTarget.at[1]+wheelTarget.size[1]*0.75,next);}
    function over(item,next) {var p=item.mapToGlobal(item.width/2,item.height/2);move(p.x,p.y,next);}
    Process {
        id: app
        command:["env","WAYLAND_DEBUG=client","LD_PRELOAD="+Quickshell.env("WINDOWPEEK_TEST_POINTER_PRELOAD"),"quickshell","--no-color","-p",Quickshell.env("WINDOWPEEK_TEST_PROFILE")+"/receiver.qml"]
        running:true
        stderr:SplitParser {onRead:function(line){if(/wl_pointer.*\.(axis|frame)/.test(line)){test.recordWheel(line);console.log("RAW_RECEIVER:"+line);}}}
        stdout:SplitParser {onRead:function(line) {
            if(line.indexOf("BACKGROUND_WHEEL:")>=0)test.backgroundWheel+=Number(line.split("BACKGROUND_WHEEL:")[1].trim());
            if(line.indexOf("BACKGROUND_KEY:")>=0)test.backgroundText+=line.split("BACKGROUND_KEY:")[1].trim();
        }}
    }
    QtObject {
        id:shell
        property var config: ({bar:{position:"top",transparent:false,layout:{left:[{
            id:"sarr.windowpeek",autoUpdates:false,windowPreviews:false,openOnHover:true,panelHoverDelay:0,
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
                test.priorTarget=test.clients[Quickshell.env("WP_TARGET")==="same"?0:1];
                console.log("TARGETS:"+JSON.stringify({wheel:test.wheelTarget.title,prior:test.priorTarget.title}));
            }
        }}
    }
    Process {
        id:setPrior
        command:["hyprctl","dispatch","hl.dsp.focus({window=\"address:"+(test.priorTarget?test.priorTarget.address:"")+"\"})"]
        onExited:queryPrior.running=true
    }
    Process {
        id:queryPrior;command:["hyprctl","-j","activewindow"]
        stdout:StdioCollector {onStreamFinished:test.confirmedPrior=JSON.parse(text).address || ""}
    }
    Timer {
        interval:550;running:true;repeat:true
        onTriggered: {
            if(!keys.running){keys.ready=false;keys.running=true;return;}
            if(!widget || !widget.settingsReady || !panel || !pointer.ready || pointer.pending || !keys.ready)return;
            try {
                switch(test.step++) {
                case 0: console.log("ANCHOR:"+JSON.stringify(widget.mapToGlobal(widget.width/2,widget.height/2))+" screen="+widget.screenName); test.over(widget,"frame");break;
                case 1: test.counting=true;break;
                case 2:case 3:case 4:case 5:case 6:case 7:
                    console.log("HOVER:"+JSON.stringify({step:test.step,mapped:panel.mapped,hover:panel.hoverOpened,bar:widget.barLabelHovered,proxy:panel.surface.barAnchorHovered,requested:panel.hoverRequested,canHide:panel.canHideHover,bridge:panel.surface.barBridgeHovered,nativeActive:panel.surface.nativeActive,keyboard:panel.surface.keyboardActive,card:panel.surface.cardOrigin,anchor:panel.surface.anchorScreenPos,screen:panel.surface.screen.name,prime:panel.surface.focusPrimed,pointerReady:panel.surface.pointerReady}));break;
                case 8:
                    test.check(panel.mapped && panel.hoverOpened && test.disappearances===0,"stationary bar hover stays mapped; disappearances="+test.disappearances);
                    test.counting=false;keys.write("key Esc\n");break;
                case 9:case 10: console.log("CLOSING:"+JSON.stringify({mapped:panel.mapped,hover:panel.hoverOpened,dismissed:widget.hoverDismissed,bar:widget.barLabelHovered,active:panel.surface.nativeActive}));break;
                case 11:
                    test.check(!panel.mapped,"Escape suppresses reopening under the same pointer");
                    test.move(1500,900,"frame");break;
                case 12: test.over(widget,"frame");break;
                case 13:
                    test.check(panel.mapped,"real exit/reentry opens hover again");
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            }catch(error){console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error);stop();Qt.quit();}
        }
    }
}
