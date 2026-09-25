import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "NativeProtection.js" as Protect
import "ShortcutBindings.js" as Bindings

QtObject {
    id: root
    property bool requested: false
    property bool hold: true
    property bool strict: false
    property string monitor: ""
    property point origin: Qt.point(0, 0)
    property point globalOrigin: Qt.point(0, 0)
    property rect anchorRect: Qt.rect(0, 0, 0, 0)
    signal barPressed(int button)
    property size panelSize: Qt.size(1, 1)
    // The native viewport is stable; only this visible card accepts outside
    // wheel/button policy. Transparent space must not count as panel content.
    property rect panelRect: Qt.rect(0, 0, 1, 1)
    property rect previewRect: Qt.rect(0, 0, 0, 0)
    property rect popupRect: Qt.rect(0, 0, 0, 0)
    property string owner: Date.now().toString(36) + ":" + Math.random().toString(36).slice(2)
    readonly property string title: "WindowPeek protection " + owner
    property bool ready: false
    property bool yielded: false
    // Keep the last cause after dismissal so support can inspect it without
    // recording input text, window identities or continuous desktop logs.
    property string lastYieldReason: ""
    property double lastYieldAt: 0
    property bool stopping: false
    property string lastFailureReason: ""
    property double lastFailureAt: 0
    signal failed(string reason)
    function fail(reason) {
        lastFailureReason = reason; lastFailureAt = Date.now();
        release(); failed(reason);
    }
    readonly property bool enabled: requested && Hyprland.usingLua && Quickshell.env("QT_QPA_PLATFORM") !== "offscreen"
    function refreshPointer() {
        if (ready && enabled && !hold) Hyprland.dispatch(Bindings.dispatch(Protect.renew(owner, hold)
            + "local p=hl.get_cursor_pos(); if p then hl.dispatch(hl.dsp.cursor.move({x=p.x,y=p.y})) end; "));
    }
    function release() {
        deadline.stop();
        if (setup.running) { stopping = true; setup.running = false; }
        ready = false; yielded = false;
        if (Hyprland.usingLua) Hyprland.dispatch(Bindings.dispatch(Protect.release(owner)));
    }
    function start() {
        release();
        if (!enabled || !monitor || stopping) return;
        // Each installation has its own token. A delayed expiry event from an
        // earlier installation must never cancel a newly approved one.
        owner = Date.now().toString(36) + ":" + Math.random().toString(36).slice(2);
        setup.command = ["hyprctl", "eval", Protect.install(owner, Quickshell.processId, monitor,
            origin.x, origin.y, panelSize.width, panelSize.height, strict, hold, anchorRect, panelRect, previewRect, popupRect) + "return 'ok'"];
        setup.running = true;
        deadline.restart();
    }
    onEnabledChanged: start()
    // Changing wheel policy must not tear down the mapped panel window.
    // If setup is still in flight, apply the latest value when it completes.
    onStrictChanged: if (ready) Hyprland.dispatch(Bindings.dispatch(Protect.setStrict(owner, strict)))
    onGlobalOriginChanged: if (ready) reposition.start()
    onAnchorRectChanged: if (ready) Hyprland.dispatch(Bindings.dispatch(Protect.anchor(owner, anchorRect)))
    onPanelSizeChanged: if (ready) reposition.start()
    onPanelRectChanged: if (ready) updateBounds.start()
    onPreviewRectChanged: if (ready) updateBounds.start()
    onPopupRectChanged: if (ready) updateBounds.start()
    onReadyChanged: if (ready) reposition.start()
    onHoldChanged: if (ready) Hyprland.dispatch(Bindings.dispatch(Protect.renew(owner, hold)))
    Component.onCompleted: if (enabled) start()
    Component.onDestruction: release()
    property Process setup: Process {
        stdout: StdioCollector { id: result }
        stderr: StdioCollector { }
        onExited: function(code) {
            deadline.stop();
            if (root.stopping) { root.stopping = false; if (root.enabled) Qt.callLater(root.start); return; }
            if (!root.enabled) return;
            if (code === 0 && result.text.trim() === "ok") {
                Hyprland.dispatch(Bindings.dispatch(Protect.setStrict(root.owner, root.strict)));
                root.ready = true;
            }
            else root.fail("setup-error");
        }
    }
    property Timer deadline: Timer { interval: 1500; onTriggered: root.fail("setup-timeout") }
    property Timer lease: Timer {
        interval: 250; running: root.ready; repeat: true
        // Keep the lease and reconcile geometry after delayed configure replies.
        onTriggered: Hyprland.dispatch(Bindings.dispatch(Protect.renew(root.owner, root.hold, root.globalOrigin.x, root.globalOrigin.y, root.panelSize.width, root.panelSize.height, root.anchorRect) + Protect.bounds(root.owner, root.panelRect, root.previewRect, root.popupRect)))
    }
    property Timer updateBounds: Timer {
        interval: 0
        onTriggered: if(root.ready) Hyprland.dispatch(Bindings.dispatch(Protect.bounds(root.owner, root.panelRect, root.previewRect, root.popupRect)))
    }
    property Timer reposition: Timer {
        // Coalesce layout changes, but do not restart this timer on each frame:
        // that would postpone resizing until the expansion animation finishes.
        interval: 0
        onTriggered: if (root.ready) Hyprland.dispatch(Bindings.dispatch(Protect.position(root.owner, root.globalOrigin.x, root.globalOrigin.y, root.panelSize.width, root.panelSize.height)))
    }
    property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.requested) return;
            if (event.name === "configreloaded") root.fail("config-reloaded");
            else if (event.name === "custom" && event.data === "windowpeek-protection-expired," + root.owner) {
                root.fail("lease-expired");
            }
            // Setup can finish before the native window maps. Apply its latest
            // layout immediately on mapping instead of waiting for the lease.
            else if (event.name === "openwindow" && event.data.endsWith("," + root.title) && root.ready) reposition.start();
            else if (event.name === "custom" && event.data.startsWith("windowpeek-protection-yield," + root.owner + ",")) {
                var reason = event.data.slice(("windowpeek-protection-yield," + root.owner + ",").length);
                if (reason !== "outside-wheel" && reason !== "outside-button") return;
                if (!root.yielded) { root.lastYieldReason = reason; root.lastYieldAt = Date.now(); }
                root.yielded = true;
            }
            else if (event.name === "custom" && event.data === "windowpeek-protection-resume," + root.owner) root.yielded = false;
            else if (event.name === "custom" && event.data.startsWith("windowpeek-protection-bar," + root.owner + ",")) {
                var button = Number(event.data.slice(("windowpeek-protection-bar," + root.owner + ",").length));
                if (root.hold && [1, 2, 4].indexOf(button) >= 0) root.barPressed(button);
            }
        }
    }
}
