import QtQuick
import Quickshell
import Quickshell.Hyprland
import "OutsideClicks.js" as Buttons
import "ShortcutBindings.js" as Bindings

QtObject {
    id: root
    property bool active: false
    readonly property bool enabled: active && Hyprland.usingLua && Quickshell.env("QT_QPA_PLATFORM") !== "offscreen"
    readonly property string identity: Date.now().toString(36) + "-" + Math.random().toString(36).slice(2)
    property int sequence: 0
    property string owner: ""
    signal pressed(real x, real y)
    function release() {
        if (owner && Hyprland.usingLua) Hyprland.dispatch(Bindings.dispatch(Buttons.release(owner)));
        owner = "";
    }
    function reset() {
        release();
        if (!enabled) return;
        owner = identity + ":" + (++sequence);
        Hyprland.dispatch(Bindings.dispatch(Buttons.install(owner)));
    }
    onEnabledChanged: reset()
    Component.onCompleted: reset()
    Component.onDestruction: release()
    property Timer lease: Timer {
        interval: 250; repeat: true; running: root.enabled && root.owner !== ""
        onTriggered: Hyprland.dispatch(Bindings.dispatch(Buttons.renew(root.owner)))
    }
    property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") { root.reset(); return; }
            if (!root.enabled || !root.owner || event.name !== "custom") return;
            var prefix = "windowpeek-outside-click," + root.owner + ",";
            if (event.data.indexOf(prefix) !== 0) return;
            var point = event.data.slice(prefix.length).split(",");
            if (point.length === 2 && point.every(function(v) { return v !== "" && Number.isFinite(Number(v)); }))
                root.pressed(Number(point[0]), Number(point[1]));
        }
    }
}
