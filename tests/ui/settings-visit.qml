import QtQuick
import QtQuick.Window
import Quickshell
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property int waits: 0
    property real progress: 0
    property int frame: 0
    readonly property var logo: find(panel,"settingsOmarchyLogo")
    readonly property var pixel: find(logo,"pixelPanelLogo")
    readonly property var gif: find(logo,"customPanelLogo")
    function check(ok,text) { if(!ok) throw new Error(text); }
    function wait(ok,text) { if(ok){waits=0;return false;}check(++waits<40,text);step--;return true; }
    function find(item,name) {
        if(!item)return null;
        if(item.objectName===name)return item;
        for(var child of item.children || []) {var found=find(child,name);if(found)return found;}
        return null;
    }
    FakeHost { id:host; settings:({settingsLogoImage:"builtin:omarchy-pixel",settingsLogoLoop:false,settingsLogoCooldown:0}) }
    Window {
        visible:true;width:540;height:780
        Plugin.PanelContent { id:panel; x:20;y:20;width:500;height:740;hostWidget:host }
    }
    Timer {
        interval:100;running:true;repeat:true
        onTriggered: {
            try {
                switch(test.step++) {
                case 0: panel.begin();panel.showSettings();break;
                case 1:
                    if(test.wait(test.pixel.progress>0.15,"Settings starts the pixel sweep"))break;
                    panel.mode="pictures";test.progress=test.pixel.progress;break;
                case 2:
                    test.check(!test.pixel.animating && test.pixel.progress===test.progress,"submenu pauses rather than rewinds pixel sweep");
                    panel.back();break;
                case 3:
                    test.check(test.pixel.progress>=test.progress && test.pixel.animating,"return resumes the same sweep");break;
                case 4:
                    if(test.wait(test.pixel.progress===1 && !test.pixel.animating,"play-once reaches its last frame"))break;
                    panel.mode="pictures";break;
                case 5: panel.back();break;
                case 6:
                    test.check(test.pixel.progress===1 && !test.pixel.animating,"completed sweep does not replay on submenu return");
                    panel.back();panel.showSettings();break;
                case 7:
                    test.check(test.pixel.animating && test.pixel.progress<0.2,"new Settings visit starts a fresh animation");
                    host.persistSettings({settingsLogoImage:String(Qt.resolvedUrl("animated-logo.gif")),settingsLogoLoop:true,settingsLogoLoopDelay:0.5});break;
                case 8:
                    if(test.wait(test.gif.waitingForLoop,"GIF enters delay"))break;
                    panel.mode="pictures";test.frame=test.gif.currentFrame;test.waits=0;break;
                case 9:
                    test.check(!test.gif.animating && test.gif.currentFrame===test.frame,"hidden GIF keeps its frame");
                    if(++test.waits<8){test.step--;break;}
                    panel.back();break;
                case 10:
                    test.check(test.gif.waitingForLoop && test.gif.currentFrame===test.frame,"return preserves remaining loop delay instead of replaying");break;
                case 11:
                    if(test.wait(test.gif.animating,"paused GIF resumes after its remaining delay"))break;
                    host.persistSettings({settingsLogoLoop:false});break;
                case 12:
                    if(test.wait(test.gif.finished,"GIF plays once"))break;
                    panel.mode="pictures";break;
                case 13: panel.back();break;
                case 14:
                    test.check(test.gif.finished && !test.gif.animating,"completed GIF survives submenu return");
                    host.persistSettings({settingsLogoCooldown:60});panel.back();panel.showSettings();break;
                case 15:
                    test.check(!test.logo.playbackGranted,"new visit honors cooldown");
                    panel.mode="pictures";break;
                case 16: panel.back();break;
                case 17:
                    test.check(!test.logo.playbackGranted,"submenu return cannot bypass a denied cooldown");
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            }catch(error){console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error);stop();Qt.quit();}
        }
    }
}
