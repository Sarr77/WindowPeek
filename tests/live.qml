import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import qs.Ui as Ui
import "WindowPeek" as Plugin

ShellRoot {
    id: fixture
    property string clickAddress: ""
    property bool clickDelivered: false
    property bool ctrlClick: false
    property bool clickPanel: false
    property var heldApply: null
    property var hover: null
    property var shortcutDiagnostic: null
    function find(object, name, address, seen) {
        if (!object || seen.indexOf(object) >= 0) return null;
        seen.push(object);
        if (object.objectName === name && (!address
            || (object.parent.modelData && object.parent.modelData.address === address)
            || (object.parent.parent.window && object.parent.parent.window.address === address))) return object;
        var children = [];
        if (object.body) children.push(object.body);
        if (object.contentItem) children.push(object.contentItem);
        if (object.item) children.push(object.item);
        if (object.children) for (var j = 0; j < object.children.length; j++) children.push(object.children[j]);
        for (var k = 0; k < children.length; k++) {
            var found = find(children[k], name, address, seen);
            if (found) return found;
        }
        return null;
    }
    Plugin.WindowState { id: state }
    Plugin.WindowActions { id: actions; state: state }
    TestEvent { id: events }
    QtObject { id: fakeShell; function updateEntryInline(id, values) { return true; } }
    Ui.PluginBarApi {
        id: bar; pluginId: "sarr.windowpeek"; moduleName: "sarr.windowpeek"
        shell: fakeShell; position: "top"; barSize: 28
        layoutConfig: ({left:[{id:"sarr.windowpeek", hintsMode:"off", includeSpecial:true}], center:[], right:[]})
        _moduleWidgets: function() { return [widget]; }
        _requestPopout: function(owner) { activePopout = owner; }
        _releasePopout: function(owner) { if (activePopout === owner) activePopout = null; }
    }
    PanelWindow {
        id: testBar
        anchors { top: true; left: true; right: true }
        implicitHeight: 28; color: "transparent"; exclusionMode: ExclusionMode.Ignore
        Plugin.Widget { id: widget; bar: bar; x: 100 }
    }
    Timer {
        id: click; interval: 100
        onTriggered: {
            var surface = fixture.clickPanel ? widget : fixture.hover;
            var row = fixture.find(surface, "windowFocusPointer", fixture.clickAddress, []);
            var list = fixture.find(surface, "windowList", "", []);
            if (!row || !list) return;
            list.contentY = Math.max(0, Math.min(list.contentHeight - list.height, row.mapToItem(list.contentItem, 0, 0).y));
            fixture.clickDelivered = events.mouseClick(row, row.width / 2, row.height / 2, Qt.LeftButton,
                fixture.ctrlClick ? (Qt.ControlModifier | Qt.ShiftModifier) : Qt.NoModifier, 0);
        }
    }
    IpcHandler {
        id: ipc
        target: "windowpeek-test"
        function status(): string {
            var panel = fixture.find(widget, "windowPeekController", "", []);
            return JSON.stringify({ ready: state.ready && widget.settingsReady, revision: state.revision, busy: actions.busy, error: actions.error,
                hoverVisible: fixture.hover ? fixture.hover.mapped : false,
                hoverBusy: click.running || widget.actionBusy, hoverError: widget.actionError,
                hoverClickDelivered: fixture.clickDelivered, panelOpen: widget.opened, screen: widget.screenName,
                panelFound: !!panel, panelMapped: !!panel && panel.mapped,
                searchFocused: !!panel && panel.body.searchField.activeFocus,
                shortcutControl: !!panel && panel.body.controlHeld,
                shortcutKeyboard: !!panel && panel.surface.keyboardActive,
                shortcutFocused: !!panel && panel.body.activeFocus,
                shortcutSurfaceActive: !!panel && !!panel.body.Window.window && panel.body.Window.window.active,
                previewSurfaceActive: !!widget.windowPreview.contentItem.Window.window
                    && widget.windowPreview.contentItem.Window.window.active,
                hoverMode: !!panel && panel.hoverOpened,
                previewVisible: widget.windowPreview.visible,
                shortcutDiagnostic: fixture.shortcutDiagnostic,
                held: fixture.heldApply !== null });
        }
        function isTestWindow(address: string): bool {
            return state.ready && state.snapshot.clients.some(function(w) {
                return w.address === address && w.class.indexOf("windowpeek-test-") === 0;
            });
        }
        function focus(address: string): bool { return isTestWindow(address) && actions.focus(address, null); }
        function move(address: string, destination: string): bool { return isTestWindow(address) && actions.move(address, destination); }
        function bring(address: string, monitorName: string): bool { return isTestWindow(address) && actions.bring(address, monitorName, null); }
        function holdBring(address: string, monitorName: string): bool {
            return isTestWindow(address) && actions.bring(address, monitorName, function(ready) { fixture.heldApply = ready; });
        }
        function releaseBring(): void { var ready = fixture.heldApply; fixture.heldApply = null; if (ready) ready(); }
        function selectMonitor(name: string): bool {
            var screen = Quickshell.screens.find(function(item) { return item.name === name; });
            if (!screen || widget.opened) return false;
            testBar.screen = screen; return true;
        }
        function panelOpen(): void { widget.open(); }
        function panelClose(): void { widget.close(); }
        function shortcutFilter(): bool {
            var panel = fixture.find(widget, "windowPeekController", "", []);
            if (!panel || (!widget.opened && !panel.hoverOpened) || !panel.mapped) return false;
            panel.body.searchField.text = "WindowPeek-Test-";
            if (widget.opened) panel.body.searchField.forceActiveFocus();
            return true;
        }
        function shortcutDigit(address: string): string {
            var panel = fixture.find(widget, "windowPeekController", "", []);
            if (!panel) return "";
            var list = fixture.find(panel.body, "windowList", "", []);
            var row = list.rows.findIndex(function(item) { return item.kind === "window" && item.address === address; });
            fixture.shortcutDiagnostic = { control: panel.body.controlHeld, focused: panel.body.activeFocus,
                testWindow: ipc.isTestWindow(address), row: row, count: list.rows.length,
                visible: list.visible, height: list.height, opened: list.opened, hints: list.showShortcuts };
            if (!panel.body.controlHeld || !panel.body.activeFocus || !ipc.isTestWindow(address)) return "";
            if (row < 0) return "";
            list.ensureRowVisible(row);
            var index = list.shortcutAddresses.indexOf(address);
            var label = fixture.find(list.itemAtIndex(row), "windowShortcutLabel", "", []);
            var digit = String((index + 1) % 10);
            fixture.shortcutDiagnostic = Object.assign({}, fixture.shortcutDiagnostic,
                {index: index, label: !!label, labelVisible: !!label && label.visible,
                    labelMatches: !!label && label.text === digit});
            return index >= 0 && index < 10 && label && label.visible && label.text === digit ? digit : "";
        }
        function shortcutHoverPoint(address: string): string {
            if (!ipc.isTestWindow(address)) return "";
            var panel = fixture.find(widget, "windowPeekController", "", []);
            if (!panel || !panel.mapped) return "";
            var list = fixture.find(panel.body, "windowList", "", []);
            var row = list.rows.findIndex(function(item) { return item.kind === "window" && item.address === address; });
            if (row < 0) return "";
            list.ensureRowVisible(row);
            var pointer = fixture.find(list.itemAtIndex(row), "windowFocusPointer", "", []);
            if (!pointer) return "";
            var point = pointer.mapToItem(null, pointer.width / 2, pointer.height / 2);
            return JSON.stringify({x: panel.surface.screen.x + point.x, y: panel.surface.screen.y + point.y});
        }
        function windowShortcut(address: string): bool {
            var panel = fixture.find(widget, "windowPeekController", "", []);
            if (!panel || !widget.opened || !panel.body.searchField.activeFocus) return false;
            var list = fixture.find(panel.body, "windowList", "", []);
            if (!list || !ipc.isTestWindow(address)) return false;
            var row = list.rows.findIndex(function(item) { return item.kind === "window" && item.address === address; });
            if (row < 0) return false;
            list.ensureRowVisible(row);
            var index = list.visibleWindowAddresses().indexOf(address);
            if (index < 0 || index > 9 || !ipc.isTestWindow(address)) return false;
            events.keyPress(Qt.Key_Control, Qt.NoModifier, 0);
            if (!panel.body.controlHeld || list.shortcutAddresses[index] !== address) return false;
            events.keyClick(index === 9 ? Qt.Key_0 : Qt.Key_1 + index, Qt.ControlModifier, 0);
            events.keyRelease(Qt.Key_Control, Qt.NoModifier, 0);
            return true;
        }
        function shortcutScale(value: real): bool { return !widget.opened && widget.persistSettings({uiScale: value}); }
        function panelBringClick(address: string): bool {
            if (!isTestWindow(address) || !widget.opened) return false;
            if (!fixture.find(widget, "windowFocusPointer", address, [])) return false;
            fixture.clickPanel = true; fixture.ctrlClick = true;
            fixture.clickAddress = address; fixture.clickDelivered = false; click.restart(); return true;
        }
        function refresh(): void { state.refresh(); }
        function hoverOpen(): void {
            fixture.hover = fixture.find(widget, "windowPeekController", "", []);
            fixture.hover.hoverRequested = false;
            fixture.hover.hoverRequested = true;
        }
        function hoverClick(address: string): bool {
            if (!isTestWindow(address) || !fixture.hover || !fixture.hover.mapped) return false;
            var row = fixture.find(fixture.hover, "windowFocusPointer", address, []);
            var list = fixture.find(fixture.hover, "windowList", "", []);
            if (!row || !list) return false;
            list.contentY = Math.max(0, Math.min(list.contentHeight - list.height, row.mapToItem(list.contentItem, 0, 0).y));
            fixture.clickAddress = address;
            fixture.clickPanel = false; fixture.ctrlClick = false;
            fixture.clickDelivered = false;
            click.restart();
            return true;
        }
        function hoverBringClick(address: string): bool {
            if (!hoverClick(address)) return false;
            fixture.ctrlClick = true; return true;
        }
    }
}
