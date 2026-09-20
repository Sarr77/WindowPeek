import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui as Ui
import "WindowPeek" as Plugin

// Native panel and keyboard routing; action dispatch is recorded, never sent to real windows.
ShellRoot {
    id: test
    property int step: -1
    property int waits: 0
    property var panel: null
    property int previewCase: 0
    property var retainedAnchor: null
    property var retainedCapture: null
    property bool watchingPreview: false
    property int previewUnmaps: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property bool compileOnly: Quickshell.env("WINDOWPEEK_TEST_COMPILE_ONLY") === "1"
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(object, name, seen) {
        if (!object || seen.indexOf(object) >= 0) return null;
        seen.push(object);
        if (object.objectName === name) return object;
        var children = [];
        if (object.data) for (var child of object.data) children.push(child);
        if (object.item) children.push(object.item);
        if (object.contentItem) children.push(object.contentItem);
        if (object.children) for (var child of object.children) children.push(child);
        for (var child of children) { var result = find(child, name, seen); if (result) return result; }
        return null;
    }
    function named(name) { return find(panel.body, name, []); }
    function clickRow(modifiers) {
        var row = named("windowFocusPointer");
        events.mouseClick(row, 15, row.height / 2, Qt.LeftButton, modifiers, 0);
    }
    function showHover() {
        panel.hoverRequested = false;
        panel.hoverRequested = true;
    }
    TestEvent { id: events }
    Rectangle {
        id: marker
        parent: test.panel ? test.panel.destinationMenu.searchField : null
        x: 80; y: 8; width: 12; height: 12
        color: "#11ee44"
        visible: test.watchingPreview
    }
    Process {
        id: pixels
        property int result: -1
        stdout: StdioCollector { onStreamFinished: console.info(text.trim()) }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) console.warn(text.trim()) }
        onExited: function(code) { result = code; }
    }
    Connections {
        target: widget.item ? widget.item.windowPreview : null
        function onBackingWindowVisibleChanged() {
            if (test.watchingPreview && !target.backingWindowVisible) test.previewUnmaps++;
        }
    }
    FakeHost { id: data }
    Plugin.WindowState { id: fictionalState; enabled: false; snapshot: data.snapshot }
    Plugin.WindowActions {
        id: actions
        state: fictionalState
        property string moved: ""
        property int brings: 0
        property int released: 0
        property int focused: 0
        function observe() {} // The fixture records dispatch, not compositor state changes.
        function move(address, destination) {
            moved = address + ":" + destination;
            Qt.callLater(function() { actions.completed("move", address); });
            return true;
        }
        function bring(address, screen, release) {
            test.check(address === "0x1" && screen === widget.item.screenName, "bring uses the invoking monitor and pressed window");
            brings++; job = {kind:"bring", address:address, phase:"record"};
            release(function() {
                test.check(!test.panel.mapped && !widget.item.windowPreview.backingWindowVisible,
                    "bring waits for both native surfaces to unmap");
                actions.released++; actions.job = null; actions.completed("bring", address);
            });
            return true;
        }
        function focus(address, release) {
            test.check(test.step === 30, "a modified click must not dispatch focus");
            focused++; release(function() {}); return true;
        }
    }
    QtObject { id: shell; function updateEntryInline(id, values) { return true; } }
    Ui.PluginBarApi {
        id: api; pluginId: "sarr.windowpeek.gestures.test"; moduleName: "sarr.windowpeek"
        position: "top"; barSize: 28; shell: shell
        layoutConfig: ({left:[{id:"sarr.windowpeek",uiScale:test.scale,autoUpdates:false,
            hintsMode:"off",windowPreviews:false,popupAnimations:true}],center:[],right:[]})
        _moduleWidgets: function() { return widget.item ? [widget.item] : []; }
        _requestPopout: function(owner) { activePopout = owner; }
        _releasePopout: function(owner) { if (activePopout === owner) activePopout = null; }
    }
    PanelWindow {
        id: bar
        visible: !test.compileOnly
        anchors { top: true; left: true; right: true }
        implicitHeight: 28; color: "transparent"; exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        Loader { id: widget; x: 140; active: false; sourceComponent: Plugin.Widget { bar: api } }
    }
    Process { id: park; onExited: function(code) { test.check(code === 0, "cursor parked"); widget.active = true; } }
    Process {
        id: pointerMover
        onExited: function(code) {
            test.check(code === 0, "cursor moved");
            pointerFrame.running = true;
        }
    }
    Process {
        id: pointerFrame
        command: [Quickshell.env("WINDOWPEEK_TEST_POINTER_FRAME")]
        onExited: function(code) { test.check(code === 0, "pointer frame delivered"); }
    }
    Process {
        id: pointerReport
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector { onStreamFinished: console.info("GESTURE_CURSOR " + text.trim()) }
    }
    function moveCursor(x, y) {
        pointerMover.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.cursor.move({x="
            + Math.round(bar.screen.x + x) + ",y=" + Math.round(bar.screen.y + y) + "}))"];
        pointerMover.running = true;
    }
    Process {
        id: keys
        property bool ready: false
        stdinEnabled: true
        stdout: SplitParser { onRead: function(line) { if (line === "pressed") keys.ready = true; } }
        onExited: { ready = false; }
    }
    function hold(control, shift) {
        check(!keys.running, "previous test keys released");
        keys.ready = false;
        keys.command = [Quickshell.env("WINDOWPEEK_TEST_KEYBOARD"), control].concat(shift ? [shift] : []);
        keys.running = true;
    }
    Component.onDestruction: keys.running = false
    Component.onCompleted: {
        var state = Plugin.Runtime.state;
        state.enabled = false; state.pending = false; state.coalesce.stop(); state.reader.running = false;
        Plugin.Runtime.state = fictionalState;
        Plugin.Runtime.actions = actions;
        if (compileOnly) Qt.callLater(function() { console.info("WINDOWPEEK_TEST_PASS: compilation only"); Qt.quit(); });
    }
    Timer {
        interval: 200; running: !test.compileOnly; repeat: true
        onTriggered: {
            try {
                var owner = widget.item;
                switch (test.step++) {
                case -1:
                    park.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.cursor.move({x="
                        + (bar.screen.x + bar.screen.width - 30) + ",y=" + (bar.screen.y + 80) + "}))"];
                    park.running = true; break;
                case 0:
                    if (!owner || !owner.settingsReady) { test.check(test.waits++ < 15, "widget ready"); test.step--; break; }
                    test.panel = test.find(owner, "windowPeekController", []);
                    test.showHover(); break;
                case 1: test.hold("Control_L"); break;
                case 2:
                    test.check(keys.ready && test.panel.hoverOpened && test.panel.mapped, "Ctrl held on hover panel");
                    test.check(test.panel.body.controlHeld && test.panel.surface.keyboardActive, "Ctrl enables hover keyboard shortcuts");
                    test.clickRow(test.named("windowFocusPointer").needsCompositor ? Qt.NoModifier : Qt.ControlModifier); break;
                case 4:
                    test.check(test.panel.destinationMenu.opened && !test.panel.opened && test.panel.body.mode === "windows",
                        "real Ctrl opens a small menu without expanding");
                    test.check(!actions.moved && !actions.brings && !actions.focused, "opening menu cannot act on a window");
                    keys.running = false; break;
                case 5: events.keyClick(Qt.Key_4, Qt.NoModifier, 0); break;
                case 6:
                    test.check(test.panel.destinationMenu.filtered.length === 1, "small menu has keyboard focus");
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 0); break;
                case 7:
                    test.check(actions.moved === "0x1:4" && !test.panel.destinationMenu.opened && test.panel.hoverOpened,
                        "choosing a workspace moves and returns to hover");
                    owner.open(); break;
                case 9: test.clickRow(Qt.ControlModifier); break;
                case 10:
                    test.check(test.panel.destinationMenu.opened && test.panel.opened && test.panel.body.mode === "windows",
                        "expanded panel uses the same small menu");
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0); break;
                case 11:
                    test.check(!test.panel.destinationMenu.opened && test.panel.opened, "Escape keeps the expanded list");
                    test.clickRow(Qt.ControlModifier | Qt.ShiftModifier); break;
                case 14:
                    test.check(actions.brings === 1 && actions.released === 1 && !test.panel.mapped, "expanded bring releases surfaces");
                    test.showHover(); break;
                case 15: test.hold("Control_R", "Shift_R"); break;
                case 16:
                    test.check(keys.ready && test.panel.body.controlHeld, "right Ctrl+Shift on hover");
                    test.clickRow(test.named("windowFocusPointer").needsCompositor ? Qt.NoModifier
                        : Qt.ControlModifier | Qt.ShiftModifier); break;
                case 19:
                    test.check(actions.brings === 2 && actions.released === 2 && !test.panel.mapped, "physical Ctrl+Shift brings from hover");
                    keys.running = false; test.showHover(); break;
                case 21: test.hold("Control_R"); break;
                case 22:
                    test.check(keys.ready, "right Ctrl ready");
                    test.clickRow(test.named("windowFocusPointer").needsCompositor ? Qt.NoModifier : Qt.ControlModifier); break;
                case 24:
                    test.check(test.panel.destinationMenu.opened && test.panel.hoverOpened, "right Ctrl alone also opens the small menu");
                    keys.running = false; break;
                case 25:
                    var menu = test.panel.destinationMenu;
                    events.mouseClick(menu, menu.width - 4, menu.height - 4, Qt.LeftButton, Qt.NoModifier, 0); break;
                case 27:
                    test.check(test.panel.hoverOpened && !test.panel.destinationMenu.opened, "outside click closes only the small menu"); break;
                case 29: test.clickRow(Qt.NoModifier); break;
                case 32:
                    test.check(actions.focused === 1 && !test.panel.mapped, "released modifiers cannot stick to the next plain click");
                    owner.persistSettings({windowPreviews:true}); test.showHover(); break;
                case 33:
                    var row = test.named("windowFocusPointer");
                    var point = row.mapToItem(null, 15, row.height / 2);
                    test.moveCursor(point.x, point.y); break;
                case 37:
                    if (!owner.windowPreview.visible) { test.check(test.waits++ < 25, "preview ready"); test.step--; break; }
                    var card = test.find(owner.windowPreview.contentItem, "windowThumbnailPointer", []);
                    var point = owner.windowPreview.menuPosition(Qt.point(card.width / 2, card.height / 2));
                    test.moveCursor(point.x, point.y); break;
                case 38:
                    console.info("PREVIEW_BEFORE_CTRL " + JSON.stringify({visible: owner.windowPreview.visible,
                        pointer: owner.windowPreview.pointerOnCard, keyboard: test.panel.surface.keyboardActive}));
                    test.hold("Control_L"); break;
                case 39:
                    test.check(keys.ready && owner.windowPreview.visible && owner.windowPreview.pointerOnCard,
                        "Ctrl keeps hovered preview clickable: " + JSON.stringify({keys: keys.ready,
                            visible: owner.windowPreview.visible, pointer: owner.windowPreview.pointerOnCard,
                            shiftKnown: owner.windowPreview.modifierState.known,
                            shiftDown: owner.windowPreview.modifierState.shiftDown,
                            keyboard: test.panel.surface.keyboardActive}));
                    test.retainedAnchor = owner.windowPreview.anchorItem;
                    test.retainedCapture = test.find(owner.windowPreview.contentItem, "windowThumbnailCapture", []).item;
                    test.check(!!test.retainedCapture, "capture exists before opening the move menu");
                    test.previewUnmaps = 0; test.watchingPreview = true;
                    var card = test.find(owner.windowPreview.contentItem, "windowThumbnailPointer", []);
                    // A focused preview receives native Qt modifiers; only a
                    // passive surface needs the compositor fallback under test.
                    events.mouseClick(card, card.width / 2, card.height / 2, Qt.LeftButton,
                        card.needsCompositor ? Qt.NoModifier : Qt.ControlModifier, 0); break;
                case 40:
                    if (Quickshell.env("WINDOWPEEK_TEST_OVERLAY_MENU") === "1") test.panel.menuNeedsPopup = false;
                    break;
                case 42:
                    test.check(test.panel.destinationMenu.opened && owner.windowPreview.visible && owner.windowPreview.backingWindowVisible
                        && owner.windowPreview.menuRetained && owner.windowPreview.anchorItem === test.retainedAnchor,
                        "preview Ctrl+click keeps its original preview mapped while choosing");
                    test.check(test.previewCase % 2 ? test.panel.opened : test.panel.hoverOpened, "chooser keeps the list mode");
                    var menu = test.panel.destinationMenu;
                    menu.searchField.hoverEnabled = true;
                    var point = menu.searchField.mapToItem(menu, 12, menu.searchField.height / 2);
                    console.info("GESTURE_TARGET " + JSON.stringify({
                        scale: test.scale, screen: bar.screen.name, screenX: bar.screen.x, screenY: bar.screen.y,
                        localX: point.x, localY: point.y,
                        global: menu.searchField.mapToGlobal(12, menu.searchField.height / 2),
                        menuWindowX: menu.window.x, menuWindowY: menu.window.y,
                        previewScreen: owner.windowPreview.anchorWindow.screen.name
                    }));
                    test.moveCursor(point.x * test.scale, point.y * test.scale);
                    var sample = marker.mapToItem(menu, 4, 4);
                    var origin = owner.windowPreview.menuPosition(Qt.point(0, 0));
                    var previewCard = test.find(owner.windowPreview.contentItem, "windowThumbnailPointer", []);
                    var sx = sample.x * test.scale, sy = sample.y * test.scale;
                    test.check(sx > origin.x && sx + 4 < origin.x + previewCard.width * test.scale
                        && sy > origin.y && sy + 4 < origin.y + previewCard.height * test.scale,
                        "pixel probe must overlap both menu and preview");
                    pixels.result = -1;
                    pixels.command = ["python3", Quickshell.env("WINDOWPEEK_TEST_PIXEL_PROBE"),
                        String(Math.round(bar.screen.x + sx)), String(Math.round(bar.screen.y + sy))];
                    pixels.running = true;
                    break;
                case 44: pointerReport.running = true; break;
                case 45:
                    test.check(pixels.result === 0, "move menu is visibly above the retained preview");
                    test.check(test.panel.destinationMenu.searchField.hovered, "native pointer reaches the menu above the retained preview");
                    test.check(test.panel.destinationMenu.searchField.activeFocus, "retained preview menu owns keyboard focus");
                    events.keyClick(Qt.Key_4, Qt.NoModifier, 0);
                    test.check(test.panel.destinationMenu.searchField.text === "4", "keyboard input reaches the menu's popup host");
                    test.panel.destinationMenu.searchField.text = "";
                    test.check(owner.windowPreview.visible && owner.windowPreview.address === "0x1", "Ctrl does not hide the preview beneath its menu");
                    test.check(!test.previewUnmaps && test.retainedCapture === test.find(owner.windowPreview.contentItem, "windowThumbnailCapture", []).item,
                        "opening and using the menu never unmaps or restarts the capture");
                    test.watchingPreview = false;
                    events.mouseClick(test.panel.destinationMenu.searchField, 12, 12, Qt.RightButton, Qt.NoModifier, 0);
                    keys.running = false;
                    break;
                case 46:
                    test.check(!test.panel.destinationMenu.opened && !owner.windowPreview.menuRetained, "right click cancels the menu and releases retention");
                    test.moveCursor(bar.screen.width - 30, 80);
                    owner.actionOnClose = true;
                    var row = test.named("windowFocusPointer");
                    events.mouseClick(row, 15, row.height / 2, Qt.RightButton, Qt.NoModifier, 0); break;
                case 49:
                    test.check(!test.panel.mapped && !owner.windowPreview.backingWindowVisible && !keys.running,
                        "right-click on the main list closes the panel and preview in either mode");
                    if (++test.previewCase < 4) {
                        owner.persistSettings({popupAnimations: test.previewCase < 2});
                        if (test.previewCase % 2) owner.open(); else test.showHover();
                        test.waits = 0; test.step = 33; break;
                    }
                    console.info("WINDOWPEEK_TEST_PASS: real modifiers, menu in both views, retained native previews with and without animations, right-click Back, bring and release");
                    stop(); Qt.quit();

                }
            } catch (error) { keys.running = false; console.error("WINDOWPEEK_TEST_FAIL at step " + (test.step - 1) + ": " + error); stop(); Qt.quit(); }
        }
    }
}
