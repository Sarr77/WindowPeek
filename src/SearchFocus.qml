import QtQuick
import Quickshell
import Quickshell.Hyprland
import "SearchFocus.js" as Focus
import "ShortcutBindings.js" as Bindings

QtObject {
    id: root
    property bool active: false
    property bool pointerReady: false
    readonly property bool available: Hyprland.usingLua && Quickshell.env("QT_QPA_PLATFORM") !== "offscreen"
    readonly property bool enabled: active && available
    readonly property string identity: Date.now().toString(36) + "-" + Math.random().toString(36).slice(2)
    property int sequence: 0
    property string owner: ""
    function release() {
        if (owner && Hyprland.usingLua) Hyprland.dispatch(Bindings.dispatch(Focus.release(owner)));
        owner = "";
    }
    function reset(reloaded) {
        if (!reloaded) release();
        if (!enabled) return;
        owner = identity + ":" + (++sequence);
        Hyprland.dispatch(Bindings.dispatch(Focus.install(owner, reloaded === true)));
    }
    onEnabledChanged: reset(false)
    Component.onCompleted: reset(false)
    Component.onDestruction: release()
    // Once the initial fullscreen input region has committed, restore hit
    // testing at the same coordinates. Without this, a stationary cursor over
    // the bar can remain assigned to the panel until the next physical motion.
    // Compact mode also primes the input region, without retaining the keyboard.
    onPointerReadyChanged: if (pointerReady && available) pointerRefresh.restart()
    property Timer pointerRefresh: Timer {
        interval: 20
        onTriggered: if (root.available && root.pointerReady)
            Hyprland.dispatch(Bindings.dispatch("local p=hl.get_cursor_pos(); if p then hl.dispatch(hl.dsp.cursor.move({x=p.x,y=p.y})) end; "))
    }
    property Timer lease: Timer {
        interval: 250; repeat: true; running: root.enabled && root.owner !== ""
        onTriggered: Hyprland.dispatch(Bindings.dispatch(Focus.renew(root.owner)))
    }
    property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "configreloaded") root.reset(true); }
    }
}
