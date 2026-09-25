import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "HostBar" as Host
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    readonly property string testMode: Quickshell.env("WP_CASE")
    property int controlWait: 0
    property int approvalWaits: 0
    property string stopText: ""
    property bool measuringExpansion: false
    property var expansionFrames: []
    property Connections immediateExpansion: Connections {
        target: widget ? widget.focusRecovery : null
        function onGrantedChanged() {
            if(test.testMode === "first-expand" && widget.focusRecovery.granted) {
                // A user gesture can arrive after the consent handler finishes,
                // once the dialog's input bindings allow panel gestures again.
                Qt.callLater(function() {
                    test.measuringExpansion=true;
                    panel.toggleExpanded();
                });
            }
        }
    }
    property Connections expansionProbe: Connections {
        target: panel ? panel.surface.cardItem.Window.window : null
        function onFrameSwapped() {
            if(test.measuringExpansion) test.expansionFrames=test.expansionFrames.concat([{
                value:panel.expansion,native:panel.surface.usingNative,width:panel.surface.contentWidth,windowWidth:panel.surface.contentWindow.width,
                snapshot:panel.surface.surfaceSnapshot!==null}]);
        }
    }
    property int step: testMode === "background" ? -3 : 0
    property int waitCount: 0
    property int notifications: 0
    property Connections reports: Connections {
        target: widget ? widget.focusRecovery : null
        function onNotification(text) { test.notifications++; console.log("RECOVERY_NOTIFICATION:"+text); }
    }
    property var rawFrame: []
    property var rawFrames: []
    property string baselineProtocol: ""
    property string backgroundText: ""
    property int backgroundWheel: 0
    property var clients: []
    property var resizeSource: null
    property var wheelTarget: null
    property var priorTarget: null
    property string confirmedPrior: ""
    property var results: ({})
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
        id: hideSource
        command: ["hyprctl", "eval", "for _,w in ipairs(hl.get_windows()) do if w.class=='WindowPeekFocusFixture' then hl.dispatch(hl.dsp.window.move({window=w,workspace='7',follow=false})) end end return 'ok'"]
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
    Process { id: nativeGeometry; command:["hyprctl","-j","clients"]; stdout:StdioCollector{onStreamFinished:console.log("NATIVE_GEOMETRY:"+JSON.stringify(JSON.parse(text).filter(function(c){return c.title.indexOf("WindowPeek protection ")===0}).map(function(c){return {at:c.at,size:c.size}})))} }
    Process {
        id: closeSource
        // The synthetic X11 sender deliberately has no WM_DELETE handler.
        // Terminate only this fixture inside the private PID namespace.
        command:["python3", "-c", "import json,os,signal,subprocess; assert os.environ.get('WINDOWPEEK_ISOLATED') == '1'; clients=json.loads(subprocess.check_output(['hyprctl','-j','clients'])); [os.kill(c['pid'],signal.SIGTERM) for c in clients if c['class']=='WindowPeekFocusFixture']"]
    }
    Timer {
        interval:550;running:true;repeat:true
        onTriggered: {
            if(!keys.running){keys.ready=false;keys.running=true;return;}
            if(!widget || !widget.settingsReady || !panel || !pointer.ready || pointer.pending || !keys.ready)return;
            try {
                if (test.testMode === "ignore" && test.step >= 10) {
                    var recovery = widget.focusRecovery;
                    switch(test.step++) {
                    case 10:
                        test.over(test.find(panel.body,"focusIgnoreApp"),"click"); break;
                    case 11:
                        test.check(recovery.issues.apps.length===1 && recovery.issues.apps[0].ignored,
                            "real attributed app persisted and ignored");
                        test.check(!recovery.offered && !recovery.granted && !panel.body.recoveryOpen,
                            "ignore closes notice without protection");
                        widget.close();test.outside("frame");break;
                    case 12: widget.open();break;
                    case 13: test.outside("frame");test.controlWait=0;break;
                    case 14:
                        if(++test.controlWait<6){test.step--;break;}
                        test.check(!recovery.offered && !recovery.interrupted && !recovery.suggested,
                            "ignored app cannot leak a generic notice on reopening");
                        test.check(recovery.issues.apps[0].incidents>=2,"muted incidents still recorded");
                        recovery.issues.choose("app",false,recovery.issues.apps[0].key);
                        widget.close();test.outside("frame");break;
                    case 15: widget.open();break;
                    case 16: test.outside("frame");test.waitCount=0;break;
                    case 17:
                        if(!recovery.offered && test.waitCount++<8){test.step--;break;}
                        test.check(!!recovery.offered && !recovery.granted,"restoring app warnings allows next incident");
                        console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                    }
                    return;
                }
                switch(test.step++) {
                case -3: inspectClients.running=true;break;
                case -2:
                    test.check(test.wheelTarget && test.priorTarget,"receivers precede source move");
                    hideSource.running=true;break;
                case -1: inspectClients.running=true;break;
                case 0:console.log("USING_LUA:"+Hyprland.usingLua);inspectClients.running=true;break;
                case 1:
                    if(test.testMode === "background")
                        test.check(test.resizeSource && test.resizeSource.mapped
                            && test.resizeSource.workspace.id===7,"resize source on inactive workspace");
                    test.check(test.wheelTarget && test.priorTarget,"two receiver windows mapped");
                    test.outside("click");break;
                case 2:pointer.write("scroll\n");break;
                case 3:
                    test.check(test.backgroundWheel===-expectedWheel,"direct baseline "+test.backgroundWheel);
                    test.baselineProtocol=JSON.stringify(test.rawFrames);
                    console.log("BASELINE_PROTOCOL:"+test.baselineProtocol);
                    test.rawFrames=[];test.backgroundWheel=0;setPrior.running=true;break;
                case 4:
                    test.check(test.confirmedPrior===test.priorTarget.address,"confirmed pre-panel active receiver");
                    if(test.testMode === "background")
                        test.check(test.resizeSource.workspace.id!==test.priorTarget.workspace.id,"source workspace differs from focused receiver");
                    test.over(widget,"frame");break;
                case 5:pointer.write("click\n");break;
                case 6:
                    test.check(panel.compactPinned,"bar click pins compact");
                    if(test.testMode === "unknown") widget.focusRecovery.observerFailed=true;
                    if(test.testMode === "first-expand") {panel.toggleExpanded();test.step=127;break;}
                    keys.write("key A\nkey B\nkey C\n");break;
                case 7:
                    test.result("PINNED_TYPING",panel.body.expanded && panel.body.searchField.text==="abc",test.state());
                    panel.body.searchField.clear();test.outside("frame");break;
                case 8:
                    if (test.testMode === "none" || test.testMode === "floating") {
                        if (++test.controlWait < 7) { test.step--; break; }
                        test.check(!widget.focusRecovery.offered && !widget.focusRecovery.interrupted && !widget.focusRecovery.suggested
                            && !widget.focusRecovery.granted && !panel.surface.usingNative,"control has no notice, offer or protection");
                        console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                    }
                    console.log("DETECTION:"+JSON.stringify({offered:!!widget.focusRecovery.offered,session:widget.focusRecovery.session,failed:widget.focusRecovery.observerFailed,sources:widget.focusRecovery.sources.length,native:panel.surface.nativeActive,at:widget.focusRecovery.sourcesAt}));
                    if(!(test.testMode === "unknown" ? widget.focusRecovery.interrupted : widget.focusRecovery.offered) && test.waitCount++<8){test.step--;break;}
                    test.check(test.testMode === "unknown" ? widget.focusRecovery.interrupted && !widget.focusRecovery.offered : !!widget.focusRecovery.offered,"actual incident was detected");
                    if(test.testMode === "background")
                        test.check(widget.focusRecovery.sources.length===1,"unmapped helpers excluded from managed source list");
                    test.check(!widget.focusRecovery.granted && !panel.surface.usingNative,"no protection without consent");
                    if(test.testMode === "first-expand") {panel.toggleExpanded();test.step=126;break;}
                    test.over(test.find(panel.body,"focusRecoveryNotice"),"click");break;
                case 126: test.over(test.find(panel.body,"focusRecoveryNotice"),"click");test.step=9;break;
                case 127: test.outside("frame");test.step=8;break;
                case 9:
                    test.check(panel.body.recoveryOpen,"explanation opened by actual click");
                    panel.body.grabToImage(function(image) { if (Quickshell.env("WINDOWPEEK_TEST_IMAGE")) image.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE")); });
                    test.over(test.find(panel.body,test.testMode === "ignore" ? "focusIgnoreMenu" : test.testMode === "decline" ? "declineFocusProtection" : "approveFocusProtection"),"click");break;
                case 10:
                    if (test.testMode === "decline") {
                        test.check(!panel.body.recoveryOpen && !widget.focusRecovery.offered && !widget.focusRecovery.granted && !panel.surface.usingNative,"decline leaves normal input mode");
                        console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                    }
                    if(widget.focusRecovery.pendingApproval && ++test.approvalWaits<10){test.step--;break;}
                    console.log("GRANT:"+JSON.stringify({granted:widget.focusRecovery.granted,native:panel.surface.usingNative,message:widget.focusRecovery.message}));
                    test.check(widget.focusRecovery.granted && panel.surface.usingNative,"consented native protection mapped");
                    test.check(test.testMode === "unknown" ? widget.focusRecovery.sessionProtection && widget.focusRecovery.protectionApp === "" : widget.focusRecovery.protectionApp.length > 0,
                        "consent uses the stated scope and never invents a source app");
                    if(test.testMode === "first-expand") {test.step=124;break;}
                    panel.body.searchField.clear();test.outside("frame");break;
                case 11: keys.write("key D\n");break;
                case 12:
                    test.check(!panel.surface.protectionPaused && panel.surface.protectionLastYieldReason === "", "motion and typing must not pause protection");
                    test.result("PROTECTED_TYPING",panel.body.searchField.text==="d" && panel.body.searchField.activeFocus,test.state());
                    pointer.write("scroll\n");break;
                case 13:
                    test.check(panel.surface.protectionPaused && panel.surface.protectionLastYieldReason === "outside-wheel" && panel.surface.protectionLastYieldAt > 0, "outside wheel pause has an explicit reason");
                    test.result("FIRST_WHEEL",test.backgroundWheel===-expectedWheel,"amount="+test.backgroundWheel);
                    test.result("FIRST_WHEEL_PROTOCOL",JSON.stringify(test.rawFrames)===test.baselineProtocol,JSON.stringify(test.rawFrames));
                    pointer.write("scroll\n");break;
                case 14:
                    test.result("SECOND_WHEEL",test.backgroundWheel===-2*expectedWheel,"amount="+test.backgroundWheel);
                    test.outside("click");break;
                case 15:
                    test.check(panel.surface.protectionLastYieldReason === "outside-wheel", "first pause cause survives subsequent outside click and dismissal");
                    test.result("OUTSIDE_DISMISS",!panel.opened,test.state());
                    test.check(widget.focusRecovery.granted,"consent retained while source lives");
                    test.over(widget,"click");break;
                case 16:
                    test.check(panel.surface.usingNative,"reopened panel reuses same-window consent");
                    if (test.testMode === "recover") {
                        Hyprland.dispatch("(function() local s=_windowpeek_native_focus_v2; s.timer:set_timeout(1); return hl.dsp.no_op() end)()");
                        test.controlWait=0;test.step=110;break;
                    }
                    if (test.testMode === "ui") { panel.toggleExpanded(); test.step=19; }
                    else if (test.testMode === "stop" || test.testMode === "unknown") { test.stopText=panel.body.searchField.text; test.over(test.find(panel.body,"turnOffFocusProtection"),"click"); }
                    else closeSource.running=true;break;
                    case 110:
                    if((!panel.surface.usingNative || widget.focusRecovery.temporaryFailed) && ++test.controlWait<12){test.step--;break;}
                    test.check(widget.focusRecovery.granted && panel.surface.usingNative && !widget.focusRecovery.temporaryFailed,
                        "temporary consent survives backend failure and protection recovers");
                    test.check(test.notifications===0,"temporary transient error does not revoke consent or issue an off notice");
                    closeSource.running=true;test.step=17;break;
                case 17:
                    test.check(!widget.focusRecovery.granted && !panel.surface.usingNative,"closing source automatically ends protection");
                    test.check(test.notifications===1,"one end-of-protection notification");
                    if(test.testMode === "stop" || test.testMode === "unknown") {
                        test.check(panel.opened && panel.body.searchField.text === test.stopText,"Turn off preserves open search and text: "+test.state());
                        test.check((test.testMode === "unknown" ? widget.focusRecovery.sessionProtectionStopped : widget.focusRecovery.offeringStopped) && panel.body.focusNotice.shown && !panel.body.focusNotice.attention,
                            "compact panel retains quiet Options after Turn off");
                        panel.close();test.step=120;break;
                    }
                    test.result("AUTO_OFF",true,"notification="+test.notifications);
                    test.outside("click");break;
                case 120: test.over(widget,"click");break;
                case 121:
                    test.check(panel.compactPinned && (test.testMode === "unknown" ? widget.focusRecovery.sessionProtectionStopped : widget.focusRecovery.offeringStopped),"reopened compact panel retains manual choice");
                    test.over(test.find(panel.body,"focusRecoveryNotice"),"click");break;
                case 122:
                    test.check(test.find(panel.body,"approveFocusProtection")!==null,"short review still offers temporary protection");
                    test.over(test.find(panel.body,"approveFocusProtection"),"click");test.approvalWaits=0;break;
                case 123:
                    if((widget.focusRecovery.pendingApproval || !panel.surface.usingNative) && ++test.approvalWaits<12){test.step--;break;}
                    test.check(widget.focusRecovery.granted && panel.surface.usingNative && panel.compactPinned,"explicit reapproval protects compact panel");
                    test.measuringExpansion=true;panel.toggleExpanded();break;
                case 124:
                    test.measuringExpansion=false;
                    console.log("FIRST_PROTECTED_EXPANSION:"+JSON.stringify(test.expansionFrames));
                    test.check(panel.body.expanded && test.expansionFrames.filter(function(f){return f.value>0 && f.value<1;}).length>=3,
                        "first protected expansion renders intermediate widths");
                    if(test.testMode === "first-expand") test.check(test.expansionFrames.every(function(f) {
                        return (f.native && !f.snapshot) || f.value===0;
                    }),"animation cannot advance behind the surface-transfer snapshot");
                    closeSource.running=true;break;
                case 125:
                    if(test.testMode === "unknown") {
                        test.check(widget.focusRecovery.granted && widget.focusRecovery.sessionProtection,"unrelated window closure cannot end unattributed consent");
                        widget.focusRecovery.stop("user");
                        test.check(!widget.focusRecovery.granted && !widget.keepSearchFocus,"manual stop ends temporary consent without a permanent preference");
                    } else test.check(!widget.focusRecovery.granted && !widget.focusRecovery.offeringStopped,"source closure clears temporary choice");
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                case 18:
                    console.log("FINAL_UI_STATE:"+test.state()+" mode="+panel.body.mode+" native="+panel.surface.nativeActive);
                    if (test.testMode === "ui") {
                        test.check(panel.body.mode === "windows" && panel.surface.usingNative && panel.body.searchField.activeFocus,"Back restores protected search");
                        test.check(panel.body.searchField.text === "e", "typing after Back remains in search");
                        test.result("SETTINGS_BACK",true,"");
                    }
                    console.log("RECOVERY_RESULTS:"+JSON.stringify(test.results));
                    if(Object.keys(test.results).every(function(k){return test.results[k];}))console.log("WINDOWPEEK_TEST_PASS");
                    else console.error("WINDOWPEEK_TEST_FAIL: recovery contract");
                    stop();Qt.quit();break;
                case 19:
                    test.check(panel.body.expanded,"protected panel expands before Settings");
                    nativeGeometry.running=true;test.over(test.find(panel.body,"settingsButton"),"click");break;
                case 20:
                    console.log("SETTINGS_STATE:"+JSON.stringify({mode:panel.body.mode,native:panel.surface.usingNative,granted:widget.focusRecovery.granted,protecting:widget.focusRecovery.protecting,eligible:widget.focusRecovery.protectionEligible,popup:!!panel.body.currentPopup,opened:panel.opened,card:panel.surface.cardOrigin,size:[panel.surface.contentWidth,panel.surface.contentHeight],active:panel.surface.nativeActive,bodyActive:panel.body.Window.active,bodyWindow:String(panel.body.Window.window),cardWindow:String(panel.surface.cardItem.Window.window),surface:String(panel.surface.contentWindow),current:panel.body.searchField.activeFocus}));
                    test.check(panel.body.mode === "settings" && panel.surface.usingNative && widget.focusRecovery.protecting,"settings retain protection");
                    keys.write("key Esc\n");break;
                case 21: keys.write("key E\n"); test.step=18;break;
                }
            }catch(error){console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error);stop();Qt.quit();}
        }
    }
}
