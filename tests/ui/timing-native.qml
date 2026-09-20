import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui as Ui
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: -1
    property int waits: 0
    property int cycleMaps: 0
    property bool observingCycle: false
    property int cycleFrames: 0
    property int maps: 0
    property bool hidden: false
    property int modifierSample: 0
    property var panel: null
    property var button: null
    property var list: null
    property var firstRow: null
    property real scrollPosition: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(value, message) { if (!value) throw new Error(message); }
    function fail(message) { console.error("WINDOWPEEK_TEST_FAIL at step " + step + ": " + message); timer.stop(); Qt.quit(); }
    function find(object, name, seen) {
        if (!object || seen.indexOf(object) >= 0) return null;
        seen.push(object);
        if (object.objectName === name) return object;
        var children = [];
        if (object.data) for (var child of object.data) children.push(child);
        if (object.item) children.push(object.item);
        if (object.contentItem) children.push(object.contentItem);
        if (object.children) for (var child of object.children) children.push(child);
        for (var child of children) { var found = find(child, name, seen); if (found) return found; }
        return null;
    }
    function move(item, x, y) {
        check(!mover.running, "previous pointer move is unfinished");
        var surface = item.QsWindow.window;
        var point;
        if (surface && surface.origin !== undefined) {
            var local = item.mapToItem(surface.contentItem, x, y);
            point = Qt.point(surface.screen.x + surface.origin.x + local.x,
                surface.screen.y + surface.origin.y + local.y);
        } else point = item.mapToGlobal(x, y);
        mover.target = item; mover.point = Qt.point(x, y);
        mover.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.cursor.move({x="
            + Math.round(point.x) + ",y=" + Math.round(point.y) + "}))"];
        mover.running = true;
    }
    function clickBar() {
        if (panel.opened) {
            var point = button.mapToItem(bar.contentItem, 20, 14);
            events.mouseClick(panel.surface.cardItem.Window.window.contentItem, point.x, point.y,
                Qt.LeftButton, Qt.NoModifier, 0);
        } else events.mouseClick(button, 20, 14, Qt.LeftButton, Qt.NoModifier, 0);
    }
    function control(down) {
        var state = loader.item.windowPreview.modifierState;
        state.pending = "timing:" + (++modifierSample);
        state.receive("custom", "windowpeek-control," + state.pending + "," + (down ? "1" : "0"));
    }
    function rowPointer() { return find(panel.body, "windowFocusPointer", []); }
    function previewCard() { return find(loader.item.windowPreview.contentItem, "windowThumbnailPointer", []); }
    function checkPreview(left) {
        var preview = loader.item.windowPreview;
        check(preview.visible && preview.backingWindowVisible, "instant preview maps: " + JSON.stringify({visible:preview.visible,mapped:preview.backingWindowVisible,ready:preview.ready,available:preview.available,known:preview.modifierState.known,ctrl:preview.modifierState.controlDown,row:preview.rowHovered,address:preview.address}));
        check(preview.contentItem.QsWindow.window.WlrLayershell.namespace === "omarchy-keyboard-panel", "preview uses unanimated layer role");
        check(preview.contentItem.QsWindow.window.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None, "preview keeps keyboard passive");
        probe.left = left;
        probe.running = true;
    }
    Process {
        id: probe
        property bool left: false
        command: ["hyprctl", "-j", "layers"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var preview = loader.item.windowPreview;
                    var screen = preview.contentItem.QsWindow.window.screen;
                    var levels = JSON.parse(text)[screen.name].levels;
                    var candidates = [];
                    for (var level in levels) for (var layer of levels[level]) {
                        if (layer.namespace === "omarchy-keyboard-panel" && layer.w === preview.width && layer.h === preview.height)
                            candidates.push(layer);
                    }
                    test.check(candidates.length === 1, "compositor exposes the expected preview surface");
                    var actual = candidates[0];
                    var card = test.previewCard();
                    var rect = card.mapToItem(preview.contentItem, 0, 0, card.width, card.height);
                    var bounds = preview.boundsRect;
                    var gap = probe.left ? screen.x + bounds.x - actual.x - rect.x - rect.width
                        : actual.x + rect.x - screen.x - bounds.x - bounds.width;
                    test.check(Math.abs(gap - preview.bridgeWidth) <= 2,
                        "compositor places preview beside panel; gap=" + gap + " layer=" + JSON.stringify(actual));
                    test.check(actual.y + rect.y >= screen.y + bounds.y - 1, "preview stays at or below panel top");
                    if (probe.left) test.move(bar.contentItem, 30, 70);
                    else test.move(preview.contentItem, preview.bridgeWidth / 2, preview.height / 2);
                } catch (error) { test.fail(error); }
            }
        }
        onExited: function(code) { if (code !== 0) test.fail("reading compositor geometry failed"); }
    }
    TestEvent { id: events }
    Process {
        id: mover
        property var target: null
        property point point
        onExited: function(code) {
            if (code !== 0) { test.fail("native pointer move failed"); return; }
            // Cursor warps update native surface entry but can omit motion within
            // that surface. Deliver the matching Qt event at the parked position.
            events.mouseMove(target, point.x, point.y, 0, Qt.NoButton, Qt.NoModifier);
        }
    }
    FakeHost { id: data }
    Plugin.WindowState { id: fictionalState; enabled: false; snapshot: data.snapshot }
    QtObject { id: fakeShell; function updateEntryInline(id, values) { return true; } }
    Ui.PluginBarApi {
        id: api; pluginId: "sarr.windowpeek.timing.test"; moduleName: "sarr.windowpeek"
        position: "top"; barSize: 28; shell: fakeShell
        layoutConfig: ({left:[{id:"sarr.windowpeek", hintsMode:"auto", hintsUsed:0,
            uiScale:test.scale, windowPreviews:false, autoUpdates:false}], center:[], right:[]})
        _moduleWidgets: function() { return loader.item ? [loader.item] : []; }
        _registerClickTarget: function(target) { api.clickTargets = api.clickTargets.concat([target]); }
        _unregisterClickTarget: function(target) { api.clickTargets = api.clickTargets.filter(function(item) { return item !== target; }); }
        _targetBelongsToWindow: function(target, window) { return target.QsWindow.window === window; }
        _requestPopout: function(owner) { activePopout = owner; }
        _releasePopout: function(owner) { if (activePopout === owner) activePopout = null; }
    }
    PanelWindow {
        id: bar
        anchors { top: true; left: true; right: true }
        implicitHeight: 28; color: "transparent"; exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        Loader { id: loader; x: 140; active: false; sourceComponent: Plugin.Widget { bar: api } }
    }
    Component.onCompleted: {
        var state = Plugin.Runtime.state;
        state.enabled = false; state.pending = false; state.coalesce.stop(); state.reader.running = false;
        Plugin.Runtime.state = fictionalState;
        var snapshot = JSON.parse(JSON.stringify(data.snapshot));
        for (var i = 6; i < 28; ++i) snapshot.clients.push({address:"0x"+i.toString(16), class:"code", title:"Fictional return " + i, workspace:{id:1,name:"1"}});
        data.snapshot = snapshot;
    }
    Connections {
        target: test.panel ? test.panel.surface : null
        function onBackingWindowVisibleChanged() { if (test.panel.mapped) test.maps++; }
    }
    Connections {
        target: test.panel ? test.panel.surface.cardItem.Window.window : null
        function onFrameSwapped() {
            if (!test.observingCycle) return;
            try {
                test.cycleFrames++;
                test.check(test.maps === test.cycleMaps && test.panel.mapped, "background toggle keeps one native surface");
                test.check(test.panel.surface.cardItem.opacity === 1, "background toggle does not fade the panel");
                test.check(test.panel.surface.cardItem.radius > 0, "background toggle keeps rounded borders");
                test.check(test.list.itemAtIndex(1) === test.firstRow, "background toggle retains row identity");
                test.check(Math.abs(test.list.contentY - test.scrollPosition) < 1, "background toggle preserves unfiltered scroll");
            } catch (error) { test.fail(error); }
        }
    }
    Timer {
        id: timer; interval: 200; running: true; repeat: true
        onTriggered: {
            try {
                var widget = loader.item;
                switch (test.step++) {
                case -1:
                    test.move(bar.contentItem, bar.width - 30, 70);
                    loader.active = true; break;
                case 0:
                    if (!widget || !widget.settingsReady) { test.check(test.waits++ < 20, "widget ready"); test.step--; break; }
                    test.panel = test.find(widget, "windowPeekController", []);
                    test.button = test.find(widget, "windowPeekBarButton", []);
                    test.list = test.find(test.panel.body, "windowList", []);
                    test.check(widget.panelHoverDelay === 400 && widget.previewHoverDelay === 400 && widget.popupAnimations,
                        "default timings preserve existing behavior");
                    test.check(widget.persistSettings({panelHoverDelay:1000, popupAnimations:false}), "save isolated test settings");
                    test.move(test.button, 20, 14); break;
                case 1:
                    test.check(widget.canShowTooltip && !widget.tooltipReady && !test.panel.mapped, "positive delay waits");
                    widget.persistSettings({panelHoverDelay:0});
                    test.check(widget.tooltipReady && test.panel.hoverOpened, "zero opens the pending bar hover synchronously");
                    test.check(test.panel.surface.cardItem.opacity === 1, "opening has no fade when disabled");
                    break;
                case 2:
                    test.check(test.panel.mapped && test.maps === 1, "instant hover mapped once");
                    test.firstRow = test.list.itemAtIndex(1); test.list.contentY = 120; test.scrollPosition = test.list.contentY;
                    widget.persistSettings({panelHoverDelay:1500});
                    test.check(widget.tooltipReady && test.panel.hoverOpened, "changing delay preserves an existing hover");
                    test.button.triggerPress(Qt.LeftButton);
                    test.check(test.panel.opened && test.panel.expansion === 1, "click expands immediately without animation");
                    test.check(test.list.itemAtIndex(1) === test.firstRow && test.list.contentY === test.scrollPosition,
                        "instant expansion preserves the row and scroll position");
                    test.move(bar.contentItem, bar.width - 30, 70); break;
                case 3:
                    test.check(test.maps === 1 && test.panel.surface.cardItem.opacity === 1, "expansion never remaps or fades");
                    widget.actionOnClose = true; widget.close();
                    test.check(test.panel.surface.cardItem.opacity === 0, "closing has no fade when disabled");
                    test.panel.afterHidden(function() { test.hidden = true; }); break;
                case 4:
                    test.check(test.hidden && !test.panel.mapped, "hidden callback follows native unmap without an animation");
                    widget.persistSettings({panelHoverDelay:600});
                    test.move(test.button, 20, 14); break;
                case 5:
                    test.check(!widget.tooltipReady && !test.panel.mapped, "restored positive delay does not open early");
                    break;
                case 8:
                    test.check(widget.tooltipReady && test.panel.hoverOpened && test.panel.mapped, "configured positive delay eventually opens");
                    test.move(bar.contentItem, bar.width - 30, 70); break;
                case 11:
                    test.check(!test.panel.mapped, "leaving closes an instant panel after handoff grace");
                    widget.persistSettings({panelHoverDelay:1000});
                    test.move(test.button, 20, 14); break;
                case 12:
                    test.check(!test.panel.mapped, "new dwell is pending");
                    test.move(bar.contentItem, bar.width - 30, 70); break;
                case 18:
                    test.check(!widget.tooltipReady && !test.panel.mapped, "leaving cancels a pending opening");
                    widget.persistSettings({popupAnimations:true});
                    widget.open();
                    test.check(test.panel.surface.cardItem.opacity < 1, "animations can be restored");
                    widget.persistSettings({popupAnimations:false});
                    test.check(test.panel.surface.cardItem.opacity === 1, "disabling an in-flight fade finishes it immediately");
                    break;
                case 19:
                    widget.actionOnClose = true; widget.close(); widget.open(); break;
                case 20:
                    test.check(test.panel.opened && test.panel.body.searchField.activeFocus, "rapid reopening retains keyboard focus without fades");
                    widget.actionOnClose = true; widget.close(); break;
                case 21:
                    test.check(!test.panel.mapped, "native surface unmaps");
                    widget.persistSettings({windowPreviews:true, previewHoverDelay:0});
                    widget.windowPreview.modifierState.enabled = false;
                    widget.open(); break;
                case 22: test.move(test.rowPointer(), 20, 15); break;
                case 23: test.control(false); break;
                case 24:
                    test.checkPreview(false);
                    break;
                case 25:
                    test.check(widget.windowPreview.containsPointer && widget.windowPreview.visible, "instant layer retains the handoff gap");
                    test.move(test.previewCard(), 40, 30); break;
                case 26:
                    test.check(widget.windowPreview.pointerOnCard, "pointer reaches instant card");
                    test.control(true);
                    test.check(widget.windowPreview.visible, "Ctrl preserves instant card under the pointer");
                    test.move(bar.contentItem, bar.width - 30, bar.height + 70); break;
                case 27:
                    test.check(!widget.windowPreview.visible && !widget.windowPreview.backingWindowVisible,
                        "leaving instant card with Ctrl hides and unmaps it");
                    widget.actionOnClose = true; widget.close(); loader.x = bar.width - 100; break;
                case 28: widget.open(); break;
                case 29: test.move(test.rowPointer(), 20, 15); break;
                case 30: test.control(false); break;
                case 31:
                    test.checkPreview(true); break;
                case 32:
                    widget.actionOnClose = true; widget.close();
                    test.hidden = false; widget.windowPreview.afterHidden(function() { test.hidden = true; }); break;
                case 33:
                    test.check(!test.panel.mapped && !widget.windowPreview.backingWindowVisible && test.hidden,
                        "parent and instant preview release their surfaces before actions");
                    loader.x = 140;
                    widget.persistSettings({windowPreviews:false, popupAnimations:true, panelHoverDelay:0});
                    test.move(test.button, 20, 14); break;
                case 35:
                    test.check(test.panel.hoverOpened && test.panel.mapped, "hover restored for background toggle");
                    test.move(test.panel.body, 120, 10); break;
                case 36:
                    test.firstRow = test.list.itemAtIndex(1);
                    test.list.contentY = 120; test.scrollPosition = test.list.contentY;
                    test.cycleMaps = test.maps; test.observingCycle = true;
                    events.mouseClick(test.panel.body, 120, 10, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(test.panel.opened, "background expands through Widget.open"); break;
                case 38:
                    test.check(test.panel.body.searchField.activeFocus, "background expansion focuses search");
                    events.mouseClick(test.panel.body, 120, 10, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(test.panel.hoverOpened && !test.panel.opened, "background collapses to hover"); break;
                case 40:
                    test.check(test.panel.hoverOpened && test.panel.expansion === 0 && !api.activePopout,
                        "collapse releases bar ownership without closing the panel");
                    test.check(test.panel.surface.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None,
                        "collapse releases keyboard focus");
                    events.mouseClick(test.panel.body, 120, 10, Qt.LeftButton, Qt.NoModifier, 0); break;
                case 42:
                    test.observingCycle = false;
                    test.check(test.cycleFrames > 3 && test.panel.opened, "repeated background toggle is stable across rendered frames");
                    test.panel.body.searchField.text = "Fictional";
                    break;
                case 43:
                    events.mouseClick(test.panel.body, 120, 10, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(test.panel.hoverOpened && test.panel.body.searchField.text === "", "collapse clears hidden search filter"); break;
                case 45:
                    widget.persistSettings({openOnHover:false}); break;
                case 47:
                    test.check(!test.panel.mapped && !widget.canShowTooltip, "disabling hover closes the passive panel");
                    test.move(test.button, 20, 14); break;
                case 49:
                    test.check(!test.panel.mapped && !widget.tooltipReady, "click-only mode ignores bar hover even with zero delay");
                    test.button.triggerPress(Qt.LeftButton);
                    test.move(test.panel.body, 120, 10); break;
                case 51:
                    test.check(test.panel.opened && test.panel.expansion === 1, "bar click opens full panel in click-only mode");
                    events.mouseClick(test.panel.body, 120, 10, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(test.panel.opened && !test.panel.hoverOpened, "click-only mode cannot collapse via background");
                    widget.persistSettings({openOnHover:true});
                    test.panel.body.showSettings();
                    events.mouseClick(test.panel.body, 120, 10, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(test.panel.opened && test.panel.body.mode === "settings", "settings background is neutral");
                    test.panel.body.back(); test.panel.body.openMove("0x1");
                    events.mouseClick(test.panel.body, 120, 10, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(test.panel.opened && test.panel.body.mode === "move", "move background is neutral");
                    test.panel.body.back(); widget.actionOnClose = true; widget.close(); break;
                case 54:
                    test.check(!test.panel.mapped, "final close unmaps");
                    widget.persistSettings({panelHoverDelay:400, popupAnimations:true});
                    test.move(test.button, 20, 14); break;
                case 57:
                    test.check(test.panel.hoverOpened, "normal hover returns before bar-close test");
                    test.clickBar(); break;
                case 59:
                    test.check(test.panel.opened, "bar click expands the passive panel");
                    test.clickBar();
                    test.check(!test.panel.opened && widget.hoverDismissed, "forwarded bar click suppresses hover before closing");
                    break;
                case 64:
                    test.check(!test.panel.mapped && !widget.tooltipReady && widget.hoverDismissed,
                        "staying on the bar cannot reopen after the full delay");
                    test.clickBar(); break;
                case 66:
                    test.check(test.panel.opened, "explicit click still opens while hover is suppressed");
                    test.clickBar(); break;
                case 68:
                    test.check(!test.panel.mapped, "explicit second close remains closed");
                    test.move(bar.contentItem, bar.width - 30, 70); break;
                case 69:
                    test.check(!widget.hoverDismissed, "leaving the label releases suppression");
                    widget.persistSettings({panelHoverDelay:0, popupAnimations:false});
                    test.move(test.button, 20, 14); break;
                case 70:
                    test.check(test.panel.hoverOpened, "reentry opens instant hover normally");
                    test.clickBar(); break;
                case 72:
                    test.clickBar(); break;
                case 74:
                    test.check(!test.panel.mapped && !widget.tooltipReady && widget.hoverDismissed,
                        "zero delay and no fade cannot reopen after bar close");
                    test.move(bar.contentItem, bar.width - 30, 70); break;
                case 75:
                    test.check(!widget.hoverDismissed, "instant mode also releases on exit");
                    test.move(test.button, 20, 14); break;
                case 76:
                    test.check(test.panel.hoverOpened, "instant hover returns after leaving and reentering");
                    widget.actionOnClose = true; widget.close();
                    test.move(bar.contentItem, bar.width - 30, 70); break;
                case 78:
                    test.check(!test.panel.mapped, "final bar-close cleanup unmaps");
                    console.info("WINDOWPEEK_TEST_PASS: delays, preview, background, click-only and bar-close suppression");
                    stop(); Qt.quit();
                }
            } catch (error) { test.fail(error); }
        }
    }
}
