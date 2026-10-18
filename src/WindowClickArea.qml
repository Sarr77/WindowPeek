import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Hyprland

// Passive surfaces cannot rely on Qt's keyboard state. Sample at press, retain
// the target, and act only after both a completed click and a matching reply.
MouseArea {
    id: root
    required property string address
    signal activated(string address, int modifiers, point position)
    property var gesture: null
    property int sequence: 0
    readonly property string identity: Date.now().toString(36) + "-" + Math.random().toString(36).slice(2)
    // Acquiring hover keyboard focus does not synchronize a pre-held Ctrl in
    // Qt. Read the compositor for native clicks even when the surface is active.
    readonly property bool needsCompositor: Quickshell.env("QT_QPA_PLATFORM") !== "offscreen"

    function query(token) {
        if (!Hyprland.usingLua) { cancel(); return; }
        Hyprland.dispatch("hl.dsp.event('windowpeek-click," + token
            + ",' .. ((hl.is_key_down('Control_L') or hl.is_key_down('Control_R')) and '1' or '0')"
            + " .. ((hl.is_key_down('Shift_L') or hl.is_key_down('Shift_R')) and '1' or '0')"
            + " .. ((hl.is_key_down('Alt_L') or hl.is_key_down('Alt_R')) and '1' or '0')"
            + " .. ((hl.is_key_down('Super_L') or hl.is_key_down('Super_R')) and '1' or '0'))");
    }
    function begin(modifiers, sample, position) {
        cancel();
        if (!enabled || !visible || !address) return;
        gesture = { address: address, modifiers: modifiers, position: position || Qt.point(width / 2, height / 2), clicked: false,
            token: sample ? identity + ":" + (++sequence) : "" };
        if (sample) { deadline.start(); query(gesture.token); }
    }
    function receive(name, data) {
        if (name !== "custom" || !gesture || !gesture.token) return;
        var prefix = "windowpeek-click," + gesture.token + ",";
        if (data.slice(0, prefix.length) !== prefix) return;
        var value = data.slice(prefix.length);
        if (!/^(?:[01]{2}|[01]{4})$/.test(value)) return;
        deadline.stop();
        gesture.token = "";
        gesture.modifiers = (value[0] === "1" ? Qt.ControlModifier : 0)
            | (value[1] === "1" ? Qt.ShiftModifier : 0)
            | (value[2] === "1" ? Qt.AltModifier : 0)
            | (value[3] === "1" ? Qt.MetaModifier : 0);
        finish();
    }
    function complete() {
        if (!gesture) return;
        gesture.clicked = true;
        finish();
    }
    function finish() {
        if (!gesture || !gesture.clicked || gesture.token) return;
        var value = gesture;
        cancel();
        if (enabled && visible && address === value.address)
            activated(value.address, value.modifiers, value.position);
    }
    function cancel() { deadline.stop(); gesture = null; }
    onPressed: function(mouse) { begin(mouse.modifiers, needsCompositor, Qt.point(mouse.x, mouse.y)); }
    onClicked: complete()
    onCanceled: cancel()
    onEnabledChanged: if (!enabled) cancel()
    onVisibleChanged: if (!visible) cancel()
    onAddressChanged: if (gesture && gesture.address !== address) cancel()
    Timer {
        id: deadline; interval: 250
        onTriggered: {
            root.cancel();
            console.warn("WindowPeek: modifier query timed out; click cancelled");
        }
    }
    Connections {
        target: Hyprland
        enabled: !!root.gesture && !!root.gesture.token
        function onRawEvent(event) {
            if (event.name === "configreloaded") root.cancel();
            else root.receive(event.name, event.data);
        }
    }
}
