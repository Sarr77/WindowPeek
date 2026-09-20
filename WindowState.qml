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
    property bool pending: false
    readonly property var inventory: Model.normalize(snapshot)
    readonly property bool ready: snapshot !== null
    readonly property bool busy: reader.running
    signal refreshed(int revision)
    signal failed()

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
            next.clients.forEach(function(client) {
                if (!client || typeof client !== "object") return;
                var entry = DesktopEntries.heuristicLookup(client.class || client.initialClass || "");
                client.app = entry ? entry.name : "";
            });
            snapshot = next;
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
