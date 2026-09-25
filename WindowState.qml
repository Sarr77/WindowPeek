import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "WindowModel.js" as Model
import "Compositor.js" as Compositor

QtObject {
    id: root
    property bool enabled: Quickshell.env("QT_QPA_PLATFORM") !== "offscreen"
    property var snapshot: null
    property int revision: 0
    property real observedAt: 0
    property bool pending: false
    property var inventory: Model.normalize(null)
    property string inventoryPayload: ""
    readonly property bool ready: snapshot !== null
    readonly property bool busy: reader.running
    signal refreshed(int revision)
    signal failed()

    // Focus diagnostics need each fresh compositor observation, but geometry-only
    // updates must not rebuild the searchable list on every monitor.
    function updateInventory() {
        var next = Model.normalize(snapshot);
        var payload = JSON.stringify(next);
        if (payload === inventoryPayload) return;
        inventoryPayload = payload;
        inventory = next;
    }
    onSnapshotChanged: updateInventory()

    function refresh() {
        if (!enabled) return;
        if (reader.running) { pending = true; return; }
        coalesce.stop();
        pending = false;
        reader.running = true;
        timeout.restart();
    }
    function receive(code, output) {
        timeout.stop();
        var next = code === 0 ? Compositor.snapshot(output) : null;
        if (!next) { snapshot = null; failed(); }
        else {
            // Our opt-in focus surface is a presentation window, not a result.
            next.clients = next.clients.filter(function(c) {
                return !(c.pid === Quickshell.processId && /^WindowPeek protection [a-z0-9:-]+$/.test(c.title || ""));
            });
            var appNames = Object.create(null);
            next.clients.forEach(function(client) {
                if (!client || typeof client !== "object") return;
                var klass = client.class || client.initialClass || "";
                if (!(klass in appNames)) {
                    var entry = DesktopEntries.heuristicLookup(klass);
                    appNames[klass] = entry ? entry.name : "";
                }
                client.app = appNames[klass];
            });
            snapshot = next;
            observedAt = Date.now();
            revision++;
            refreshed(revision);
        }
        if (pending) coalesce.restart();
    }
    property Process reader: Process {
        command: ["hyprctl", "-j", "--batch", "clients;workspaces;monitors;activewindow"]
        stdout: StdioCollector { id: output }
        stderr: StdioCollector { }
        onExited: function(code) { root.receive(code, output.text); }
    }
    property Timer timeout: Timer {
        interval: 2000
        onTriggered: { reader.running = false; root.snapshot = null; root.failed(); }
    }
    property Timer coalesce: Timer { interval: 40; onTriggered: root.refresh() }
    property Timer reconcile: Timer { interval: 5000; running: root.enabled; repeat: true; onTriggered: root.refresh() }
    property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.enabled && Compositor.relevantEvent(event.name)) coalesce.restart();
        }
    }
    Component.onCompleted: refresh()
}
