import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "HostBar" as Host
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

// Real Wayland pointer/keyboard events against the production layer surface.
// Private compositor only; never run on the user's desktop.
ShellRoot {
    id:test
    property int step:0
    property int waits:0
    readonly property bool gestures:(Quickshell.env("WP_CASE") || "").indexOf("gestures") >= 0
    readonly property bool lowZoom:(Quickshell.env("WP_CASE") || "").indexOf("low") >= 0
    property int handleIndex:0
    property int centerIndex:0
    property point gestureOrigin
    property rect gestureBefore
    property rect shrunken
    readonly property var handles:[
        {name:"logoScaleHandle",x:-1,y:-1}, {name:"logoScaleTopRightHandle",x:1,y:-1},
        {name:"logoScaleBottomLeftHandle",x:-1,y:1}, {name:"logoScaleBottomRightHandle",x:1,y:1},
        {name:"logoLeftHandle",x:-1,y:0}, {name:"logoWidthHandle",x:1,y:0},
        {name:"logoTopHandle",x:0,y:-1}, {name:"logoHeightHandle",x:0,y:1}
    ]
    readonly property var centers:["logoLeftHandle","logoWidthHandle","logoTopHandle","logoHeightHandle","logoMoveHandle"]
    function layoutForGesture() {
        var placement=find(body,"logoPlacementBounds").parent;
        return lowZoom ? {zoom:25,width:(placement.width-2*placement.edgeMargin)*10000/(placement.baselineWidth*25),height:104.8,x:0,y:0}
            : {zoom:38.077946,width:315.269513,height:182.05325,x:0,y:0};
    }
    function currentBounds() {
        var r=find(body,"logoPlacementBounds");return Qt.rect(r.x,r.y,r.width,r.height);
    }
    function command(value) {pointer.pending=true;pointer.write(value+"\n");}
    function moveGesture(amount) {
        var h=handles[handleIndex];point(gestureOrigin.x+h.x*amount*scale,gestureOrigin.y+h.y*amount*scale);
    }
    function beginTarget(name) {
        var item=find(body,name);gestureOrigin=item.mapToGlobal(item.width/2,item.height/2);
        point(gestureOrigin.x,gestureOrigin.y);
    }
    function testGestures() {
        var h=handles[handleIndex], r=find(body,"logoPlacementBounds"), placement=r.parent;
        switch(step++) {
        case 100:host.persistSettings({settingsLogoLayout:layoutForGesture()});placement.centerArtwork();break;
        case 101:gestureBefore=currentBounds();beginTarget(h.name);break;
        case 102:command("press");break;
        case 103:check(find(body,h.name).pressed,"real press reaches "+h.name);moveGesture(-12);break;
        case 104:
            shrunken=currentBounds();
            check(h.x ? shrunken.width<gestureBefore.width-1 : Math.abs(shrunken.width-gestureBefore.width)<0.1,"inward width responds: "+h.name);
            check(h.y ? shrunken.height<gestureBefore.height-1 : Math.abs(shrunken.height-gestureBefore.height)<0.1,"inward height responds: "+h.name);
            if(h.x && h.y)check(Math.abs(shrunken.width/shrunken.height-gestureBefore.width/gestureBefore.height)<0.001,"corner retains proportions: "+h.name);
            command("release");break;
        case 105:
            check(Math.abs(currentBounds().width-shrunken.width)<0.1 && Math.abs(currentBounds().height-shrunken.height)<0.1,"drag persists: "+h.name);
            beginTarget(h.name);break;
        case 106:command("press");break;
        case 107:check(find(body,h.name).pressed,"second press reaches "+h.name+" "+JSON.stringify({ctrl:body.logoControlHeld,key:keys.running,point:gestureOrigin,bounds:currentBounds(),active:body.Window.active,editing:placement.editing,handleSize:[find(body,h.name).width,find(body,h.name).height],parents:[find(body,h.name).parent.x,find(body,h.name).parent.y]}));moveGesture(12);break;
        case 108:
            var grown=currentBounds();
            check(h.x ? grown.width>shrunken.width+1 : Math.abs(grown.width-shrunken.width)<0.1,"outward width responds: "+h.name);
            check(h.y ? grown.height>shrunken.height+1 : Math.abs(grown.height-shrunken.height)<0.1,"outward height responds: "+h.name);
            check(grown.x>=placement.edgeMargin-0.1 && grown.y>=placement.edgeMargin-0.1
                && grown.x+grown.width<=placement.width-placement.edgeMargin+0.1
                && grown.y+grown.height<=placement.height-placement.edgeMargin+0.1,"gesture stays inside viewport: "+h.name);
            command("release");break;
        case 109:
            console.log("GESTURE_PASS",h.name);
            step=++handleIndex<handles.length ? 100 : 200;break;
        case 200:
            host.persistSettings({settingsLogoLayout:{zoom:30,width:300,height:110,x:8,y:-8}});break;
        case 201:gestureBefore=currentBounds();beginTarget(centers[centerIndex]);break;
        case 202:dbl();break;
        case 203:
            var after=currentBounds(), horizontal=centerIndex<2 || centerIndex===4, vertical=centerIndex>=2;
            check(horizontal ? Math.abs(after.x+after.width/2-placement.width/2)<0.1 : Math.abs(after.x-gestureBefore.x)<0.1,"horizontal centering: "+centers[centerIndex]);
            check(vertical ? Math.abs(after.y+after.height/2-placement.height/2)<0.1 : Math.abs(after.y-gestureBefore.y)<0.1,"vertical centering: "+centers[centerIndex]);
            check(Math.abs(after.width-gestureBefore.width)<0.1 && Math.abs(after.height-gestureBefore.height)<0.1,"centering keeps size: "+centers[centerIndex]);
            check(body.mode==="settings" && body.logoControlHeld,"centering keeps Settings and Ctrl");
            console.log("CENTER_PASS",centers[centerIndex]);
            step=++centerIndex<centers.length ? 200 : 210;break;
        case 210:keys.write("\n");break;
        case 211:check(!body.logoControlHeld,"release ends edit mode");panel.close();console.log("WINDOWPEEK_TEST_PASS logo-controls-native gestures",scale);Qt.quit();break;
        }
    }
    readonly property bool protectedMode:(Quickshell.env("WP_CASE") || "").indexOf("protected") >= 0
    readonly property real scale:Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var widget:hostBar.moduleWidgets("sarr.windowpeek")[0] || null
    readonly property var panel:find(widget,"windowPeekController")
    readonly property var body:panel ? panel.body : null
    function find(item,name) {
        if(!item)return null;if(item.objectName===name)return item;
        for(var child of item.children||[]){var found=find(child,name);if(found)return found;}return null;
    }
    function check(ok,message) {if(!ok)throw new Error(message);}
    function wait(ok,message) {if(ok){waits=0;return false;}check(++waits<20,message);step--;return true;}
    function point(x,y) {pointer.pending=true;pointer.write("move "+Math.round(x)+" "+Math.round(y)+" 1920 1080\n");}
    function target(name) {var item=find(body,name);check(item && item.visible,"target visible: "+name);var p=item.mapToGlobal(item.width/2,item.height/2);point(p.x,p.y);}
    function dbl() {pointer.pending=true;pointer.write("double\n");}
    FakeHost {
        id:host;bar:test.widget ? test.widget.bar : null
        readonly property var focusRecovery:test.protectedMode && test.widget ? test.widget.focusRecovery : null
        windowPreview:thumbnail
        settings:({keepSearchFocus:test.protectedMode,hintsMode:"off",doubleClickExpand:true,windowPreviews:false,settingsLogoImage:test.gestures ? Qt.resolvedUrl("WindowPeek/tests/artwork/reveal.svg").toString() : "builtin:omarchy-pixel",settingsLogoLayout:{zoom:75,width:80,height:80,x:-14,y:-8}})
        Component.onCompleted:savedAppearance=Appearance.normalize({uiScale:test.scale})
    }
    Plugin.WindowThumbnail {id:thumbnail;hostWidget:host}
    QtObject {
        id:shell
        property var config:({bar:{position:"top",transparent:false,layout:{left:[{id:"sarr.windowpeek",autoUpdates:false,windowPreviews:false,openOnHover:false,uiScale:test.scale}],center:[],right:[]}}})
        function updateEntryInline(id,entry){return true;}
        function pluginShellForId(id){return shell;}
    }
    Component {id:widgetFactory;Plugin.Widget {}}
    QtObject {
        id:registry;property var widgets:({"sarr.windowpeek":{component:widgetFactory}});property int revision:0
        function metadataFor(id){return {firstParty:false};}
    }
    Host.Bar {id:hostBar;shell:shell;barConfig:shell.config.bar;barWidgetRegistry:registry;omarchyPath:"/usr/share/omarchy"}
    Window {id:other;visible:true;width:900;height:700;title:"Artwork input fixture";color:"#24343c"}
    Process {
        id:pointer;command:[Quickshell.env("WINDOWPEEK_TEST_POINTER_FRAME"),"--listen"];running:true;stdinEnabled:true
        property bool ready:false;property bool pending:false
        stdout:SplitParser {onRead:function(line){if(line==="ready")pointer.ready=true;if(line==="clicked" || line==="framed")pointer.pending=false;}}
    }
    Process {
        id:keys;command:[Quickshell.env("WINDOWPEEK_TEST_KEYBOARD"),"Control_L"];stdinEnabled:true
        property bool ready:false
        stdout:SplitParser {onRead:function(line){if(line==="pressed")keys.ready=true;}}
    }
    Timer {
        interval:test.gestures ? 60 : 200;running:true;repeat:true
        onTriggered: {
            if(pointer.pending)return;
            try {
                if(test.step>=100) {test.testGestures();return;}
                switch(test.step++) {
                case 0:if(test.wait(test.widget && test.widget.settingsReady && pointer.ready,"widget and pointer ready"))break;test.widget.open();break;
                case 1:test.panel.hostWidget=host;test.panel.showSettings();break;
                case 2:
                    if(test.wait(!test.protectedMode || test.panel.surface.usingNative,"protection surface ready"))break;
                    test.target("settingsOmarchyLogo");break;
                case 3:keys.running=true;break;
                case 4:
                    if(test.wait(keys.ready && test.body.logoControlHeld,"Ctrl displays handles"))break;
                    if(test.gestures)test.step=100;else test.target("logoWidthHandle");break;
                case 5:test.dbl();break;
                case 6:
                    test.check(host.settings.settingsLogoLayout.x===0,"real double-click on right handle centres horizontally: "+JSON.stringify(host.settings.settingsLogoLayout));
                    test.target("logoHeightHandle");break;
                case 7:test.dbl();break;
                case 8:
                    var rect=test.find(test.body,"logoPlacementBounds");
                    test.check(Math.abs(rect.y+rect.height/2-rect.parent.height/2)<0.1,"real double-click on bottom handle centres vertically");
                    test.point(1500,800);break;
                case 9:
                    test.check(test.body.logoControlHeld && test.find(test.body,"logoMoveHandle").visible,"Ctrl controls survive pointer exit");
                    test.check(test.body.Window.active,"artwork editing keeps keyboard focus outside the panel");
                    host.persistSettings({settingsLogoLayout:{zoom:75,width:80,height:80,x:-10,y:-5}});
                    test.target("logoLeftHandle");break;
                case 10:
                    test.check(test.body.logoControlHeld,"controls remain available on return");test.dbl();break;
                case 11:
                    test.check(host.settings.settingsLogoLayout.x===0,"real double-click on left handle centres horizontally");
                    test.target("logoTopHandle");break;
                case 12:test.dbl();break;
                case 13:
                    var rect=test.find(test.body,"logoPlacementBounds");
                    test.check(Math.abs(rect.y+rect.height/2-rect.parent.height/2)<0.1,"real double-click on top handle centres vertically");break;
                case 14:
                    host.persistSettings({settingsLogoLayout:{zoom:75,width:80,height:65,x:-10,y:-5}});
                    test.target("logoMoveHandle");break;
                case 15:test.dbl();break;
                case 16:
                    var rect=test.find(test.body,"logoPlacementBounds"), saved=host.settings.settingsLogoLayout;
                    test.check(Math.abs(rect.x+rect.width/2-rect.parent.width/2)<0.1
                        && Math.abs(rect.y+rect.height/2-rect.parent.height/2)<0.1,"artwork double-click centres both axes");
                    test.check(saved.zoom===75 && saved.width===80 && saved.height===65,"artwork centering preserves custom proportions and size");
                    test.check(test.body.mode==="settings","artwork double-click does not toggle the panel");break;
                case 17:test.point(1500,800);break;
                case 18:keys.write("\n");break;
                case 19:
                    if(test.wait(!test.body.logoControlHeld,"release outside hides controls"))break;
                    test.point(1510,800);break;
                case 20:
                    test.check(!test.body.Window.active,"pointer can focus another app after Ctrl release");
                    test.panel.close();break;
                case 21:
                    if(test.wait(!keys.running,"first Ctrl helper exits"))break;
                    keys.ready=false;keys.command=[Quickshell.env("WINDOWPEEK_TEST_KEYBOARD"),"Control_R"];keys.running=true;break;
                case 22:
                    if(test.wait(keys.ready,"right Ctrl held before opening"))break;
                    test.widget.open();break;
                case 23:test.panel.showSettings();break;
                case 24:
                    if(test.wait(test.body.logoControlHeld && test.body.Window.active,"preheld right Ctrl enables editing outside panel"))break;
                    test.panel.close();break;
                case 25:
                    test.check(!test.body.logoControlHeld,"closing while Ctrl held clears artwork mode");
                    keys.write("\n");break;
                case 26:
                    console.log("WINDOWPEEK_TEST_PASS logo-controls-native",test.scale);Qt.quit();break;
                }
            }catch(error){console.error("WINDOWPEEK_TEST_FAIL",test.step,error);keys.write("\n");Qt.exit(1);}
        }
    }
}
