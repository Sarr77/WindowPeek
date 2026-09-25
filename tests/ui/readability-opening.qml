import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin

// Exercise two independent cold panel owners, using the real deferred sampler.
ShellRoot {
    id: test
    property int step: 0
    property int waits: 0
    property int sampledFrames: 0
    property bool failed: false
    property bool checking: false
    property bool firstShown: false
    property bool secondShown: false
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function settled(host, sampler) {
        if (host.textShadowSampleKey !== sampler.sampleKey || host.textReadability.busy
                || Object.keys(host.textReadability.pending).length) {
            check(++waits < 60, "real wallpaper analysis finishes"); step--; return false;
        }
        waits=0; return true;
    }
    function frame() {
        if (!checking || failed) return;
        try {
            for (var label of [firstText, secondText]) {
                if (!label.visible) continue;
                check(label.color.a > .99, "cold open must not briefly restore dim text before wallpaper samples: " + String(label.color));
                if(Quickshell.env("WINDOWPEEK_TEST_IMAGE") && sampledFrames<25) {
                    let file=Quickshell.env("WINDOWPEEK_TEST_IMAGE")+"."+sampledFrames+".png";
                    label.grabToImage(function(r){r.saveToFile(file);});
                }
                sampledFrames++;
            }
        } catch(e) { failed=true;console.error("WINDOWPEEK_TEST_FAIL: "+e);Qt.quit(); }
    }
    FakeHost {
        id:first;settings:({panelStyle:"wallpaper",wallpaperTransparency:70,textShadowMode:"auto"})
        wallpaperSource:"file://"+Quickshell.env("WINDOWPEEK_TEST_PROFILE")+"/purple.ppm"
    }
    FakeHost {
        id:second;settings:({panelStyle:"wallpaper",wallpaperTransparency:70,textShadowMode:"auto"})
        wallpaperSource:first.wallpaperSource
    }
    Plugin.TextShadowSampler {
        id:firstSampler;hostWidget:first;active:test.firstShown
        screenSize:Qt.size(500,600);panelRect:Qt.rect(0,0,500,600)
    }
    Plugin.TextShadowSampler {
        id:secondSampler;hostWidget:second;active:test.secondShown
        screenSize:Qt.size(500,600);panelRect:Qt.rect(0,0,420,500)
    }
    Window {
        visible:true;width:480*test.scale;height:180*test.scale;color:"#63396c"
        Column {
            scale:test.scale;transformOrigin:Item.TopLeft;x:20;y:20;spacing:30
            Plugin.ReadableText {
                id:firstText;visible:test.firstShown;shadowHost:first
                text:"First monitor · window details";textColor:Qt.alpha(Color.popups.text,.7);font.pixelSize:14
            }
            Plugin.ReadableText {
                id:secondText;visible:test.secondShown;shadowHost:second
                text:"Second monitor · window details";textColor:Qt.alpha(Color.popups.text,.7);font.pixelSize:14
            }
        }
    }
    Component.onCompleted: { Color.shellValues={};Color.background="#1a1b26";Color.foreground="#a9b1d6"; }
    Timer { interval:30;running:true;repeat:true;onTriggered:test.frame() }
    Timer {
        interval:80;running:true;repeat:true
        onTriggered: {
            if(test.failed){stop();return;}
            try {
                switch(test.step++) {
                case 0:test.checking=true;test.firstShown=true;break;
                case 1:
                    if(!test.settled(first,firstSampler))break;
                    test.check(first.textShadowSamples.length===64,"first owner sampled wallpaper");
                    test.secondShown=true;break;
                case 2:
                    if(!test.settled(second,secondSampler))break;
                    test.check(second.textShadowSamples.length===64,"second owner samples independently");
                    test.firstShown=false;test.secondShown=false;
                    first.textReadability.idle.triggered();second.textReadability.idle.triggered();break;
                case 3:
                    test.check(!first.textReadability.worker.running && !second.textReadability.worker.running,"idle processes stopped");
                    test.firstShown=true;test.secondShown=true;break;
                case 4:
                    if(!test.settled(first,firstSampler) || !test.settled(second,secondSampler))break;
                    test.check(test.sampledFrames>=8,"cold and warm visible text samples were inspected");
                    test.checking=false;
                    first.wallpaperSource="file://"+Quickshell.env("WINDOWPEEK_TEST_PROFILE")+"/dark.ppm";break;
                case 5:
                    if(!test.settled(first,firstSampler) || !test.settled(second,secondSampler))break;
                    test.check(Math.abs(firstText.color.a-.7)<.01,"real dark wallpaper permits original text");
                    first.wallpaperSource="file://"+Quickshell.env("WINDOWPEEK_TEST_PROFILE")+"/purple.ppm";
                    test.checking=true;break;
                case 6:
                    if(!test.settled(first,firstSampler) || !test.settled(second,secondSampler))break;
                    test.check(firstText.color.a>.99 && secondText.color.a>.99,"old dark-wallpaper answer cannot dim new wallpaper");
                    test.checking=false;
                    first.persistSettings({textShadowMode:"off"});
                    test.check(Math.abs(firstText.color.a-.7)<.01,"explicit Off restores original alpha immediately");
                    console.info("WINDOWPEEK_TEST_PASS: cold owners, real delayed samples, warm reopen after worker shutdown, visible ink, wallpaper change, explicit Off");
                    stop();Qt.quit();break;
                }
            }catch(e){test.failed=true;console.error("WINDOWPEEK_TEST_FAIL: "+e);stop();Qt.quit();}
        }
    }
}
