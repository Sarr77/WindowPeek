import QtQuick
import Quickshell.Io

// The FileView is only a change notifier; preload:false prevents its own read.
// All content crosses a bounded, nonblocking regular-file check in a child.
QtObject {
    id: root
    property string path: ""
    property int maxBytes: 262144
    property bool watchChanges: false
    property bool readPending: false
    property string writePending: ""
    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("bounded_io.py").toString().replace(/^file:\/\//, ""))
    signal loaded(string content)
    signal loadFailed(string reason)
    signal saved()
    signal saveFailed()

    function syncWatcher() { watcher.path = watchChanges ? path : ""; }
    onPathChanged: {
        if (path) reload();
        Qt.callLater(syncWatcher);
    }
    onWatchChangesChanged: Qt.callLater(syncWatcher)
    function reload() {
        if (!path) return;
        if (reader.running) { readPending = true; return; }
        reader.output = "";
        reader.command = ["/usr/bin/python3", "-I", "-B", helper, "read", path, String(maxBytes)];
        reader.running = true;
    }
    function setText(value) {
        if (writer.running) { saveFailed(); return; }
        writePending = JSON.stringify({text:value}) + "\n";
        writer.output = "";
        writer.command = ["/usr/bin/python3", "-I", "-B", helper, "write", path, String(maxBytes)];
        writer.running = true;
    }
    property Process reader: Process {
        property string output: ""
        stdout: StdioCollector { onStreamFinished: reader.output = text }
        onExited: function(code) {
            var result = {};
            try { if (code === 0) result = JSON.parse(output); } catch (_) {}
            if (result.status === "ok") root.loaded(result.text);
            else root.loadFailed(result.status || "error");
            if (root.readPending) { root.readPending = false; Qt.callLater(root.reload); }
        }
    }
    property Process writer: Process {
        property string output: ""
        stdinEnabled: true
        onStarted: write(root.writePending)
        stdout: StdioCollector { onStreamFinished: writer.output = text }
        onExited: function(code) {
            var result = {};
            try { if (code === 0) result = JSON.parse(output); } catch (_) {}
            root.writePending = "";
            if (result.status === "ok") root.saved();
            else root.saveFailed();
        }
    }
    property FileView watcher: FileView {
        path: ""
        preload: false
        watchChanges: true
        printErrors: false
        onFileChanged: root.reload()
    }
    Component.onCompleted: Qt.callLater(syncWatcher)
}
