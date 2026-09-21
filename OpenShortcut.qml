import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "OpenShortcut.js" as Binding
import "ShortcutBindings.js" as Lua

// One instance per active IPC owner. No persistent config, unbinds or shell hooks.
QtObject {
    id: root
    property bool active: false
    property string chord: "Alt+Super+P"
    readonly property bool available: active && Hyprland.usingLua && Quickshell.env("QT_QPA_PLATFORM") !== "offscreen"
    readonly property string owner: Date.now().toString(36) + "-" + Math.random().toString(36).slice(2)
    property bool registered: false
    property int revision: 0
    signal pressed()
    function stop() {
        if (registered && Hyprland.usingLua) Hyprland.dispatch(Lua.dispatch(Binding.release(owner)));
        registered = false;
    }
    function refresh() {
        revision++;
        stop();
        probe.running = false;
        if (available) { probe.revision = revision; probe.running = true; }
    }
    onAvailableChanged: refresh()
    onChordChanged: refresh()
    Component.onCompleted: refresh()
    Component.onDestruction: stop()
    property Process probe: Process {
        property int revision: -1
        property string result: ""
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector { onStreamFinished: root.probe.result = text }
        onExited: function(code) {
            if (!root.available || revision !== root.revision || code !== 0) return;
            try {
                if (Binding.occupied(JSON.parse(result), root.chord)) return;
                Hyprland.dispatch(Lua.dispatch(Binding.install(root.owner, root.chord)));
                root.registered = true;
            } catch (error) { /* An unreadable binding list must never overwrite user shortcuts. */ }
        }
    }
    property Timer lease: Timer {
        interval: 5000; repeat: true; running: root.available && root.registered
        onTriggered: Hyprland.dispatch(Lua.dispatch(Binding.renew(root.owner)))
    }
    property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") root.refresh();
            else if (root.available && root.registered && event.name === "custom"
                && event.data === "windowpeek-open," + root.owner) root.pressed();
        }
    }
}
