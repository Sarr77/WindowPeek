import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    required property var hostWidget
    property bool active: false
    property size screenSize
    property rect panelRect
    property var sampleCache: ({})
    property var sampleOrder: []
    readonly property bool eligible: active && !!hostWidget && hostWidget.textShadowMode === "auto"
        && hostWidget.panelStyle === "wallpaper" && !!String(hostWidget.wallpaperSource)
    readonly property string sampleKey: hostWidget ? JSON.stringify([String(hostWidget.wallpaperSource),
        screenSize.width,screenSize.height,Math.floor(panelRect.x/64),Math.floor(panelRect.y/64),
        Math.ceil(panelRect.width/64),Math.ceil(panelRect.height/64)]) : ""
    function schedule() {
        worker.running=false; deadline.stop(); delay.stop();
        if (!eligible || sampleKey === hostWidget.textShadowSampleKey) return;
        if (sampleCache[sampleKey]) {
            hostWidget.textShadowSamples=sampleCache[sampleKey];
            hostWidget.textShadowSampleKey=sampleKey;
        } else delay.restart();
    }
    onEligibleChanged: schedule()
    onSampleKeyChanged: schedule()
    Timer {
        id: delay; interval:200
        onTriggered: {
            if (!root.eligible || root.screenSize.width<=0 || root.screenSize.height<=0 || root.panelRect.width<=0 || root.panelRect.height<=0) return;
            worker.key=root.sampleKey; worker.result="";
            worker.command=["python3","-I","-B",Qt.resolvedUrl("wallpaper_contrast.py").toString().replace(/^file:\/\//,""),
                JSON.stringify({mode:"text-shadow",source:String(root.hostWidget.wallpaperSource),
                    screen:[root.screenSize.width,root.screenSize.height],
                    panel:[root.panelRect.x,root.panelRect.y,root.panelRect.width,root.panelRect.height]})];
            worker.running=true; deadline.restart();
        }
    }
    Timer { id:deadline; interval:3000; onTriggered:worker.running=false }
    Process {
        id:worker
        property string key:""
        property string result:""
        stdout:StdioCollector { onStreamFinished:worker.result=text }
        onExited:function(code) {
            deadline.stop();
            if(code!==0 || !root.eligible || key!==root.sampleKey) return;
            try {
                var data=JSON.parse(result);
                if(!Array.isArray(data.samples) || data.samples.length!==64) return;
                if(!data.samples.every(function(c){return Array.isArray(c) && c.length===3 && c.every(function(v){return Number.isFinite(v) && v>=0 && v<=255;});})) return;
                root.sampleCache[key]=data.samples;
                root.sampleOrder.push(key);
                while(root.sampleOrder.length>8) delete root.sampleCache[root.sampleOrder.shift()];
                root.hostWidget.textShadowSamples=data.samples;
                root.hostWidget.textShadowSampleKey=key;
            } catch (_) {}
        }
    }
}
