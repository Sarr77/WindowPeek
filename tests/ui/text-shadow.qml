import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property int waits: 0
    property real normalWidth: 0
    property real normalHeight: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property string directory: Quickshell.env("WINDOWPEEK_TEST_PROFILE")
    function check(ok,message) { if(!ok) throw new Error(message); }
    function find(item,name) {
        if(item.objectName===name) return item;
        for(var c of item.children || []) { var found=find(c,name); if(found) return found; }
        return null;
    }
    function waiting() {
        if(host.textShadowSampleKey===sampler.sampleKey) { waits=0; return false; }
        check(waits++<40,"wallpaper sample completes"); step--; return true;
    }
    FakeHost {
        id: host
        settings: ({panelStyle:"wallpaper",wallpaperTransparency:90,textShadowMode:"auto"})
        wallpaperSource: "file://"+test.directory+"/bright.ppm"
    }
    Plugin.TextShadowSampler {
        id: sampler; hostWidget: host; active: true
        screenSize: Qt.size(500,600); panelRect: Qt.rect(0,0,500,600)
    }
    Window {
        id: window; visible:true; width:520*test.scale; height:700*test.scale
        color:"#35a088"
        Rectangle { anchors.fill:parent; color:window.color }
        Column {
            id: content; property var hostWidget: host
            x:20*test.scale; y:20*test.scale; width:480
            spacing:12; scale:test.scale; transformOrigin:Item.TopLeft
            Plugin.ReadableText { id: light; text:"Typing in search was interrupted"; textColor:"#dcd7ba"; font.pixelSize:14 }
            Plugin.ReadableText { id: dark; text:"Dark text stays readable too"; textColor:"#111111"; font.pixelSize:14 }
            Rectangle {
                width:480; height:40; color:"#181820"
                readonly property color readabilityBackground: color
                Plugin.ReadableText { id: backed; anchors.centerIn:parent; text:"Text on an opaque control"; textColor:"#dcd7ba"; font.pixelSize:14 }
            }
            Plugin.LabelButton { id: button; label:"Review options" }
            Plugin.SettingsContent { id: settings; width:480; hostWidget:host }
        }
    }
    Timer {
        interval:100; running:true; repeat:true
        onTriggered: {
            try {
                var picker=test.find(settings,"textShadowPicker");
                switch(test.step++) {
                case 0:
                    Color.shellValues={}; Color.background="#181820"; Color.foreground="#dcd7ba";
                    test.find(settings,"settingsPersonalizationSection").expanded=true;
                    break;
                case 1:
                    if(test.waiting()) break;
                    test.check(host.textShadowSamples.length===64,"actual local image sampled");
                    test.check(light.shadowActive && !dark.shadowActive && !backed.shadowActive,"per-text contrast and opaque backing respected");
                    picker.changed("off"); break;
                case 2:
                    test.check(host.textShadowMode==="off" && !light.shadowActive,"UI manual Off overrides Auto");
                    test.normalWidth=light.implicitWidth; test.normalHeight=light.implicitHeight;
                    picker.changed("on"); break;
                case 3:
                    test.check(light.shadowActive && dark.shadowActive && backed.shadowActive,"UI manual On reaches all text");
                    test.check(button.nativeLabels.some(function(t){return t.visible;}) && button.nativeLabels.every(function(t){return t.style===(t.visible ? Text.Raised : Text.Normal);}), "visible native button labels get a halo");
                    test.check(light.implicitWidth===test.normalWidth && light.implicitHeight===test.normalHeight,"halo preserves layout dimensions");
                    if(Quickshell.env("WINDOWPEEK_TEST_IMAGE")) window.contentItem.grabToImage(function(r){r.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE"));});
                    break;
                case 4:
                    button.visible=false;
                    picker.changed("auto"); host.wallpaperSource="file://"+test.directory+"/dark.ppm"; break;
                case 5:
                    if(test.waiting()) break;
                    test.check(!light.shadowActive && dark.shadowActive,"Auto updates after wallpaper change");
                    test.check(sampler.sampleOrder.length===2,"both wallpaper samples are cached");
                    host.wallpaperSource="file://"+test.directory+"/bright.ppm";
                    test.check(host.textShadowSampleKey===sampler.sampleKey,"return to cached crop needs no image process");
                    button.visible=true;
                    host.persistSettings({panelStyle:"glass",glassTransparency:90}); break;
                case 6:
                    test.check(light.shadowActive && dark.shadowActive,"glass considers changing content behind panel");
                    test.check(button.nativeLabels.filter(function(t){return t.visible;}).every(function(t){return t.style===Text.Raised;}),"newly visible labels use the current readability context");
                    host.persistSettings({panelStyle:"solid"}); break;
                case 7:
                    test.check(!light.shadowActive && !dark.shadowActive,"Auto leaves solid panel alone");
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit(); break;
                }
            } catch(e) { console.error("WINDOWPEEK_TEST_FAIL: "+e); stop(); Qt.quit(); }
        }
    }
}
