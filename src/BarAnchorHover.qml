import QtQuick
import Quickshell
import Quickshell.Hyprland
import "ShortcutBindings.js" as Bindings

// Offset monitors can receive an incorrect initial pointer-enter position
// when a layer acquires keyboard focus. Verify the anchor without input events.
QtObject {
    id: root
    property bool active: false
    property Item anchor: null
    property var globalBounds: null
    property bool inside: false
    property string pending: ""
    property int sequence: 0
    readonly property string identity: Date.now().toString(36) + ":" + Math.random().toString(36).slice(2)
    readonly property bool enabled: active && !!anchor && Hyprland.usingLua
        && Quickshell.env("QT_QPA_PLATFORM") !== "offscreen"
    function sample() {
        if (!enabled || pending) return;
        pending = identity + ":" + (++sequence);
        deadline.restart();
        Hyprland.dispatch(Bindings.dispatch("local p=hl.get_cursor_pos(); if p then hl.dispatch(hl.dsp.event('windowpeek-anchor," + pending + ",'..p.x..','..p.y)) end; "));
    }
    onEnabledChanged: {
        inside = false; pending = ""; deadline.stop();
        if (enabled) sample();
    }
    Component.onCompleted: sample()
    property Timer poll: Timer { interval: 80; repeat: true; running: root.enabled; onTriggered: root.sample() }
    property Timer deadline: Timer { interval: 200; onTriggered: { root.inside = false; root.pending = ""; } }
    property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.enabled || !root.pending || event.name !== "custom") return;
            var prefix = "windowpeek-anchor," + root.pending + ",";
            if (event.data.indexOf(prefix) !== 0) return;
            var values = event.data.slice(prefix.length).split(",");
            var x = Number(values[0]), y = Number(values[1]);
            root.pending = ""; deadline.stop();
            var rect = root.globalBounds;
            var origin = rect ? Qt.point(rect.x, rect.y) : root.anchor.mapToGlobal(0, 0);
            var end = rect ? Qt.point(rect.x + rect.width, rect.y + rect.height) : root.anchor.mapToGlobal(root.anchor.width, root.anchor.height);
            root.inside = values.length === 2 && Number.isFinite(x) && Number.isFinite(y)
                && x >= origin.x && y >= origin.y
                && x < end.x && y < end.y;
        }
    }
}
