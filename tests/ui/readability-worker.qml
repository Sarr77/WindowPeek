import QtQuick
import Quickshell
import "WindowPeek" as Plugin
import "WindowPeek/TextReadability.js" as Policy

ShellRoot {
    id:test
    property int step:0
    property int waits:0
    property color ink:"#509475"
    property color theme:"#c1c497"
    property color backing:"transparent"
    property var answer:host.textReadability.result(ink,theme,backing)
    function check(ok,message){if(!ok)throw new Error(message);}
    function settled(){
        if(host.textReadability.busy || Object.keys(host.textReadability.pending).length){
            check(++waits<30,"worker settles");step--;return false;
        }
        waits=0;return true;
    }
    FakeHost {
        id:host;settings:({panelStyle:"wallpaper",wallpaperTransparency:100,textShadowMode:"auto"})
        textShadowSamples:Array.from({length:64},function(){return [66,141,114];})
    }
    Timer {
        interval:40;running:true;repeat:true
        onTriggered:{
            try {
                switch(test.step++) {
                case 0:
                    for(var i=0;i<1000;i++)host.textReadability.result(test.ink,test.theme,test.backing);
                    test.check(Object.keys(host.textReadability.roles).length===1,"a thousand labels share one color job");break;
                case 1:
                    if(!test.settled())break;
                    test.check(host.textReadability.batches===1,"shared role calculated once");
                    var c=host.textReadability.context;
                    test.check(test.answer.active===Policy.needed(c,test.ink,test.backing),"worker agrees with contrast policy");
                    var expected=Policy.ink(c,test.ink,test.theme,test.backing);
                    test.check(test.answer.ink.r===expected.r && test.answer.ink.g===expected.g,"worker preserves ink policy");
                    // Submit one generation, then invalidate it before it can
                    // deliver a reply. The last context must win.
                    host.textShadowSamples=Array.from({length:64},function(){return [245,235,210];});
                    test.ink="#dcd7ba";
                    host.textReadability.result(test.ink,test.theme,test.backing);
                    host.textReadability.submit();
                    host.textShadowSamples=Array.from({length:64},function(){return [12,20,18];});break;
                case 2:
                    if(!test.settled())break;
                    test.check(!test.answer.active,"stale bright-wallpaper result cannot replace latest dark-wallpaper result");
                    host.persistSettings({textShadowMode:"on"});
                    test.check(test.answer.active,"manual On is immediate");
                    host.persistSettings({textShadowMode:"off"});
                    test.check(!test.answer.active && test.answer.ink.r===test.ink.r,"manual Off restores ink immediately");break;
                case 3:
                    if(!test.settled())break;
                    for(var k=0;k<700;k++)host.textReadability.result(Qt.rgba(k/1000,.3,.2,1),test.theme,test.backing);
                    test.check(Object.keys(host.textReadability.roles).length<=512,"long-lived color-role cache is bounded");
                    break;
                case 4:
                    if(!test.settled())break;
                    host.textReadability.idle.triggered(); break;
                case 5:
                    if(host.textReadability.stopping){test.step--;break;}
                    test.check(!host.textReadability.worker.running,"idle worker releases its process");
                    host.persistSettings({textShadowMode:"auto"}); test.ink="#819477"; break;
                case 6:
                    if(!test.settled())break;
                    test.check(host.textReadability.worker.running,"new context restarts idle worker");
                    test.check(test.answer.active===Policy.needed(host.textReadability.context,test.ink,test.backing),"restarted worker returns fresh decision");
                    console.info("WINDOWPEEK_TEST_PASS: shared worker decisions, stale replies, explicit choices, bounded cache, idle restart");stop();Qt.quit();break;
                }
            }catch(e){console.error("WINDOWPEEK_TEST_FAIL: "+e);stop();Qt.quit();}
        }
    }
}
