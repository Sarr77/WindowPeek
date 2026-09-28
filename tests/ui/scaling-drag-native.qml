import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "HostBar" as Host
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

// Bounded real Wayland drag in the private compositor, with fictional content.
ShellRoot {
    id:test
    property int step:0
    property int waits:0
    property int samples:0
    property bool returning:false
    readonly property bool increasing:(scale <= 1) !== returning
    property real previous:0
    property real startValue:0
    property real trackWidth:0
    property point origin
    readonly property var widget:hostBar.moduleWidgets("sarr.windowpeek")[0] || null
    readonly property var panel:find(widget,"windowPeekController")
    readonly property var body:panel ? panel.body : null
    readonly property var editor:find(body,"scalingEditor")
    readonly property var slider:find(find(body,"panelScaleControl"),"scaleSlider")
    readonly property real scale:Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function find(item,name) {
        if(!item)return null;if(item.objectName===name)return item;
        for(var child of item.children || []) {var found=find(child,name);if(found)return found;}return null;
    }
    function check(ok,text) {if(!ok)throw new Error(text);}
    function wait(ok,text) {if(ok){waits=0;return false;}check(++waits<35,text);step--;return true;}
    function point(x,y) {pointer.pending=true;pointer.write("move "+Math.round(x)+" "+Math.round(y)+" 1920 1080\n");}
    function command(value) {pointer.pending=true;pointer.write(value+"\n");}
    FakeHost {
        id:host;bar:test.widget ? test.widget.bar : null
        windowPreview:thumbnail
        settings:({hintsMode:"off",windowPreviews:false,popupAnimations:false})
        Component.onCompleted:savedAppearance=Appearance.normalize({uiScale:test.scale})
    }
    Plugin.WindowThumbnail {id:thumbnail;hostWidget:host}
    QtObject {
        id:shell;property string omarchyPath:"/usr/share/omarchy";property string themeName:"fixture"
        property var config:({bar:{position:"top",transparent:false,layout:{left:[{id:"sarr.windowpeek",autoUpdates:false,windowPreviews:false,openOnHover:false,uiScale:test.scale}],center:[],right:[]}}})
        function getResolvedSettings(id,entry){return entry;}function panelForModule(id){return test.panel;}
        function updateEntryInline(id,settings){} function pluginApiForId(id){return shell;}
    }
    Component {id:widgetFactory;Plugin.Widget {}}
    QtObject {
        id:registry;property var widgets:({"sarr.windowpeek":{component:widgetFactory}});property int revision:0
        function metadataFor(id){return {firstParty:false};}
    }
    Host.Bar {id:hostBar;shell:shell;barConfig:shell.config.bar;barWidgetRegistry:registry;omarchyPath:"/usr/share/omarchy"}
    Window {visible:true;width:900;height:700;title:"Scale drag fixture";color:"#24343c"}
    Process {
        id:pointer;command:[Quickshell.env("WINDOWPEEK_TEST_POINTER_FRAME"),"--listen"];running:true;stdinEnabled:true
        property bool ready:false;property bool pending:false
        stdout:SplitParser{onRead:function(line){if(line==="ready")pointer.ready=true;if(line==="clicked" || line==="framed")pointer.pending=false;}}
    }
    Process {
        id:keyboard;command:[Quickshell.env("WINDOWPEEK_TEST_KEYBOARD"),"None"];running:true;stdinEnabled:true
        property bool ready:false
        stdout:SplitParser{onRead:function(line){if(line==="pressed")keyboard.ready=true;}}
    }
    Timer {
        interval:100;running:true;repeat:true
        onTriggered: {
            if(pointer.pending)return;
            try {
                switch(test.step++) {
                case 0:if(test.wait(pointer.ready && keyboard.ready && test.widget && test.widget.settingsReady,"pointer/widget ready"))break;test.widget.open();break;
                case 1:test.panel.hostWidget=host;test.panel.showSettings();break;
                case 2:find(test.body,"openScalingButton").clicked();break;
                case 3:
                    if(test.wait(test.slider && test.slider.visible,"scaling slider visible"))break;
                    test.body.ensureVisible(test.slider);
                    test.slider.forceActiveFocus(Qt.TabFocusReason);
                    break;
                case 4:
                    test.origin=test.slider.handle.mapToGlobal(test.slider.handle.width/2,test.slider.handle.height/2);
                    test.trackWidth=test.slider.width*test.scale;
                    test.startValue=test.slider.value;test.previous=test.startValue;
                    console.log("SLIDER_GEOMETRY",JSON.stringify({origin:test.origin,width:test.slider.width,height:test.slider.height,handle:[test.slider.handle.x,test.slider.handle.y,test.slider.handle.width,test.slider.handle.height],card:test.panel.surface.cardOrigin,scale:test.panel.uiScale,mode:test.body.mode}));
                    if(Quickshell.env("WINDOWPEEK_TEST_IMAGE")) test.body.grabToImage(function(r){r.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE"));});
                    test.point(test.origin.x,test.origin.y);break;
                case 5:test.command("press");break;
                case 6:
                    test.check(test.slider.pressed,"native press starts dragging: "+JSON.stringify({opened:test.panel.opened,mode:test.body.mode,value:test.slider.value,active:test.slider.activeFocus,origin:test.slider.handle.mapToGlobal(test.slider.handle.width/2,test.slider.handle.height/2)}));
                    test.samples+=test.returning ? -1 : 1;
                    test.point(test.origin.x+(test.scale>1 ? -1 : 1)*test.trackWidth*0.04*test.samples,test.origin.y);break;
                case 7:
                    test.check(test.increasing ? test.slider.value>=test.previous : test.slider.value<=test.previous,
                        "monotonic movement must not reverse scale: "+test.previous+" -> "+test.slider.value);
                    test.previous=test.slider.value;
                    var delta=test.slider.value-test.startValue;
                    test.check(test.samples<3 || (test.scale>1 ? delta<0 : delta>0),"movement changes scale");
                    test.check(Math.abs(panel.uiScale-test.slider.value/100)<0.001,"whole panel still scales live");
                    console.log("DRAG_SAMPLE",test.samples,test.slider.value);
                    test.point(test.origin.x+(test.scale>1 ? -1 : 1)*(test.trackWidth*0.04*test.samples+(test.returning ? -1 : 1)),test.origin.y);break;
                case 8:
                    test.check(test.increasing ? test.slider.value>=test.previous : test.slider.value<=test.previous,
                        "one-pixel continuation must not reverse scale after layout: "+test.previous+" -> "+test.slider.value);
                    if(!test.returning && test.samples===10)test.returning=true;
                    if(test.samples>0)test.step=6;else test.command("release");break;
                case 9:
                    test.check(!test.slider.pressed,"release ends drag");
                    test.check(Math.abs(panel.uiScale-host.uiScale)<0.001,"release applies final scale to the editor");
                    test.check(host.savedAppearance.uiScale===test.scale,"live preview remains unsaved");
                    test.check(test.slider.value===test.startValue,"returning the pointer restores the starting value");
                    test.previous=test.slider.value;test.slider.forceActiveFocus(Qt.TabFocusReason);
                    keyboard.write("key Left\n");break;
                case 10:
                    test.check(test.slider.value===Math.max(80,test.previous-5),"keyboard still changes the native slider after dragging");
                    test.editor.cancel();
                    test.check(host.uiScale===test.scale,"Cancel restores original scale");
                    panel.close();console.log("WINDOWPEEK_TEST_PASS scaling-drag-native",test.scale);Qt.quit();break;
                }
            }catch(error){test.command("release");console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error);stop();Qt.quit();}
        }
    }
}
