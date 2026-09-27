import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin

// Late wallpaper/worker replies must not repaint text already on screen.
ShellRoot {
    id: test
    property int step: 0
    property int waits: 0
    property int frames: 0
    property bool checking: false
    property bool failed: false
    property bool imagePending: false
    property bool imageSaved: false
    property var paints: ({})
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function sample() {
        if (!checking || failed) return;
        try {
            for (var item of [label, backed, field]) {
                var value = JSON.stringify([String(item.color), item.style, String(item.styleColor),
                    item.font.family, item.font.pixelSize, item.readablePlaceholderEnabled]);
                if (paints[item.objectName]) check(value === paints[item.objectName],
                    "visible text changed after first paint: " + item.objectName + " " + paints[item.objectName] + " -> " + value);
                else paints[item.objectName] = value;
            }
            frames++;
        } catch(e) { failed=true; console.error("WINDOWPEEK_TEST_FAIL: " + e); Qt.quit(); }
    }
    function begin() { paints={}; checking=true; sample(); }
    function settled() {
        if (host.textShadowSampleKey !== sampler.sampleKey || host.textReadability.busy
                || Object.keys(host.textReadability.pending).length) {
            check(++waits < 80, "wallpaper and worker settle"); step--; return false;
        }
        waits=0; sample(); return true;
    }
    QtObject { id:bar; property bool transparent:true }
    FakeHost {
        id:host; bar:bar
        settings:({panelStyle:"wallpaper",followBarStyle:true,wallpaperTransparency:70,textShadowMode:"auto"})
        wallpaperSource:"file://"+Quickshell.env("WINDOWPEEK_TEST_PROFILE")+"/dark.ppm"
    }
    Plugin.TextShadowSampler {
        id:sampler;hostWidget:host;active:host.textPresentationActive
        screenSize:Qt.size(500,600);panelRect:Qt.rect(0,0,500,600)
    }
    Window {
        visible:true;width:520*test.scale;height:200*test.scale;color:"#142328"
        Column {
            id:canvas
            property var hostWidget:host
            x:20;y:20;scale:test.scale;transformOrigin:Item.TopLeft;spacing:12
            Plugin.ReadableText { id:label;objectName:"label";text:"Windows 14";textColor:"#dcd7ba";font.pixelSize:14 }
            Plugin.ReadableText { id:backed;objectName:"backed";text:"Window details";textColor:"#b3dcd7ba";shadowBacking:"#101018";font.pixelSize:12 }
            Plugin.EditField { id:field;objectName:"field";width:460;placeholderText:"Search windows…" }
        }
    }
    Component.onCompleted: {
        Color.colorsFile.path=""; Color.shellFile.path=""; Color.userShellFile.path="";
        Color.shellValues={};Color.background="#1a1b26";Color.foreground="#dcd7ba"; }
    Timer { interval:16;running:true;repeat:true;onTriggered:test.sample() }
    Timer {
        interval:80;running:true;repeat:true
        onTriggered: {
            if(test.failed){stop();return;}
            try {
                switch(test.step++) {
                case 0:
                    host.textPresentationActive=true; test.begin();
                    test.check(!host.textShadowSamples.length,"first paint precedes slow sampling");
                    if(Quickshell.env("WINDOWPEEK_TEST_IMAGE"))canvas.grabToImage(function(r){r.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE")+".first.png");});break;
                case 1:
                    if(!test.settled())break;
                    test.check(test.frames>=8,"visible first-opening frames inspected");
                    if(Quickshell.env("WINDOWPEEK_TEST_IMAGE") && !test.imageSaved) {
                        if(!test.imagePending) {
                            test.imagePending=true;
                            canvas.grabToImage(function(r){
                                r.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE")+".settled.png");
                                test.imageSaved=true;
                            });
                        }
                        test.step--;break;
                    }
                    test.checking=false;host.textPresentationActive=false;break;
                case 2:
                    test.check(!label.shadowActive,"settled dark wallpaper permits original ink for next visit");
                    host.textPresentationActive=true;test.begin();break;
                case 3:
                    test.sample();test.checking=false;
                    bar.transparent=false;
                    test.check(!label.shadowActive,"opaque bar style is immediate");break;
                case 4:
                    bar.transparent=true;test.begin();break;
                case 5:
                    if(!test.settled())break;
                    test.checking=false;host.textPresentationActive=false;
                    host.wallpaperSource="file://"+Quickshell.env("WINDOWPEEK_TEST_PROFILE")+"/purple.ppm";
                    Color.foreground="#a9b1d6";break;
                case 6:
                    host.textPresentationActive=true;test.begin();break;
                case 7:
                    if(!test.settled())break;
                    // Different crop from expanding or showing a preview is
                    // analysis, not a request to redraw existing lettering.
                    sampler.panelRect=Qt.rect(0,0,420,500);break;
                case 8:
                    if(!test.settled())break;
                    test.checking=false;host.persistSettings({textShadowMode:"off"});
                    test.check(!label.shadowActive,"explicit Off applies immediately");
                    host.persistSettings({textShadowMode:"on"});
                    test.check(label.shadowActive,"explicit On applies immediately");
                    test.begin();break;
                case 9:
                    if(!test.settled())break;
                    test.checking=false;host.textPresentationActive=false;
                    console.info("WINDOWPEEK_TEST_PASS: stable first paint, warm reopen, transparency, new theme, crop changes, fields and explicit On/Off; frames="+test.frames);
                    stop();Qt.quit();break;
                }
            } catch(e) { test.failed=true;console.error("WINDOWPEEK_TEST_FAIL: "+e);stop();Qt.quit(); }
        }
    }
}
