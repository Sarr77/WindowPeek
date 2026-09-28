import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "WindowPeek" as Plugin

// Fake content only. Run --desktop inside a private compositor for GPU figures.
ShellRoot {
    id: test
    property int stage: -1
    property double began: 0
    property double readyAt: 0
    property double lastTick: 0
    property real startCpu: 0
    property var gaps: []
    property bool collecting: false
    readonly property var cases: [
        {name:"original",source:""}, {name:"pixel",source:"builtin:omarchy-pixel"},
        {name:"matrix-original",source:"builtin:ttfx-matrix"},
        {name:"matrix-theme",source:"builtin:ttfx-matrix",theme:true},
        {name:"highlight-motion",source:"builtin:ttfx-highlight",motion:"float",theme:true},
        {name:"custom-gif",source:String(Qt.resolvedUrl("WindowPeek/vendor/ttfx/fireworks.gif"))},
        {name:"custom-gif-scatter",source:String(Qt.resolvedUrl("WindowPeek/vendor/ttfx/fireworks.gif")),reveal:"scatter"},
        {name:"custom-gif-pixels-tint",source:String(Qt.resolvedUrl("WindowPeek/vendor/ttfx/fireworks.gif")),reveal:"pixels",theme:true},
        {name:"hidden",source:"builtin:ttfx-highlight",hidden:true}
    ]
    FakeHost { id: host }
    Window {
        id: window; visible:true; width:520;height:420;color:"#161421"
        Rectangle {
            id: surface; anchors.centerIn:parent; width:400;height:300
            color:"#272134";border.color:"#bb93dd";radius:8
            SequentialAnimation on width {
                running:test.stage>=0 && !test.cases[test.stage].hidden;loops:Animation.Infinite
                NumberAnimation { to:480;duration:300;easing.type:Easing.InOutQuad }
                NumberAnimation { to:360;duration:300;easing.type:Easing.InOutQuad }
            }
            Plugin.PanelLogo {
                id: logo;anchors.fill:parent;anchors.margins:16;hostWidget:host;cooldownSlot:"settings"
                source:test.stage>=0 ? test.cases[test.stage].source : ""
                themeColors:test.stage>=0 && !!test.cases[test.stage].theme
                motion:test.stage>=0 ? test.cases[test.stage].motion || "none" : "none"
                reveal:test.stage>=0 ? test.cases[test.stage].reveal || "none" : "none"
                visible:test.stage>=0 && !test.cases[test.stage].hidden
                loopDelay:0
                onCustomImageReadyChanged: if(customImageReady && !test.readyAt) test.readyAt=Date.now()
            }
        }
    }
    FileView {
        id: cpu;path:"/proc/self/stat";blockLoading:false;blockWrites:false
        onLoaded: {
            var raw=text(), fields=raw.slice(raw.lastIndexOf(")")+2).trim().split(/\s+/);
            var ticks=Number(fields[11])+Number(fields[12]);
            if(test.collecting) {
                test.collecting=false;
                var sorted=test.gaps.slice().sort(function(a,b){return a-b;});
                console.log("LOGO_METRIC",JSON.stringify({name:test.cases[test.stage].name,
                    elapsedMs:Date.now()-test.began,cpuTicks:ticks-test.startCpu,
                    readyMs:Math.max(0,test.readyAt-test.began),tickP95:sorted[Math.floor(sorted.length*.95)]||0,
                    tickMax:sorted[sorted.length-1]||0}));
            }
            if(test.stage+1===test.cases.length) {console.log("WINDOWPEEK_TEST_PASS logo-performance");Qt.quit();return;}
            test.stage++;
            test.startCpu=ticks;test.began=Date.now();test.readyAt=0;test.lastTick=test.began;test.gaps=[];
            endStage.restart();
        }
    }
    Timer { id:endStage;interval:2500;onTriggered:{test.collecting=true;cpu.reload();} }
    Timer {
        interval:16;repeat:true;running:true
        onTriggered:{var now=Date.now();if(test.lastTick)test.gaps.push(now-test.lastTick);test.lastTick=now;}
    }
}
