// Private two-monitor compositor: seeded mixed actions with real pointer/key events.
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "HostBar" as Host
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int previewWait: 0
    property int approvalRetries: 0
    property int monitorIndex: Quickshell.env("WP_CASE") === "preview-offset" ? 1 : 0
    property int randomSeed: Number(Quickshell.env("WP_TARGET")) || 7
    property var tasks: []
    property int taskIndex: 0
    property string expectedText: ""
    property bool pendingText: false
    function active() { check(panel.opened && panel.surface.usingNative && panel.surface.nativeActive && !panel.surface.protectionPaused,"protected search must own keyboard: "+state()); }
    property bool measuringMotion: false
    property var motionFrames: []
    property var motionRuns: []
    Connections {
        target: panel ? panel.body.Window.window : null
        function onFrameSwapped() {
            if(!test.measuringMotion)return;
            var preview=widget.windowPreview;
            test.motionFrames.push({at:Date.now(),width:panel.surface.contentWidth,
                surfaceWidth:panel.body.Window.window.width,surfaceHeight:panel.body.Window.window.height,
                shared:!preview.visible || preview.contentItem.Window.window===panel.body.Window.window,
                gap:preview.visible ? preview.screenOrigin.x+preview.bridgeWidth-(panel.surface.cardOrigin.x+panel.surface.contentWidth) : null});
        }
    }
    function makeTasks() {
        if (Quickshell.env("WP_CASE") === "motion") {
            tasks=["active"];
            for(var screen=0;screen<2;screen++) {
                for(var withPreview=0;withPreview<2;withPreview++) {
                    tasks.push(withPreview ? "enablePreview" : "disablePreview");
                    if(withPreview)tasks=tasks.concat(["preview","wait","previewShown"]);
                    tasks=tasks.concat(["motionBegin","collapse","compact","expand","expanded","collapse","compact","expand","expanded","motionEnd"]);
                }
                tasks=tasks.concat(["close","closed"]);
                if(screen===0)tasks=tasks.concat(["switch","open","active"]);
            }
            return;
        }
        if (["preview-exit", "preview-offset"].indexOf(Quickshell.env("WP_CASE")) >= 0) {
            tasks=["active","preview","wait","previewShown","previewEnter","wait","previewInside","out1","wait","type","close","closed"];
            return;
        }
        var blocks = [
            ["out0","type","out1","type"],
            ["collapse","compact","out1","type","expanded"],
            ["barToggle","compact","out0","type","expanded"],
            ["preview","wait","previewShown","previewEnter","wait","previewClick","closed","open","active"],
            ["out1","wheel","paused","barToggle","compact","out0","type","expanded"],
            ["closeBar","wait","closed","switch","open","active","type"],
            ["close","closed","switch","open","active","out0","type"],
            ["out1","wheel","paused","resume","active","type"],
            ["closeOutside","closed","switch","openCompact","active","out0","type","expanded"]
        ];
        for(var i=blocks.length-1;i>0;i--) { randomSeed=(randomSeed*1664525+1013904223)>>>0;var j=randomSeed%(i+1);var shuffledBlock=blocks[i];blocks[i]=blocks[j];blocks[j]=shuffledBlock; }
        tasks=["active","preview","wait","previewShown","previewEnter","wait","previewClick","closed","open","active","out1","wait","type"];
        for(var block of blocks)tasks=tasks.concat(block);
        tasks=tasks.concat(["close","closed"]);
    }
    function action(name) {
        check(backgroundText==="","no typing may reach either background receiver");
        if(pendingText) { check(panel.body.searchField.text===expectedText && panel.surface.nativeActive,"typed character reached protected search expected="+expectedText+" state="+state()+" native="+panel.surface.nativeActive);pendingText=false; }
        console.log("CYCLE:"+JSON.stringify({action:name,monitor:monitorIndex,opened:panel.opened,native:panel.surface.nativeActive,paused:panel.surface.protectionPaused,reason:panel.surface.protectionLastYieldReason,protecting:widget.focusRecovery.protecting,hold:panel.surface.protectionHold,onPreview:panel.surface.pointerOnPreview,eligible:widget.focusRecovery.protectionEligible,age:Date.now()-widget.focusRecovery.state.observedAt,poll:widget.focusRecovery.guardPoll.interval,pollRunning:widget.focusRecovery.guardPoll.running,interacting:panel.body.interacting,popup:!!panel.body.currentPopup,busy:panel.body.busy,dialog:panel.body.recoveryOpen,menu:panel.destinationMenu.opened,preview:panel.childPreviewVisible,previewContains:widget.windowPreview.containsPointer,shortcut:widget.windowPreview.shortcutTarget ? widget.windowPreview.shortcutTarget.objectName : "none"}));
        switch(name) {
        case "enablePreview":widget.persistSettings({windowPreviews:true});break;
        case "disablePreview":widget.persistSettings({windowPreviews:false});break;
        case "motionBegin":motionFrames=[];measuringMotion=true;break;
        case "motionEnd":
            measuringMotion=false;
            motionRuns.push({monitor:monitorIndex,preview:panel.childPreviewVisible,frames:motionFrames});
            console.log("PROTECTED_MOTION:"+JSON.stringify(motionRuns[motionRuns.length-1]));break;
        case "expand":var q=panel.surface.nativeGlobalOrigin;move(q.x+120*scale,q.y+25*scale,"double");break;
        case "out0":move(1450,900,"frame");break;
        case "out1":move(3370,900,"frame");break;
        case "type":active();expectedText=panel.body.searchField.text+"a";pendingText=true;keys.write("key A\n");break;
        case "wait":break;
        case "preview":over(find(panel.body,"windowFocus"),"frame");break;
        case "previewEnter":var thumb=widget.windowPreview;var point=Qt.point(thumb.globalOrigin.x+thumb.width/2,thumb.globalOrigin.y+thumb.height/2);console.log("PREVIEW_TARGET:"+JSON.stringify({mapped:point,placed:thumb.screenOrigin,contains:thumb.containsPointer}));move(point.x,point.y,"frame");break;
        case "previewInside":check(panel.surface.pointerOnPreview && widget.windowPreview.containsPointer,"preview on offset monitor receives actual pointer input");break;
        case "previewClick":check(widget.windowPreview.containsPointer,"preview has actual pointer input");pointer.write("click\n");break;
        case "previewShown":if(!panel.childPreviewVisible && ++previewWait<5){over(find(panel.body,"windowFocus"),"frame");taskIndex--;break;}previewWait=0;check(panel.childPreviewVisible,"real child preview must be visible");check(widget.focusRecovery.protecting,"visible preview alone must not stop keyboard protection");if(tasks[taskIndex]==="previewEnter"){taskIndex++;action("previewEnter");}break;
        case "closeBar":over(widget,"click");break;
        case "close":active();keys.write("key Esc\n");break;
        case "closeOutside":move(monitorIndex ? 3370 : 1450,900,"click");break;
        case "closed":check(!panel.opened && !panel.mapped,"closed panel unmapped");break;
        case "switch":monitorIndex=1-monitorIndex;break;
        case "open":over(widget,"double");break;
        case "openCompact":over(widget,"click");break;
        case "active":active();break;
        case "barToggle":over(widget,"double");break;
        case "collapse":if(panel.body.expanded){var p=panel.surface.nativeGlobalOrigin;move(p.x+120*scale,p.y+25*scale,"double");}break;
        case "compact":check(!panel.body.expanded,"compact after collapse");break;
        case "expanded":check(panel.body.expanded,"typing expands compact panel");break;
        case "wheel":wheelBefore=backgroundWheel;pointer.write("scroll\n");break;
        case "paused":check(backgroundWheel-wheelBefore===-240,"the first outside wheel reaches the receiver in full");check(panel.surface.protectionPaused && panel.surface.protectionLastYieldReason==="outside-wheel","outside wheel deliberately pauses");break;
        case "resume":if(!panel.body.expanded){var p=panel.surface.nativeGlobalOrigin;move(p.x+120*scale,p.y+25*scale,"double");}else over(panel.body.searchField,"click");break;
        }
    }
    property int waitCount: 0
    property int step: 0
    property string backgroundText: ""
    property int backgroundWheel: 0
    property int wheelBefore: 0
    property var clients: []
    property var resizeSource: null
    property var wheelTarget: null
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var widget: hostBar.moduleWidgets("sarr.windowpeek")[monitorIndex] || null
    readonly property var panel: find(widget,"windowPeekController")
    function find(item,name) {
        if (!item) return null;
        if (item.objectName===name) return item;
        for (var child of item.children || []) { var r=find(child,name);if(r)return r; }
        return null;
    }
    function state() {return JSON.stringify({expanded:panel.body.expanded,text:panel.body.searchField.text,opened:panel.opened,compact:panel.compactPinned,allowed:panel.body.backgroundToggleAllowed,interacting:panel.body.interacting,pending:widget.barClickPending,barHovered:widget.barLabelHovered,active:panel.body.searchField.activeFocus,background:backgroundText});}
    function check(ok,message) {if(!ok)throw new Error(message);}
    function move(x,y,next) {
        pointer.pending=true;
        pointer.queuedCommand=next==="frame"?"":next;
        pointer.write("move "+Math.round(x)+" "+Math.round(y)+" 3840 1080\n");
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
            id:"sarr.windowpeek",autoUpdates:false,windowPreviews:true,previewHoverDelay:0,openOnHover:false,
            doubleClickExpand:true,keepSearchFocus:false,uiScale:test.scale}],center:[],right:[]}}})
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
        id:placeReceiver
        command:["hyprctl","eval","for _,w in ipairs(hl.get_windows()) do if w.title=='Fictional second receiver' then hl.dispatch(hl.dsp.window.move({window=w,workspace='2',follow=false})) end end return 'ok'"]
    }
    Timer {
        interval:350;running:true;repeat:true
        onTriggered: {
            if(!widget || !panel || !widget.settingsReady || !pointer.ready || !keys.ready || pointer.pending)return;
            try {
                switch(test.step++) {
                case 0:placeReceiver.running=true;break;
                case 1:inspectClients.running=true;break;
                case 2:
                    test.check(hostBar.moduleWidgets("sarr.windowpeek").length===2 && test.wheelTarget.at[0]>=1920 && test.clients[1].at[0]<1920,"two monitors and a receiver on each");
                    test.outside("click");break;
                case 3:test.over(widget,"double");break;
                case 4:test.outside("frame");break;
                case 5:
                    if (Quickshell.env("WP_TARGET") === "permanent") {
                        test.check(widget.persistSettings({keepSearchFocus:true}),"permanent protection saved");
                        test.makeTasks();test.step=8;break;
                    }
                    if(!widget.focusRecovery.offered && ++test.waitCount<12){test.step--;break;}
                    test.check(widget.focusRecovery.offered,"temporary source detected");
                    test.over(test.find(panel.body,"focusRecoveryNotice"),"click");break;
                case 6:test.check(panel.body.recoveryOpen,"consent dialog");test.over(test.find(panel.body,"approveFocusProtection"),"click");break;
                case 7:if(widget.focusRecovery.pendingApproval && ++test.waitCount<12){test.step--;break;}console.log("CONSENT_STATE:"+JSON.stringify({granted:widget.focusRecovery.granted,message:widget.focusRecovery.message,open:panel.opened,dialog:panel.body.recoveryOpen,native:panel.surface.nativeActive,screen:widget.screenName,offered:!!widget.focusRecovery.offered,strict:widget.keepSearchFocus}));if(!widget.focusRecovery.granted && panel.body.recoveryOpen && widget.focusRecovery.message && ++test.approvalRetries<3){test.over(test.find(panel.body,"approveFocusProtection"),"click");test.step--;break;}test.check(widget.focusRecovery.granted && !widget.keepSearchFocus,"temporary consent");test.makeTasks();break;
                default:
                    if(test.taskIndex>=test.tasks.length){
                        if(Quickshell.env("WP_CASE")==="motion") {
                            test.check(motionRuns.length===4,"four protected animation cases");
                            test.check(motionRuns[0].preview===false && motionRuns[1].preview===true && motionRuns[2].preview===false && motionRuns[3].preview===true,"both preview states on each monitor");
                            for(var run of motionRuns) {
                                test.check(run.frames.length>8,"animation produced frames");
                                var initial=run.frames[0];
                                test.check(run.frames.some(function(f){return f.width!==initial.width;}),"card animates within viewport");
                                if(run.preview)test.check(run.frames.every(function(f){return Math.abs(f.gap-widget.windowPreview.bridgeWidth)<.1;}),"preview remains attached on every frame");
                                test.check(run.frames.every(function(f){return f.shared;}),"preview and protected card must share one render surface");
                                test.check(run.frames.every(function(f){return f.surfaceWidth===initial.surfaceWidth && f.surfaceHeight===initial.surfaceHeight;}),"animation must not resize the native render surface");
                            }
                        }
                        console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;}
                    test.action(test.tasks[test.taskIndex++]);break;
                }
            }catch(e){console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+" task "+(test.taskIndex-1)+": "+e);stop();Qt.quit();}
        }
    }
}
