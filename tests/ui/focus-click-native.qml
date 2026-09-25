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
    property int step: 0
    property int focusWaits: 0
    property string backgroundText: ""
    property int backgroundWheel: 0
    property var clients: []
    property var resizeSource: null
    property var wheelTarget: null
    property string handoffAddress: ""
    property double handoffStarted: 0
    property double handoffMs: -1
    function measureHandoff(client) {
        handoffAddress=client.address.replace(/^0x/,"");handoffStarted=Date.now();handoffMs=-1;
        var x=client.at[0]+client.size[0]*0.75,y=client.at[1]+client.size[1]*0.75;
        // Two motion frames resemble actual mouse travel and cross Hyprland's
        // movement threshold after an idle period; a lone warp cannot do that.
        move(x,y,"move "+Math.round(x+2)+" "+Math.round(y)+" 1920 1080");
    }
    property Connections focusTiming: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if(event.name==="activewindowv2" && test.handoffAddress
                && event.data.replace(/^0x/,"")===test.handoffAddress && test.handoffMs<0) {
                test.handoffMs=Date.now()-test.handoffStarted;
                console.log("BACKGROUND_HANDOFF_MS:"+test.handoffMs);
            }
        }
    }
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
                case 1: test.check(!!test.resizeSource && !!test.wheelTarget,"fictional source and receiver available");test.outside("click");break;
                case 2: test.over(widget,"click");break;
                case 3: keys.write("key A\n");break;
                case 4: test.focusWaits=0;test.outside("frame");break;
                case 5: break;
                case 6:
                    if(panel.surface.nativeActive && ++test.focusWaits<6){test.step--;break;}
                    test.check(!panel.surface.nativeActive && !panel.body.searchField.cursorVisible,"actual keyboard focus lost, caret hidden");
                    panel.surface.cardItem.grabToImage(function(image){if(Quickshell.env("WINDOWPEEK_TEST_IMAGE"))image.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE"));});
                    test.measureHandoff(test.clients[1]);test.step=100;break;
                case 100:
                    test.check(test.handoffMs>=0 && test.handoffMs<400,"background focus follows motion promptly after Search loses focus");
                    test.measureHandoff(test.clients[0]);break;
                case 101:
                    test.check(test.handoffMs>=0 && test.handoffMs<400,"returning to the previous window does not await another X11 resize burst");
                    test.handoffAddress="";
                    pointer.afterClickKey="B";test.over(panel.body.searchField,"click");test.step=7;break;
                case 7:
                    test.check(panel.surface.nativeActive && panel.body.searchField.cursorVisible
                        && panel.body.searchField.text==="ab" && test.backgroundText==="",
                        "field click returns real keyboard focus before immediate typing: "+test.state());
                    test.focusWaits=0;test.outside("frame");break;
                case 8: break;
                case 9:
                    if(panel.surface.nativeActive && ++test.focusWaits<6){test.step--;break;}
                    test.check(!panel.surface.nativeActive && !panel.body.searchField.cursorVisible,
                        "a second loss does not trigger automatic focus acquisition");
                    var p=panel.surface.cardItem.mapToGlobal(6*test.scale,panel.surface.cardItem.height/2);
                    pointer.afterClickKey="C";test.move(p.x,p.y,"click");break;
                case 10:
                    test.check(panel.surface.nativeActive && panel.body.searchField.text==="abc" && test.backgroundText==="",
                        "blank panel click returns keyboard focus and preserves the query: "+test.state());
                    test.check(!widget.keepSearchFocus && !widget.focusRecovery.granted && !panel.surface.protectionRequested,
                        "click does not silently enable persistent or temporary protection");
                    test.focusWaits=0;test.outside("frame");break;
                case 11: break;
                case 12:
                    if(panel.surface.nativeActive && ++test.focusWaits<6){test.step--;break;}
                    test.check(!panel.surface.nativeActive,"focus remains lost until another deliberate press");
                    pointer.write("scroll\n");break;
                case 13:
                    test.check(Math.abs(test.backgroundWheel)===240,"ordinary outside wheel still reaches the application");
                    pointer.afterClickKey="D";test.over(panel.body.searchField,"click");break;
                case 14:
                    test.check(panel.surface.nativeActive && panel.body.searchField.text==="abcd" && test.backgroundText==="",
                        "field remains recoverable after outside scrolling");
                    keys.write("key Esc\n");break;
                case 15:
                    test.check(!widget.opened,"Escape still dismisses the recovered search");
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            }catch(e){console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+e);stop();Qt.quit();}
        }
    }
}
