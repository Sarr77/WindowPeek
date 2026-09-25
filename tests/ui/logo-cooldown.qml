import QtQuick
import QtQuick.Window
import Quickshell
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property int waits: 0
    property real hiddenAt: 0
    function check(ok, message) { if (!ok) throw new Error(message); }
    function wait(ok, message) { if (ok) { waits=0; return false; } if (++waits>50) throw new Error(message); step--; return true; }
    function find(item, name) {
        if (item.objectName===name) return item;
        for (var child of item.children || []) { var result=find(child,name); if(result) return result; }
        return null;
    }
    FakeHost { id: host }
    Window {
        id: window; visible: true; width: 460; height: 360
        Plugin.PanelLogo {
            id: compact; hostWidget: host; x:20; y:20; width:320; height:75
            source:"builtin:omarchy-pixel"; cooldownSlot:"hover"; cooldown:0.6; loopAnimation:false
        }
        Plugin.PanelLogo {
            id: settings; hostWidget: host; x:20; y:120; width:320; height:75
            source:String(Qt.resolvedUrl("animated-logo.gif")); cooldownSlot:"settings"; cooldown:1.2; loopDelay:0
        }
        Plugin.PanelLogo {
            id: peer; hostWidget: host; x:20; y:220; width:320; height:75; visible:false
            source:"builtin:omarchy-pixel"; cooldownSlot:"hover"; cooldown:0.6
        }
    }
    Timer {
        interval:100; repeat:true; running:true
        onTriggered: {
            try {
                switch(test.step++) {
                case 0:
                    if(test.wait(compact.playbackGranted && settings.playbackGranted && test.find(settings,"customPanelLogo").animating,"both logo types start on their first appearance"))break;
                    compact.visible=false;settings.visible=false;test.hiddenAt=Date.now();break;
                case 1: compact.visible=true;settings.visible=true;break;
                case 2:
                    test.check(!compact.playbackGranted && !settings.playbackGranted,"reopening during cooldown stays static");
                    test.check(test.find(compact,"pixelPanelLogo").progress===0 && test.find(settings,"customPanelLogo").currentFrame===0,"static logos retain their initial appearance");
                    compact.visible=false;break;
                case 3:
                    if(Date.now()-test.hiddenAt<800){test.step--;break;}
                    compact.visible=true;break;
                case 4:
                    test.check(compact.playbackGranted && !settings.playbackGranted,"independent cooldowns do not restart a visible blocked logo");
                    peer.visible=true;break;
                case 5:
                    test.check(!peer.playbackGranted,"another monitor shares the compact logo cooldown");
                    peer.visible=false;peer.cooldown=0;break;
                case 6: peer.visible=true;break;
                case 7:
                    test.check(peer.playbackGranted,"zero cooldown permits every opening");
                    if(Date.now()-test.hiddenAt<1500){test.step--;break;}
                    settings.visible=false;break;
                case 8: settings.visible=true;break;
                case 9:
                    test.check(settings.playbackGranted && test.find(settings,"customPanelLogo").animating,"GIF restarts after its cooldown");
                    window.visible=false;break;
                case 10:
                    test.check(!compact.playbackGranted && !settings.playbackGranted && !test.find(settings,"customPanelLogo").animating,"closing the backing window ends playback");
                    window.visible=true;break;
                case 11:
                    test.check(!settings.playbackGranted && peer.playbackGranted,"backing-window reopen respects cooldown and zero independently");
                    compact.visible=false;settings.visible=false;peer.visible=false;
                    host.persistSettings({sharedLogoCooldownEnabled:true,sharedLogoCooldown:0.6});break;
                case 12: compact.visible=true;break;
                case 13:
                    test.check(compact.playbackGranted,"shared cooldown admits first logo");
                    settings.visible=true;break;
                case 14:
                    test.check(!settings.playbackGranted,"pixel playback blocks the other slot's GIF");
                    compact.visible=false;settings.visible=false;test.hiddenAt=Date.now();break;
                case 15: settings.visible=true;break;
                case 16:
                    test.check(!settings.playbackGranted,"shared cooldown lasts after the first logo closes");
                    if(Date.now()-test.hiddenAt<800){test.step--;break;}
                    settings.visible=false;break;
                case 17: settings.visible=true;break;
                case 18:
                    test.check(settings.playbackGranted,"other slot starts after the shared cooldown");
                    compact.visible=true;break;
                case 19:
                    test.check(!compact.playbackGranted,"GIF playback also blocks the first slot");
                    settings.visible=false;compact.visible=false;
                    host.persistSettings({sharedLogoCooldownEnabled:false});break;
                case 20: compact.visible=true;settings.visible=true;break;
                case 21:
                    test.check(compact.playbackGranted && !settings.playbackGranted,"disabling sharing restores independent cooldowns");
                    compact.visible=false;settings.visible=false;
                    host.persistSettings({sharedLogoCooldownEnabled:true,sharedLogoCooldown:0});break;
                case 22: compact.visible=true;settings.visible=true;break;
                case 23:
                    test.check(compact.playbackGranted && settings.playbackGranted,"shared zero permits both logos every opening");
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            } catch(error) { console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error);stop();Qt.quit(); }
        }
    }
}
