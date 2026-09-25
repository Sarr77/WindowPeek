// Private-compositor regression: a field caret must represent real keyboard delivery.
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "HostBar" as Host
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    readonly property bool crossMonitor: Quickshell.env("WP_TWO") === "1"
    readonly property bool control: Quickshell.env("WP_CASE") === "control"
    readonly property bool intentional: Quickshell.env("WP_CASE") === "intentional"
    property var priorTarget: null
    property int attempts: 0
    property int step: 0
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
    function state() {return JSON.stringify({expanded:panel.body.expanded,text:panel.body.searchField.text,active:panel.body.searchField.activeFocus,background:backgroundText});}
    function check(ok,message) {if(!ok)throw new Error(message);}
    function move(x,y,next) {
        pointer.pending=true;
        pointer.queuedCommand=next==="frame"?"":next;
        pointer.write("move "+Math.round(x)+" "+Math.round(y)+(test.crossMonitor ? " 3840 1080\n" : " 1920 1080\n"));
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
        property bool leaveAfterClick:false
        stdout:SplitParser{onRead:function(line){
            if(line==="ready"){pointer.ready=true;return;}
            if(pointer.queuedCommand){
                var command=pointer.queuedCommand;pointer.queuedCommand="";
                pointer.write(command+"\n");
            }else {
                pointer.pending=false;
                if(pointer.afterClickKey) {keys.write("key "+pointer.afterClickKey+"\n");pointer.afterClickKey="";}
                if(pointer.leaveAfterClick) {pointer.leaveAfterClick=false;test.outside("frame");}
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
                test.wheelTarget=test.clients[0];test.priorTarget=test.clients[1];
            }
        }}
    }
    Process {
        id:switchFocus
        command:["hyprctl","dispatch","hl.dsp.focus({window=\"address:"+(test.priorTarget ? test.priorTarget.address : "")+"\"})"]
        stdout: StdioCollector { onStreamFinished: console.log("FOCUS_COMMAND:"+text) }
        stderr: StdioCollector { onStreamFinished: { if(text) console.log("FOCUS_COMMAND_ERROR:"+text); } }
    }
    Process {
        id:placeReceiver
        command:["hyprctl","eval","for _,w in ipairs(hl.get_windows()) do if w.title=='Fictional second receiver' then hl.dispatch(hl.dsp.window.move({window=w,workspace='2',follow=false})) end end return 'ok'"]
    }
    Timer {
        interval:350;running:true;repeat:true
        onTriggered: {
            if(!widget || !panel || !widget.settingsReady || !pointer.ready || !keys.ready || pointer.pending)return;
            try {
                console.log("FOCUS_RETURN:"+JSON.stringify({step:test.step,native:panel.surface.nativeActive,status:widget.focusRecovery.diagnosticStatus()}));
                switch(test.step++) {
                case 0:
                    if(test.crossMonitor)placeReceiver.running=true;
                    break;
                case 1:inspectClients.running=true;break;
                case 2:
                    test.check(test.wheelTarget && (test.resizeSource || test.control),"fictional receiver and source mapped");
                    if(test.crossMonitor)test.check(test.wheelTarget.at[0]>=1920,"receiver on second monitor");
                    test.outside("click");break;
                case 3:test.over(widget,"double");break;
                case 4:
                    test.check(panel.opened && panel.body.expanded && panel.surface.nativeActive,"expanded search acquired actual focus");
                    test.check(!widget.focusRecovery.interrupted && !widget.focusRecovery.suggested && !widget.focusRecovery.offered,"fresh detection, no old status");
                    if(test.intentional)switchFocus.running=true;
                    else if(test.crossMonitor)test.outside("frame");
                    else {pointer.leaveAfterClick=true;test.over(panel.body.searchField,"click");}
                    break;
                case 5:
                    if(test.control) {
                        if(++test.attempts<8){test.step--;break;}
                        test.check(panel.surface.nativeActive && !widget.focusRecovery.interrupted && !widget.focusRecovery.offered,"pointer movement without loss produces no notice");
                        console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                    }
                    if(panel.surface.nativeActive && ++test.attempts<8){test.step--;break;}
                    test.check(!panel.surface.nativeActive,"actual loss after pointer exit");
                    test.attempts=0;
                    // Cross back to the panel's monitor, still over an app and
                    // without clicking. That movement must not erase the loss.
                    if(test.crossMonitor)test.move(1100,600,"frame");
                    break;
                case 6:
                    if(test.intentional) {
                        if(++test.attempts<8){test.step--;break;}
                        test.check(!panel.surface.nativeActive && !widget.focusRecovery.interrupted && !widget.focusRecovery.offered && !widget.focusRecovery.suggested,"explicit focus transfer is not a search interruption");
                        console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                    }
                    if(!widget.focusRecovery.interrupted && ++test.attempts<8){test.step--;break;}
                    test.check(!panel.surface.nativeActive && panel.opened,"search remains interrupted and open");
                    test.check(widget.focusRecovery.interrupted && test.find(panel.body,"focusRecoveryNotice").visible,"fresh loss must show help after clicking search or crossing monitors and back");
                    test.check(!widget.focusRecovery.granted && !widget.keepSearchFocus,"no automatic protection");
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            }catch(e){console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+e);stop();Qt.quit();}
        }
    }
}
