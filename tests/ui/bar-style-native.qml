import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "HostBar" as Host
import "WindowPeek" as Plugin

ShellRoot {
    id:test
    property int step:0
    property string savedBefore:""
    readonly property real scale:Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var widget:hostBar.moduleWidgets("sarr.windowpeek")[0] || null
    readonly property var panel:find(widget,"windowPeekController")
    function check(ok,message){if(!ok)throw new Error(message);}
    function find(item,name){
        if(!item)return null;
        if(item.objectName===name)return item;
        for(var child of item.children || []){var result=find(child,name);if(result)return result;}
        return null;
    }
    function background(value){var next=JSON.parse(JSON.stringify(shell.config));next.bar.background=value;shell.config=next;}
    function reveal(state){panel.body.ensureVisible(test.find(panel.body,"barStylePicker-"+state));}
    function visibleChoice(state){
        var item=test.find(panel.body,"barStylePicker-"+state),view=test.find(panel.body,"editorScroll");
        var point=item.mapToItem(view,0,0);
        test.check(point.y>=-1 && point.y+item.height<=view.height+1,"scroll reveals "+state+" choice");
    }
    QtObject {
        id:shell
        property var config:({bar:{position:"top",background:"opaque",layout:{left:[{
            id:"sarr.windowpeek",autoUpdates:false,checkUpdates:false,windowPreviews:false,
            panelStyle:"wallpaper",followBarStyle:true,glassTransparency:8,wallpaperTransparency:70,
            hintsMode:"off",uiScale:test.scale}],center:[],right:[]}}})
        readonly property var barConfig:config.bar
        function updateEntryInline(id,entry){return true;}
        function pluginShellForId(id){return shell;}
    }
    Component {id:factory;Plugin.Widget{}}
    QtObject {
        id:registry
        property var widgets:({"sarr.windowpeek":{component:factory}})
        property int revision:0
        function metadataFor(id){return {firstParty:false};}
    }
    Host.Bar {id:hostBar;shell:shell;barConfig:shell.config.bar;barWidgetRegistry:registry;omarchyPath:"/usr/share/omarchy"}
    Process {id:capture}
    Timer {id:finish;interval:300;onTriggered:Qt.quit()}
    Timer {
        interval:450;running:true;repeat:true
        onTriggered:{
            if(!widget || !widget.settingsReady || !panel || widget.runtime.preferences.saving || capture.running)return;
            try {
                switch(test.step++){
                case 0:
                    test.savedBefore=JSON.stringify(widget.runtime.preferences.values);
                    widget.open(false,true);break;
                case 1:
                    test.check(panel.mapped && widget.panelStyle==="solid" && panel.surface.cardItem.color.a===1,"opaque bar renders Solid");
                    test.background("glassy");break;
                case 2:
                    test.check(widget.panelStyle==="wallpaper" && panel.surface.cardItem.color.a===1
                        && !panel.surface.BackgroundEffect.blurRegion,"Glassy bar defaults to Wallpaper");
                    test.background("none");break;
                case 3:
                    test.check(widget.panelStyle==="wallpaper" && panel.surface.cardItem.color.a===1
                        && !panel.surface.BackgroundEffect.blurRegion,"clear bar restores Wallpaper");
                    test.check(JSON.stringify(widget.runtime.preferences.values)===test.savedBefore,"bar cycle did not save or replace preferences");
                    widget.persistSettings({barStyleRules:{opaque:{style:"glass",glassTransparency:42},glassy:{style:"glass",glassTransparency:65},none:{style:"solid"}}});
                    test.background("glassy");test.step=31;break;
                case 31:
                    test.check(widget.panelStyle==="glass" && Math.abs(panel.surface.cardItem.color.a-.35)<.005
                        && Boolean(panel.surface.BackgroundEffect.blurRegion),"explicit Glass choice retains 65% transparency and blur");
                    test.background("opaque");test.step=4;break;
                case 4:
                    test.check(widget.panelStyle==="glass" && Math.abs(panel.surface.cardItem.color.a-.58)<.005,"custom rule controls the rendered card");
                    test.check(widget.runtime.preferences.values.glassTransparency===8
                        && widget.runtime.preferences.values.wallpaperTransparency===70,"base choices survive independent rules");
                    widget.openSettings();break;
                case 5:
                    test.find(panel.body,"settingsPersonalizationSection").expanded=true;
                    break;
                case 6:
                    test.reveal("opaque");break;
                case 7:
                    test.visibleChoice("opaque");test.reveal("glassy");break;
                case 8:
                    test.visibleChoice("glassy");test.reveal("none");break;
                case 9:
                    test.visibleChoice("none");
                    var prefix=Quickshell.env("WINDOWPEEK_TEST_IMAGE");
                    if(prefix){
                        var s=panel.surface.screen;
                        var card=panel.surface.cardItem;
                        capture.command=["grim","-s","1","-g",s.x+","+s.y+" "+Math.min(s.width,Math.ceil(card.x+card.width+12))+"x"+Math.min(s.height,Math.ceil(card.y+card.height+12)),prefix];capture.running=true;
                    }
                    break;
                case 10:
                    test.check(test.find(panel.body,"barStyleRulesEditor").visible,"configuration is available in real Settings");
                    console.info("WINDOWPEEK_TEST_PASS: real Bar cycles all styles, renders per-state alpha/blur, preserves settings and exposes controls");
                    widget.close();stop();finish.start();
                }
            }catch(error){console.error("WINDOWPEEK_TEST_FAIL: "+error);widget.close();stop();finish.start();}
        }
    }
}
