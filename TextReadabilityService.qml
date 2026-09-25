import QtQuick
import Quickshell.Io
import qs.Commons
import "TextReadability.js" as Readability

// One cache per panel owner. Many labels share a small set of color roles.
// Recompute those roles in a worker; the UI never waits for wallpaper analysis.
QtObject {
    id: root
    required property var hostWidget
    property int revision: 0
    property int epoch: 0
    property bool busy: false
    property bool stopping: false
    property var roles: ({})
    property var answers: ({})
    property var pending: ({})
    property int batches: 0
    property int lastWorkerMs: 0
    readonly property string wallpaperSource: String(hostWidget.wallpaperSource || "")
    readonly property var wallpaperSamples: currentSamples()
    readonly property bool awaitingWallpaperSamples: hostWidget.panelStyle==="wallpaper"
        && hostWidget.wallpaperTransparency>0
        && (hostWidget.wallpaperPending === true || wallpaperSource!=="")
        && wallpaperSamples.length===0
    property string answerWallpaperSource: ""
    readonly property var context: ({
        textShadowMode:hostWidget.textShadowMode,
        panelStyle:hostWidget.panelStyle,
        wallpaperTransparency:hostWidget.wallpaperTransparency,
        glassTransparency:hostWidget.glassTransparency,
        wallpaperSource:wallpaperSource,
        awaitingWallpaperSamples:awaitingWallpaperSamples,
        textShadowSamples:wallpaperSamples,
        surfaces:{panel:plain(hostWidget.surfaces.panel),wallpaperBrightness:hostWidget.surfaces.wallpaperBrightness || 0}
    })
    function currentSamples() {
        var key=hostWidget.textShadowSampleKey || "";
        if(key) {
            try {
                // Samples from a previous wallpaper cannot qualify a new one.
                if(JSON.parse(key)[0]!==String(hostWidget.wallpaperSource || "")) return [];
            } catch (_) { return []; }
        }
        return hostWidget.textShadowSamples || [];
    }
    function plain(c) { return {r:c.r,g:c.g,b:c.b,a:c.a}; }
    function colorKey(c) { return [c.r,c.g,c.b,c.a].join(","); }
    function result(color, theme, backing) {
        revision; context;
        var selected=hostWidget.textShadowMode;
        if(selected==="off" || hostWidget.panelStyle==="solid")
            return {active:selected==="on",ink:color};
        var key=colorKey(color)+"/"+colorKey(theme)+"/"+colorKey(backing);
        var job=roles[key];
        if(!awaitingWallpaperSamples && !job && Object.keys(roles).length<512) {
            job={key:key,color:plain(color),theme:plain(theme),backing:plain(backing)};
            roles[key]=job; pending[key]=job;
            Qt.callLater(root.submit);
        }
        if(!awaitingWallpaperSamples && answers[key]) return selected==="on" && !answers[key].active
            ? {active:true,ink:answers[key].ink} : answers[key];
        // Missing wallpaper samples are not evidence of a solid dark tint.
        // Keep this legible first paint until a real crop has been analysed;
        // an early guessed answer must not briefly dim the text in between.
        // Keep opening instant while the first result is prepared. No sample
        // scan here, and never use this fallback as the settled contrast result.
        var translucent=hostWidget.panelStyle!=="solid";
        var lightness=Readability.luminance(color);
        return {active:selected==="on" || translucent,
            ink:translucent ? (lightness>=0.4 || lightness<=0.06 ? {r:color.r,g:color.g,b:color.b,a:1} : plain(theme)) : color};
    }
    onContextChanged: {
        epoch++;
        if(context.wallpaperSource!==answerWallpaperSource) {
            answers={}; answerWallpaperSource=context.wallpaperSource;
        }
        // Retain settled ink during refresh, but do not keep processing roles
        // from old themes, discarded previews or continuous color-picker drags.
        pending={}; roles={};
        if(Object.keys(answers).length>512) answers={};
        Qt.callLater(root.submit);
    }
    function submit() {
        if(busy || stopping || awaitingWallpaperSamples) return;
        var keys=Object.keys(pending).slice(0,64);
        var jobs=keys.map(function(key){return pending[key];});
        if(!jobs.length) return;
        for(var key of keys) delete pending[key];
        busy=true; batches++;
        idle.stop();
        worker.message=JSON.stringify({epoch:epoch,context:context,jobs:jobs})+"\n";
        if(worker.running) worker.write(worker.message);
        else worker.running=true;
        deadline.restart();
    }
    // Process lifetime is managed by Quickshell. WorkerScript cannot safely
    // outlive the QQmlEngine during shell teardown (Qt 6.11 / Quickshell 0.3).
    property Timer deadline: Timer { interval:3000; onTriggered: worker.signal(9) }
    property Timer idle: Timer { interval:15000; onTriggered: { root.stopping=true; worker.running=false; } }
    property Process worker: Process {
        property string message: ""
        stdinEnabled: true
        command: ["python3","-I","-B","-u", decodeURIComponent(Qt.resolvedUrl("wallpaper_contrast.py").toString().replace(/^file:\/\//,"")),
            "--text-readability-worker"]
        onStarted: write(message)
        stdout: SplitParser {
            onRead: function(line) {
                try { root.receive(JSON.parse(line)); }
                catch (_) { worker.signal(9); }
            }
        }
        onExited: {
            deadline.stop(); idle.stop(); root.busy=false; root.stopping=false;
            if(Object.keys(root.pending).length) Qt.callLater(root.submit);
            // A failed batch keeps its immediate rendering fallback. Do not
            // spin on a missing helper; a later context/role can start it again.
        }
    }
    function receive(message) {
            deadline.stop();
            root.busy=false;
            if(message.epoch===root.epoch) {
                root.lastWorkerMs=message.elapsed;
                var changed=false;
                for(var key in message.results) {
                    var before=root.answers[key], next=message.results[key];
                    if(!before || before.active!==next.active || before.ink.r!==next.ink.r
                        || before.ink.g!==next.ink.g || before.ink.b!==next.ink.b || before.ink.a!==next.ink.a) {
                        root.answers[key]=next; changed=true;
                    }
                }
                if(changed) root.revision++;
            }
            if(Object.keys(root.pending).length) Qt.callLater(root.submit);
            else idle.restart();
    }
}
