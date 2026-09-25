import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "HostBar" as Host
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int noticeWaits: 0
    readonly property bool testSuggestion: Quickshell.env("WP_CASE") === "suggestion"
    property int lossRound: 0
    property int retryWaits: 0
    property int failuresInjected: 0
    property int step: 0
    property int notifications: 0
    property Connections reports: Connections {
        target: widget ? widget.focusRecovery : null
        function onNotification(text) { test.notifications++; console.log("RECOVERY_NOTIFICATION:"+text); }
    }
    property var rawFrame: []
    property var rawFrames: []
    property string backgroundText: ""
    property int backgroundWheel: 0
    property int backgroundClicks: 0
    property real priorMaximum: 0
    property var clients: []
    property var resizeSource: null
    property var wheelTarget: null
    property var priorTarget: null
    readonly property int expectedWheel: 240
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
        command:["env","WAYLAND_DEBUG=client","LD_PRELOAD="+Quickshell.env("WINDOWPEEK_TEST_POINTER_PRELOAD"),"quickshell","--no-color","-p",Quickshell.env("WINDOWPEEK_TEST_PROFILE")+"/receiver.qml"]
        running:true
        stderr:SplitParser {onRead:function(line){if(/wl_pointer.*\.(axis|frame)/.test(line)){test.recordWheel(line);console.log("RAW_RECEIVER:"+line);}}}
        stdout:SplitParser {onRead:function(line) {
            if(line.indexOf("BACKGROUND_CLICK")>=0)test.backgroundClicks++;
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
            test.resizeSource=JSON.parse(text).find(function(c){return c.class==="WindowPeekFocusFixture";}) || null;
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
        id: closeSource
        // The synthetic X11 sender deliberately has no WM_DELETE handler.
        // Terminate only this fixture inside the private PID namespace.
        command:["python3", "-c", "import json,os,signal,subprocess; assert os.environ.get('WINDOWPEEK_ISOLATED') == '1'; clients=json.loads(subprocess.check_output(['hyprctl','-j','clients'])); [os.kill(c['pid'],signal.SIGTERM) for c in clients if c['class']=='WindowPeekFocusFixture']"]
    }
    Timer {
        interval:500;running:true;repeat:true
        onTriggered: {
            if(!widget || !panel || !widget.settingsReady || !pointer.ready || !keys.ready || pointer.pending) return;
            try {
                switch(test.step++) {
                case 0: inspectClients.running=true; break;
                case 1: test.check(wheelTarget,"receiver mapped"); test.outside("click"); break;
                case 2: pointer.write("scroll\n"); break;
                case 3:
                    test.check(test.backgroundWheel===-expectedWheel,"baseline scroll delivered");
                    test.backgroundWheel=0; test.rawFrames=[];
                    test.check(!widget.keepSearchFocus,"default off");
                    if (test.testSuggestion) { test.over(widget,"double");test.step=100;break; }
                    test.check(widget.persistSettings({keepSearchFocus:true}),"manual setting saved");
                    test.over(widget,"click"); break;
                case 100:
                    test.check(panel.opened && panel.body.expanded && panel.surface.nativeActive,"visible Search acquired focus");
                    widget.focusRecovery.observerFailed=true;
                    test.noticeWaits=0;
                    test.outside("frame");break;
                case 101: break;
                case 102:
                    if((panel.surface.nativeActive || !widget.focusRecovery.interrupted) && ++test.noticeWaits<8){test.step=102;break;}
                    test.check(!panel.surface.nativeActive,"fictional X11 source triggered actual loss");
                    test.check(!widget.focusRecovery.offered && !widget.focusRecovery.granted && !panel.surface.usingNative,
                        "no attribution or automatic protection");
                    test.lossRound++;
                    test.check(widget.focusRecovery.interrupted,"first unknown-source interruption has a notice");
                    test.check(test.find(panel.body,"focusRecoveryNotice").visible,"unknown-source review button visible");
                    test.check(widget.focusRecovery.suggested === (test.lossRound>=3),"one count per distinct loss, suggestion only after three");
                    if(test.lossRound<3) {panel.close();test.step=103;}
                    else {panel.close();test.step=105;}
                    break;
                case 103: test.over(widget,"double");test.step=100;break;
                case 105: test.over(widget,"click");break;
                case 106:
                    test.check(panel.compactPinned && !widget.focusRecovery.suggested && !panel.body.focusNotice.shown,
                        "earlier repeated losses do not show a warning when reopening only to browse");
                    test.over(test.find(panel.body,"panelHeader"),"double");break;
                case 107:
                    test.check(panel.body.expanded && widget.focusRecovery.suggested,"repeated-loss help remains available in visible Search");
                    test.over(test.find(panel.body,"focusRecoveryNotice"),"click");test.step=104;break;
                case 104:
                    test.check(panel.body.recoveryOpen && !widget.keepSearchFocus,
                        "unknown-source suggestion opens brief explanation, never enables");
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                case 4:
                    test.check(panel.compactPinned && panel.surface.usingNative,"compact opens protected");
                    test.check(!widget.focusRecovery.granted,"no source grant required");
                    test.outside("frame"); break;
                case 5: keys.write("key A\nkey B\nkey C\n"); break;
                case 6:
                    test.check(panel.body.expanded && panel.body.searchField.text==="abc", "outside typing expands pinned search");
                    pointer.write("scroll\n"); break;
                case 7:
                    test.check(test.backgroundWheel===0 && test.rawFrames.length===0,"outside wheel blocked");
                    test.check(panel.surface.nativeActive && panel.body.searchField.activeFocus,"wheel retains focus");
                    pointer.write("finger\n"); break;
                case 8:
                    test.check(test.rawFrames.length===0,"outside FINGER blocked");
                    test.check(panel.surface.nativeActive && panel.body.searchField.activeFocus,"FINGER retains focus");
                    keys.write("key D\n"); break;
                case 9:
                    test.check(panel.body.searchField.text==="abcd" && test.backgroundText==="","typing stays in search after wheel and FINGER");
                    if (test.resizeSource) closeSource.running=true;
                    panel.body.searchField.clear();
                    test.step=90; break;
                case 90:
                    test.check(widget.keepSearchFocus && widget.focusRecovery.manualRequested,"source closure does not disable manual preference");
                    var list=test.find(panel.body,"windowList");
                    test.priorMaximum=panel.body.maximumHeight;
                    panel.body.maximumHeight=panel.body.listChromeHeight+44;
                    break;
                case 91:
                    test.check(test.find(panel.body,"windowList").contentHeight>40,"scrollable search fixture");
                    test.over(test.find(panel.body,"windowList"),"scroll"); break;
                case 92:
                    test.check(panel.body.contentY>0 && panel.surface.nativeActive,"inside wheel scrolls protected search: "+JSON.stringify({y:panel.body.contentY,native:panel.surface.nativeActive,listHeight:test.find(panel.body,"windowList").height,contentHeight:test.find(panel.body,"windowList").contentHeight,at:panel.surface.nativeGlobalOrigin}));
                    panel.body.maximumHeight=test.priorMaximum;
                    test.outside("click"); test.step=10; break;
                case 10:
                    console.log("OUTSIDE_CLICK:"+JSON.stringify({opened:panel.opened,clicks:test.backgroundClicks}));
                    test.check(!panel.opened,"outside click closes");
                    pointer.write("scroll\n"); break;
                case 11:
                    test.check(test.backgroundWheel===-expectedWheel,"scroll restored after close");
                    test.over(widget,"click"); break;
                case 12:
                    test.check(panel.surface.usingNative,"setting protects next opening");
                    panel.toggleExpanded(); break;
                case 13: test.over(test.find(panel.body,"settingsButton"),"click"); break;
                case 14:
                    test.check(panel.body.mode==="settings" && !widget.focusRecovery.protecting,"Settings releases hold");
                    test.outside("scroll");test.step=80;break;
                case 80:
                    console.log("SETTINGS_WHEEL:"+JSON.stringify({actual:test.backgroundWheel,expected:-2*expectedWheel,hold:panel.surface.protectionHold,native:panel.surface.usingNative,paused:panel.surface.protectionPaused,reason:panel.surface.protectionLastYieldReason,rect:[panel.surface.nativeGlobalOrigin.x,panel.surface.nativeGlobalOrigin.y,panel.surface.contentWidth,panel.surface.contentHeight],target:[test.wheelTarget.at[0]+test.wheelTarget.size[0]*.75,test.wheelTarget.at[1]+test.wheelTarget.size[1]*.75]}));
                    test.check(test.backgroundWheel===-2*expectedWheel,"Settings allows outside scrolling");
                    panel.body.showTroubleshooting();test.step=15;break;
                case 15:
                    test.check(panel.body.mode==="troubleshooting","nested troubleshooting");
                    panel.surface.cardItem.grabToImage(function(image){if(Quickshell.env("WINDOWPEEK_TEST_IMAGE"))image.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE"));});
                    panel.body.ensureVisible(test.find(panel.body,"keepSearchFocusToggle"));
                    test.over(test.find(panel.body,"keepSearchFocusToggle"),"click"); break;
                case 16:
                    test.check(!widget.keepSearchFocus && !panel.surface.usingNative,"toggle disables durable mode");
                    keys.write("key Esc\n"); break;
                case 17:
                    test.check(panel.body.mode==="settings","Back returns one level");
                    panel.close(); widget.persistSettings({keepSearchFocus:true}); break;
                case 18: test.over(widget,"click"); break;
                case 19:
                    test.check(panel.surface.usingNative,"manual option can be re-enabled");
                    Hyprland.dispatch("(function() local s=_windowpeek_native_focus_v2; assert(s and s.owner); _windowpeek_old_test_owner=s.owner; s.timer:set_timeout(1); return hl.dsp.no_op() end)()"); break;
                case 20:
                    if ((widget.focusRecovery.protectionFailed || !panel.surface.usingNative) && ++test.retryWaits<12) {test.step--;break;}
                    test.check(panel.surface.usingNative && widget.keepSearchFocus && !widget.focusRecovery.manualFailed,
                        "a transient lease failure automatically restores protection without resetting the setting");
                    test.check(test.notifications===0,"successful automatic recovery has no failure notification");
                    test.check(widget.focusRecovery.lastBackendFailure==="lease-expired","precise cause is retained for diagnostics");
                    Hyprland.dispatch("(function() hl.dispatch(hl.dsp.event('windowpeek-protection-expired,'.._windowpeek_old_test_owner)); return hl.dsp.no_op() end)()");
                    test.step=24;break;
                case 24:
                    test.check(panel.surface.usingNative && !widget.focusRecovery.protectionFailed && widget.focusRecovery.recoveryAttempts===1,
                        "late expiry from an older install cannot cancel the new one");
                    test.retryWaits=0;test.step=21;
                    Hyprland.dispatch("(function() local s=_windowpeek_native_focus_v2; s.timer:set_timeout(1); return hl.dsp.no_op() end)()");break;
                case 21:
                    if ((widget.focusRecovery.protectionFailed || !panel.surface.usingNative) && ++test.retryWaits<12) {test.step--;break;}
                    test.check(panel.surface.usingNative && widget.keepSearchFocus,"second bounded recovery succeeds");
                    Hyprland.dispatch("(function() local s=_windowpeek_native_focus_v2; s.timer:set_timeout(1); return hl.dsp.no_op() end)()");break;
                case 22:
                    test.check(!panel.surface.usingNative && widget.keepSearchFocus && widget.focusRecovery.manualFailed
                        && !widget.focusRecovery.retrying,"repeated failure releases safely and preserves preference without an infinite loop");
                    test.check(test.notifications===1,"one actionable notification after retries are exhausted");
                    test.over(test.find(panel.body,"focusRecoveryNotice"),"click");test.retryWaits=0;break;
                case 23:
                    if(!panel.surface.usingNative && ++test.retryWaits<12){test.step--;break;}
                    test.check(panel.surface.usingNative && widget.keepSearchFocus,"Retry restores protection without another consent or preference reset");
                    panel.close(); widget.persistSettings({keepSearchFocus:false});
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            } catch(error) {console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error);stop();Qt.quit();}
        }
    }
}
