import QtQuick
import QtQuick.Window
import Quickshell
import "WindowPeek" as Plugin
import "WindowPeek/LogoCatalog.js" as Catalog

ShellRoot {
    id: test
    property int step: -1
    property int waits: 0
    property int frames: 0
    property int priorFrame: -1
    property real pausedProgress: 0
    property int effectIndex: 1
    property int phaseIndex: 0
    property bool grabbing: false
    readonly property var opening: find(art,"logoReveal")
    readonly property var gif: find(art,"customPanelLogo")
    readonly property var natural: find(art,"naturalLogoArt")
    function check(ok,text) { if(!ok) throw new Error(text); }
    function wait(ok,text) { if(ok){waits=0;return false;}check(++waits<50,text);step--;return true; }
    function find(item,name) {
        if(!item)return null;if(item.objectName===name)return item;
        for(var child of item.children||[]){var found=find(child,name);if(found)return found;}return null;
    }
    Window {
        visible:true;width:420;height:280;color:"#181824"
        Plugin.LogoArt {
            id:art;x:30;y:30;width:360;height:202.5
            source:Qt.resolvedUrl("animated-logo.gif");themeColors:false
            reveal:"iris";playing:false;loopDelay:0
        }
    }
    Timer {
        interval:20;running:true;repeat:true
        onTriggered: if(test.gif && test.gif.currentFrame!==test.priorFrame) {test.priorFrame=test.gif.currentFrame;test.frames++;}
    }
    Timer {
        interval:120;running:true;repeat:true
        onTriggered: {
            if(test.grabbing)return;
            try {
                switch(test.step++) {
                case -1:
                    if(test.wait(art.status===Image.Ready,"GIF loaded"))break;
                    art.pendingPlayback=true;
                    test.check(test.natural.opacity===0,"pending opening conceals the loaded image before playback starts");
                    if(Quickshell.env("WINDOWPEEK_TEST_IMAGE")) {
                        test.grabbing=true;
                        art.grabToImage(function(result) {
                            if(!result.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE")+".pending.png")) {console.error("WINDOWPEEK_TEST_FAIL image save");Qt.exit(1);}
                            test.grabbing=false;
                        });
                    }
                    break;
                case 0: art.playing=true;art.pendingPlayback=false;break;
                case 1:
                    if(test.wait(test.opening.progress>0.1 && test.frames>=2,"GIF plays underneath the opening effect"))break;
                    art.suspended=true;test.pausedProgress=test.opening.progress;break;
                case 2:
                    test.check(test.opening.progress===test.pausedProgress && !test.opening.animating,"hidden effect pauses at its current frame");
                    art.suspended=false;break;
                case 3:
                    if(test.wait(test.opening.progress===1,"effect completes"))break;
                    test.check(!test.opening.active && !test.opening.animating && !test.natural.layer.enabled,"completed reveal releases capture and animation clock");
                    test.frames=0;break;
                case 4:
                    if(test.wait(test.frames>=2,"GIF continues after reveal completes"))break;
                    art.suspended=true;
                    art.source=Qt.resolvedUrl("WindowPeek/tests/artwork/reveal.svg");
                    if(art.status===Image.Loading || art.status===Image.Null)
                        test.check(test.natural.opacity===0,"async source loading never shows an unmasked placeholder");
                    break;
                case 5: if(test.wait(art.status===Image.Ready,"static artwork loaded"))break;break;
                case 6:
                    art.reveal=Catalog.reveals[test.effectIndex];
                    test.opening.progress=[0,0.5,1][test.phaseIndex];
                    break;
                case 7:
                    if(Quickshell.env("WINDOWPEEK_TEST_IMAGE")) {
                        test.grabbing=true;
                        var path=Quickshell.env("WINDOWPEEK_TEST_IMAGE")+"."+art.reveal+"."+test.phaseIndex+".png";
                        art.grabToImage(function(result) {
                            if(!result.saveToFile(path)) {console.error("WINDOWPEEK_TEST_FAIL image save");Qt.exit(1);}
                            test.grabbing=false;
                        });
                    }
                    break;
                case 8:
                    if(++test.phaseIndex<3){test.step=6;break;}
                    test.phaseIndex=0;
                    if(++test.effectIndex<Catalog.reveals.length){test.step=6;break;}
                    art.playing=false;art.suspended=false;break;
                case 9:
                    test.check(!test.opening.active && !test.opening.animating && test.opening.progress===1,"stopped playback leaves the full image visible");
                    art.reveal="none";art.pendingPlayback=true;
                    test.check(test.natural.opacity===1,"without an opening effect, pending playback never hides the image");
                    console.log("WINDOWPEEK_TEST_PASS logo-reveal",test.opening.supported?"GPU":"software fade fallback");Qt.quit();break;
                }
            } catch(error){console.error("WINDOWPEEK_TEST_FAIL",test.step,error);Qt.exit(1);}
        }
    }
}
