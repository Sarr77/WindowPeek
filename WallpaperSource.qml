import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Omarchy's background renderer uses this link, independently of XDG_STATE_HOME.
Scope {
    id: root
    property string path: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
    property var consumers: []
    readonly property bool active: consumers.length > 0
    property bool checked: false
    property int revision: 0
    property var file: null
    readonly property url source: file ? Util.fileUrl(file.path) + "?windowpeek=" + encodeURIComponent(file.signature) : ""
    function observe(owner, enabled) {
        var next = consumers.filter(function(item) { return item && item !== owner; });
        if (enabled) next.push(owner);
        consumers = next;
    }
    function refresh() {
        if (!active || probe.running) return;
        probe.requestedPath = path;
        probe.requestedRevision = revision;
        probe.result = "";
        probe.command = ["stat", "-L", "--printf=%d:%i:%s:%y:%z", "--", path];
        probe.running = true;
    }
    onActiveChanged: {
        revision++;
        checked = false;
        if (active) refresh();
        else probe.running = false;
    }
    onPathChanged: { revision++; checked = false; file = null; refresh(); }
    Timer { interval: 1000; repeat: true; running: root.active; onTriggered: root.refresh() }
    Process {
        id: probe
        // A new inode or an in-place edit must invalidate Qt's shared image cache.
        property string requestedPath: ""
        property int requestedRevision: -1
        property string result: ""
        stdout: StdioCollector { onStreamFinished: probe.result = text }
        onExited: function(code) {
            if (!root.active) return;
            if (requestedPath !== root.path || requestedRevision !== root.revision) { root.refresh(); return; }
            var signature = result.trim();
            if (code !== 0 || !signature) root.file = null;
            else if (!root.file || root.file.path !== requestedPath || root.file.signature !== signature)
                root.file = {path: requestedPath, signature: signature};
            root.checked = true;
        }
    }
}
