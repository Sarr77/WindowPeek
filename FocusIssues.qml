import QtQuick
import Quickshell
import Quickshell.Io
import "FocusIssues.js" as Issues

QtObject {
    id: root
    // The compositor instance survives bar restarts, but not logout/compositor restart.
    property string desktopSession: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
        || ("process-" + Date.now() + "-" + Math.random())
    readonly property string directory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/windowpeek"
    readonly property string path: directory + "/focus-issues.json"
    property var data: Issues.empty()
    property bool ready: false
    property bool failed: false
    property bool readBlocked: false
    readonly property bool saving: writes.busy
    property var pendingData: null
    property int requestId: 0
    property WriteQueue writes: WriteQueue { file: root.file }
    readonly property bool sessionIgnored: !!desktopSession && data.ignoredSession === desktopSession
    readonly property bool allIgnored: data.ignoreAll
    readonly property var apps: data.apps.slice().sort(function(a, b) { return b.lastSeen - a.lastSeen; })
    signal changed()
    function load(raw) {
        if (ready) return;
        try { data = Issues.normalize(JSON.parse(raw)); writes.committed = JSON.stringify(data, null, 2) + "\n"; }
        catch (_) { failed = true; readBlocked = true; }
        ready = true;
    }
    function save(next, done) {
        if (!ready || readBlocked) { failed = true; if (done) done(false); return false; }
        var id = ++requestId;
        pendingData = next;
        writes.enqueue(JSON.stringify(next, null, 2) + "\n", function(ok) {
            failed = !ok;
            if (ok) { data = next; changed(); }
            if (id === requestId) pendingData = null;
            if (done) done(ok);
        });
        return true;
    }
    function record(client, now) { return save(Issues.record(pendingData || data, client, now)); }
    function muted(key) { return Issues.muted(data, desktopSession, key || ""); }
    function choose(scope, value, key, done) {
        return save(Issues.choose(pendingData || data, scope, value, desktopSession, key || ""), done);
    }
    property Process prepare: Process {
        command: ["mkdir", "-p", "-m", "700", root.directory]; running: true
        onExited: function(code) {
            if (code !== 0) { root.failed = true; root.readBlocked = true; root.ready = true; return; }
            root.file.path = root.path;
        }
    }
    property FileView file: FileView {
        path: ""; atomicWrites: true; blockWrites: false; printErrors: false
        onLoaded: root.load(text())
        onLoadFailed: function(error) {
            if (!path || root.ready) return;
            if (error !== FileViewError.FileNotFound) { root.failed = true; root.readBlocked = true; }
            root.ready = true;
        }
    }
}
