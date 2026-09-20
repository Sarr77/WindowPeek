import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import qs.Ui as Ui
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

// Native fixture: only fictional windows are ever passed to the capture API.
ShellRoot {
    id: fixture
    readonly property bool nativePointer: Quickshell.env("WINDOWPEEK_TEST_POINTER") === "1"
    property string surface: "panel"
    property string sourceColor: "#28b4c8"
    property bool sourceVisible: false
    property bool siblingVisible: false
    property int sourceFrames: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    property var panel: null
    property var overview: null
    property var promotionOwner: null
    property var promotionCapture: null
    function find(item, name, seen) {
        if (!item) return null;
        seen = seen || [];
        if (seen.indexOf(item) >= 0) return null;
        seen.push(item);
        if (item.objectName === name) return item;
        var children = [];
        if (item.data) for (var i=0; i<item.data.length; ++i) children.push(item.data[i]);
        if (item.children) for (var j=0; j<item.children.length; ++j) children.push(item.children[j]);
        if (item.contentItem) children.push(item.contentItem);
        for (var k=0; k<children.length; ++k) {
            var result = find(children[k], name, seen);
            if (result) return result;
        }
        return null;
    }
    function target() { return find(surface === "panel" ? panel : overview, "windowFocusPointer"); }
    function rowTarget() { return find(target().parent, "windowPreviewTarget"); }
    function list() { return find(surface === "panel" ? panel : overview, "windowList"); }
    function rowPointers(item) {
        var result = [];
        if (item.objectName === "windowFocusPointer") result.push(item);
        for (var i = 0; i < item.children.length; ++i) result = result.concat(rowPointers(item.children[i]));
        return result;
    }
    function isolateHover(item) {
        if (!fixture.nativePointer && (item.objectName === "windowFocusPointer"))
            item.hoverEnabled = false;
        for (var i = 0; i < item.children.length; ++i) isolateHover(item.children[i]);
    }
    TestEvent { id: events }
    TestCase { id: pixels; name: "CapturePixels"; when: false }
    FakeHost {
        id: host
        windowPreview: thumbnail
        opened: plugin.opened
        bar: barApi
        function panelClosed() { thumbnail.dismiss(); cancelAppearance(); }
        settings: ({hintsMode: "on", hintsUsed: 0,
            popupAnimations: !Quickshell.env("WINDOWPEEK_TEST_INSTANT"),
            previewHoverDelay: Quickshell.env("WINDOWPEEK_TEST_INSTANT") ? 0 : 400})
        language: "pl"
        Component.onCompleted: savedAppearance = Appearance.normalize({uiScale: fixture.scale})
    }
    Window {
        id: source
        title: Quickshell.env("WINDOWPEEK_CAPTURE_ID")
        visible: fixture.sourceVisible; width: 640; height: 400; color: fixture.sourceColor
        Rectangle { x: 24; y: 24; width: 180; height: 46; radius: 6; color: "#202437"
            Text { anchors.centerIn: parent; text: "Fictional document"; color: "white"; font.pixelSize: 17 }
        }
        Column { x: 24; y: 95; spacing: 12
            Repeater { model: 4; Rectangle { required property int index; width: 220 - index * 25; height: 8; color: "#ffffff"; opacity: 0.6 } }
        }
    }
    Connections { target: source; function onFrameSwapped() { fixture.sourceFrames++; } }
    Window {
        title: Quickshell.env("WINDOWPEEK_CAPTURE_ID") + "-sibling"
        visible: fixture.siblingVisible; width: 300; height: 200; color: "#ed6688"
    }
    Ui.PluginBarApi {
        id: barApi
        pluginId: "sarr.windowpeek.capture.test"; position: "top"; barSize: 28
        _requestPopout: function(owner) { activePopout = owner; }
        _releasePopout: function(owner) { if (activePopout === owner) activePopout = null; }
    }
    PanelWindow {
        id: bar
        screen: Quickshell.screens.find(function(s) { return s.name === Quickshell.env("WINDOWPEEK_TEST_SCREEN"); }) || Quickshell.screens[0]
        anchors { top: true; left: true; right: true }
        implicitHeight: 28; color: "transparent"; exclusionMode: ExclusionMode.Ignore
        Item { id: anchor; x: 100; width: 130; height: 28 }
    }
    Plugin.Panel { id: plugin; bar: barApi; anchorItem: anchor; hostWidget: host }
    Plugin.WindowThumbnail { id: thumbnail; hostWidget: host }
    IpcHandler {
        target: "windowpeek-capture-test"
        function ping(): bool { return true; }
        function createSources(): void { fixture.sourceVisible = true; fixture.siblingVisible = true; }
        function configure(address: string): void {
            fixture.panel = fixture.find(plugin, "windowPeekContent");
            fixture.overview = plugin.body;
            var clients = [];
            for (var i = 0; i < 24; ++i) clients.push({address: i ? "0xffffffffffff00" + (i+100).toString(16) : address,
                class: "org.example.Notes", app: "Notes", title: i ? "Fictional document " + (i+1)
                    : "Fictional document — workspace navigation and thumbnail layout review, with further details beyond the second line",
                workspace: {id:1,name:"1"}});
            host.snapshot = {clients: clients, workspaces: [{id:1,name:"1",monitorID:0}],
                monitors:[{id:0,name:"TEST",activeWorkspace:{id:1}}], activeAddress:address};
            panel.begin();
        }
        function showSurface(value: string): void {
            thumbnail.dismiss(); fixture.surface = value;
            if (value === "panel") { plugin.dismissHover(); plugin.hoverRequested = false; plugin.open(); panel.begin(); fixture.list().contentY = 0; }
            else { plugin.close(); plugin.hoverRequested = false; plugin.hoverRequested = true; overview.resetScroll(); }
            fixture.isolateHover(panel); fixture.isolateHover(overview);
        }
        function hover(): void {
            // Drive row hover state independently of the user's physical mouse.
            if (fixture.surface === "hover") plugin.hoverRequested = true;
            if (!fixture.nativePointer) fixture.rowTarget().requested = true;
        }
        function hoverRow(index: int): string {
            var pointers = fixture.rowPointers(fixture.list());
            pointers.forEach(function(pointer) { pointer.hoverEnabled = true; });
            var pointer = pointers[index];
            // Manual capture scenarios override requested. Restore pointer
            // ownership before returning to real Qt hover transitions.
            var previewTarget = fixture.find(pointer.parent, "windowPreviewTarget");
            previewTarget.requested = Qt.binding(function() {
                return pointer.containsMouse && pointer.enabled && pointer.visible;
            });
            events.mouseMove(pointer, pointer.width / 2, pointer.height / 2, 0, Qt.NoButton, Qt.NoModifier);
            return fixture.find(pointer.parent, "windowPreviewTarget").address;
        }
        function exitSurface(): void {
            var view = fixture.surface === "panel" ? panel : overview;
            var scene = view.Window.window.contentItem;
            if (fixture.surface === "panel") events.mouseMove(scene, 0, scene.height - 1, 0, Qt.NoButton, Qt.NoModifier);
            else events.mouseMove(scene, scene.width + 30, scene.height + 30, 0, Qt.NoButton, Qt.NoModifier);
            var card = fixture.find(thumbnail.contentItem, "windowThumbnailPointer");
            events.mouseMove(card, card.width + 30, card.height + 30, 0, Qt.NoButton, Qt.NoModifier);
            plugin.hoverRequested = false;
        }
        function leave(): void {
            if (fixture.nativePointer) return;
            fixture.rowTarget().requested = false;
            events.mouseMove(fixture.surface === "panel" ? panel : overview, -50, -50, 0, Qt.NoButton, Qt.NoModifier);
            var card = fixture.find(thumbnail.contentItem, "windowThumbnailPointer");
            events.mouseMove(card, -50, -50, 0, Qt.NoButton, Qt.NoModifier);
        }
        function crossToCard(): void {
            if (fixture.nativePointer) { if (fixture.surface === "hover") plugin.hoverRequested = false; return; }
            fixture.rowTarget().requested = false;
            events.mouseMove(fixture.surface === "panel" ? panel : overview, -10, -10, 0, Qt.NoButton, Qt.NoModifier);
            var card = fixture.find(thumbnail.contentItem, "windowThumbnailPointer");
            events.mouseMove(card, card.width / 2, card.height / 2, 0, Qt.NoButton, Qt.NoModifier);
            if (fixture.surface === "hover") plugin.hoverRequested = false;
        }
        function cardClick(control: bool): void {
            host.focused = ""; host.brought = "";
            var card = fixture.find(thumbnail.contentItem, "windowThumbnailPointer");
            events.mouseClick(card, card.width / 2, card.height / 2, Qt.LeftButton, control ? (Qt.ControlModifier | Qt.ShiftModifier) : Qt.NoModifier, 0);
        }
        function pauseInGap(): void {
            fixture.rowTarget().requested = false;
            var view = fixture.surface === "panel" ? panel : overview;
            events.mouseMove(view, -30, -30, 0, Qt.NoButton, Qt.NoModifier);
            var region = fixture.find(thumbnail.contentItem, "windowThumbnailHandoff");
            var card = fixture.find(thumbnail.contentItem, "windowThumbnailCard");
            var right = card.mapToGlobal(0,0).x > thumbnail.boundsItem.mapToGlobal(0,0).x;
            var x = right ? thumbnail.bridgeWidth / 2 : region.width - thumbnail.bridgeWidth / 2;
            var y = region.height / 2;
            events.mouseMove(region, x, y, 0, Qt.NoButton, Qt.NoModifier);
            host.focused = ""; host.brought = "";
            events.mouseClick(region, x, y, Qt.LeftButton, Qt.NoModifier, 0);
            if (fixture.surface === "hover") plugin.hoverRequested = false;
        }
        function pointerPoint(which: string): string {
            var item = which === "card" ? fixture.find(thumbnail.contentItem,"windowThumbnailPointer") : fixture.target();
            var p = item.mapToGlobal(item.width / 2, item.height / 2);
            if (which === "outside") p = anchor.mapToGlobal(bar.width - 40 - anchor.x, bar.screen.height - 40);
            return JSON.stringify({x:Math.round(p.x), y:Math.round(p.y)});
        }
        function edge(right: bool): void { anchor.x = right ? bar.width - 140 : 100; }
        function promote(): void {
            fixture.promotionOwner = thumbnail.anchorItem;
            fixture.promotionCapture = fixture.find(thumbnail.contentItem, "windowCaptureView");
            plugin.open(); fixture.surface = "panel";
        }
        function parentClose(): void { plugin.close(); plugin.dismissHover(); plugin.hoverRequested = false; }

        function wheel(): void {
            var row = fixture.target();
            events.mouseWheel(row, row.width / 2, row.height / 2, Qt.NoButton, Qt.NoModifier, 0, -120, 0);
        }
        function click(control: bool): void {
            var row = fixture.target();
            events.mouseClick(row, row.width / 2, row.height / 2, Qt.LeftButton, control ? (Qt.ControlModifier | Qt.ShiftModifier) : Qt.NoModifier, 0);
        }
        function changeColor(value: string): void { fixture.sourceColor = value; }
        function closeSource(): void { fixture.sourceVisible = false; }
        function hints(value: string): void { host.persistSettings({hintsMode:value,hintsUsed:99}); }
        function status(): string {
            var title = fixture.find(thumbnail.contentItem, "windowThumbnailTitle");
            return JSON.stringify({surface:fixture.surface, screen:bar.screen.name, nativePointer:fixture.nativePointer, pointerPoint:JSON.parse(pointerPoint("row")), visible:thumbnail.visible, mapped:thumbnail.backingWindowVisible,
                content:thumbnail.hasContent, address:thumbnail.address,
                promotionRetained: !!fixture.promotionOwner && thumbnail.anchorItem === fixture.promotionOwner
                    && !!fixture.promotionCapture && fixture.find(thumbnail.contentItem, "windowCaptureView") === fixture.promotionCapture,
                sourceColor:String(fixture.sourceColor), sourceFrames:fixture.sourceFrames,
                controlKnown:thumbnail.modifierState.known, controlDown:thumbnail.modifierState.controlDown,
                pointerOnCard:thumbnail.pointerOnCard,
                titleLines:title.lineCount, titleTruncated:title.truncated,
                available:thumbnail.available, owner:!!thumbnail.anchorItem, ownerWindow:!!thumbnail.anchorWindow, ready:thumbnail.ready,
                held:thumbnail.held, rowHovered:thumbnail.rowHovered,
                rowInput:fixture.rowPointers(fixture.list()).slice(0,3).map(function(p) {
                    var t = fixture.find(p.parent, "windowPreviewTarget");
                    var hint = fixture.find(p.parent, "windowFocusHint");
                    return {address:t.address, hovered:p.containsMouse, requested:t.requested, hint:!!hint && hint.visible};
                }),
                hintsUsed:host.hints.used, width:thumbnail.width, height:thumbnail.height,
                cardWidth:fixture.find(thumbnail.contentItem,"windowThumbnailCard").width * fixture.scale,
                cardHovered:thumbnail.containsPointer, parentVisible:fixture.surface === "panel" ? plugin.opened : plugin.hoverOpened,
                bounds:thumbnail.boundsRect, row:thumbnail.rowRect,
                origin:fixture.find(thumbnail.contentItem,"windowThumbnailCard").mapToGlobal(0,0),
                listOrigin:thumbnail.boundsItem ? thumbnail.boundsItem.mapToGlobal(0,0) : Qt.point(0,0),
                sceneWidth:thumbnail.anchorScene ? thumbnail.anchorScene.width : 0,
                scroll:fixture.list() ? fixture.list().contentY : -1,
                hovered:fixture.target() ? fixture.target().parent.hovered : false,
                rowRequested:fixture.rowTarget() ? fixture.rowTarget().requested : false,
                focused:host.focused, brought:host.brought});
        }
        function color(): string {
            var view = fixture.find(thumbnail.contentItem, "windowCaptureView");
            if (!view) return "";
            var snapshot = pixels.grabImage(thumbnail.contentItem);
            var point = view.mapToItem(thumbnail.contentItem, view.width * 0.75, view.height * 0.75);
            var factor = snapshot.width / thumbnail.width;
            var x = Math.floor(point.x * factor), y = Math.floor(point.y * factor);
            return JSON.stringify([snapshot.red(x,y),snapshot.green(x,y),snapshot.blue(x,y)]);
        }
        function save(path: string): void {
            fixture.find(thumbnail.contentItem, "windowThumbnailCard").grabToImage(function(image) { image.saveToFile(path); });
        }
    }
}
