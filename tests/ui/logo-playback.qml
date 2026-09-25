import QtQuick
import QtQuick.Window
import Quickshell
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property int waits: 0
    property int gifCycles: 0
    property double gifEnd: 0
    property real gifGap: 0
    property double pixelEnd: 0
    property real pixelGap: 0
    property real previousProgress: 0
    property double hiddenAt: 0
    function check(ok, text) { if (!ok) throw new Error(text); }
    function wait(ok, text) { if(ok){waits=0;return false;}check(++waits<120,text);step--;return true; }
    Window {
        visible:true;width:420;height:180
        Plugin.LogoImage {
            id: gif; width:400;height:80
            source:Qt.resolvedUrl("animated-logo.gif");playing:true;loopDelay:0.3
            onWaitingForLoopChanged: if(waitingForLoop) test.gifEnd=Date.now()
            onCurrentFrameChanged: if(currentFrame===0 && playing) {
                if(test.gifEnd>0) {test.gifGap=Date.now()-test.gifEnd;test.gifEnd=0;}
                test.gifCycles++;
            }
        }
        Plugin.PixelLogo {
            id: pixel; y:100;width:300;height:65;playing:false;loopDelay:0.3
            onProgressChanged: {
                if(progress===1) test.pixelEnd=Date.now();
                if(progress<test.previousProgress && test.pixelEnd>0) {
                    test.pixelGap=Date.now()-test.pixelEnd;test.pixelEnd=0;
                }
                test.previousProgress=progress;
            }
        }
    }
    Timer {
        interval:50;running:true;repeat:true
        onTriggered: {
            try {
                switch(test.step++) {
                case 0:
                    if(test.wait(test.gifCycles>0,"GIF loops after its delay"))break;
                    test.check(test.gifGap>=280 && test.gifGap<1000,"fractional GIF pause is measured in seconds");
                    gif.loopDelay=0;test.gifCycles=0;break;
                case 1:
                    if(test.wait(test.gifCycles>0,"changing an active pause to zero resumes playback"))break;
                    test.check(!gif.waitingForLoop,"zero delay has no extra pause");
                    gif.loopDelay=0.3;break;
                case 2:
                    if(test.wait(gif.waitingForLoop,"GIF enters next delay"))break;
                    gif.playing=false;test.hiddenAt=Date.now();break;
                case 3:
                    if(Date.now()-test.hiddenAt<500){test.step--;break;}
                    test.check(!gif.waitingForLoop && !gif.animating && gif.currentFrame===0,"hiding cancels the pending loop restart");
                    gif.source=Qt.resolvedUrl("single-play-logo.gif");test.gifEnd=0;test.gifCycles=0;gif.playing=true;break;
                case 4:
                    if(test.wait(test.gifCycles>=2,"a finite GIF also repeats with the requested delay"))break;
                    test.check(test.gifGap>=280 && test.gifGap<1000,"finite GIF preserves the delay on each cycle");
                    gif.loopAnimation=false;break;
                case 5:
                    if(test.wait(gif.finished,"loop off plays only once"))break;
                    test.check(!gif.waitingForLoop && !gif.animating,"loop off never schedules another playback");
                    pixel.playing=true;break;
                case 6:
                    if(test.wait(test.pixelGap>0,"pixel animation repeats"))break;
                    test.check(test.pixelGap>=275 && test.pixelGap<700,"pixel animation uses the same fractional delay");
                    pixel.loopAnimation=false;break;
                case 7:
                    if(test.wait(!pixel.animating && pixel.progress===1,"pixel animation plays once with looping off"))break;
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            } catch(error){console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error);stop();Qt.quit();}
        }
    }
}
