import QtQuick
import Quickshell
import Quickshell.Hyprland
import "ShortcutBindings.js" as Bindings
import "Shortcuts.js" as Shortcuts

// A passive list cannot receive Ctrl presses. Observe only while it is open,
// including the initial state when Ctrl was held before the surface appeared.
QtObject {
    id: root
    property bool active: false
    property string modifier: "Ctrl"
    property bool enabled: Quickshell.env("QT_QPA_PLATFORM") !== "offscreen"
    property bool known: false
    property bool controlDown: false
    property string pending: ""
    property string bindingOwner: ""
    signal digitPressed(int digit)
    property int sequence: 0
    readonly property string identity: Date.now().toString(36) + "-" + Math.random().toString(36).slice(2)

    function refresh() {
        if (!active || !enabled || !Hyprland.usingLua || pending) return;
        pending = identity + ":" + (++sequence);
        Hyprland.dispatch(Bindings.dispatch(Bindings.renew(bindingOwner)
            + "hl.dispatch(hl.dsp.event('windowpeek-shortcut-control," + pending
            + ",' .. ((" + Shortcuts.modifierQuery(modifier) + ") and '1' or '0'))); "));
        deadline.restart();
    }
    function receive(name, data) {
        if (!active || name !== "custom") return;
        var digitPrefix = "windowpeek-shortcut-digit," + bindingOwner + ",";
        if (bindingOwner && data.indexOf(digitPrefix) === 0) {
            var digit = data.slice(digitPrefix.length);
            if (/^[0-9]$/.test(digit)) digitPressed(Number(digit));
            return;
        }
        if (!pending) return;
        var prefix = "windowpeek-shortcut-control," + pending + ",";
        if (data !== prefix + "0" && data !== prefix + "1") return;
        deadline.stop(); pending = "";
        controlDown = data === prefix + "1";
        known = true;
    }
    function key(event, pressed) {
        if (!active) return;
        // Discard an older sample that could otherwise undo this key event.
        deadline.stop(); pending = "";
        controlDown = Shortcuts.held(Shortcuts.eventMask(event, pressed), modifier);
        known = true;
    }
    function reset() {
        deadline.stop(); pending = ""; known = false; controlDown = false;
        releaseBindings();
        if (active && enabled && Hyprland.usingLua) {
            bindingOwner = identity + ":" + (++sequence);
            Hyprland.dispatch(Bindings.dispatch(Bindings.install(bindingOwner, Shortcuts.luaChord(modifier))));
        }
        refresh();
    }
    function releaseBindings() {
        if (bindingOwner && Hyprland.usingLua)
            Hyprland.dispatch(Bindings.dispatch(Bindings.release(bindingOwner)));
        bindingOwner = "";
    }
    Component.onDestruction: releaseBindings()
    onActiveChanged: reset()
    onEnabledChanged: reset()
    onModifierChanged: reset()
    property Timer poll: Timer {
        interval: 50; repeat: true; running: root.active && root.enabled
        onTriggered: root.refresh()
    }
    property Timer deadline: Timer {
        interval: 250
        onTriggered: { root.known = false; root.pending = ""; }
    }
    property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") root.reset();
            else root.receive(event.name, event.data);
        }
        function onUsingLuaChanged() { root.reset(); }
    }
}
