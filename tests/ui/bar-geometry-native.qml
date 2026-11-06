import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "WindowPeek/vendor/omarchy" as Vendor

ShellRoot {
    id: test
    property int scenario: 0
    property int step: 0
    property int pixelChecks: 0
    readonly property var sides: ["top", "bottom", "left", "right"]
    readonly property string side: sides[scenario % 4]
    readonly property bool horizontal: side === "top" || side === "bottom"
    readonly property bool fullScreenBar: Math.floor(scenario / 4) % 2 === 1
    readonly property bool perScreenSize: Math.floor(scenario / 8) % 2 === 1
    readonly property bool centered: Math.floor(scenario / 16) % 2 === 1
    readonly property int output: Math.floor(scenario / 32)
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property real thickness: perScreenSize ? 48 : 28
    function check(ok, message) {
        if (!ok) throw new Error("scenario " + scenario + " (" + side + ", "
            + (fullScreenBar ? "full-screen" : "strip") + "): " + message);
    }
    function near(a, b, message) { check(Math.abs(a - b) < 1, message + ": " + a + " vs " + b); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var result = find(child, name); if (result) return result; }
        return null;
    }
    function checkGeometry() {
        var card = panel.cardItem;
        check(panel.backingWindowVisible && card.opacity > .99, "card rendered");
        check(card.x >= 0 && card.y >= 0 && card.x + card.width <= panel.screenW
            && card.y + card.height <= panel.screenH, "whole card must fit on the output");
        if (side === "top") near(card.y, thickness + panel.gap, "top strip clearance");
        if (side === "bottom") near(panel.screenH - card.y - card.height, thickness + panel.gap, "bottom strip clearance");
        if (side === "left") near(card.x, thickness + panel.gap, "left strip clearance");
        if (side === "right") near(panel.screenW - card.x - card.width, thickness + panel.gap, "right strip clearance");
        var bridge = panel.barBridgeBounds;
        near(horizontal ? bridge.height : bridge.width, panel.gap, "hover bridge spans just the gap");
        var input = find(panel.cardItem.Window.window.contentItem, "windowPeekBarInput");
        check(input !== null, "bar input exists");
        check(panel.fittedContentWidth(10000) <= panel.screenW - (horizontal ? 0 : thickness + panel.gap), "width cap clears strip");
        check(panel.fittedContentHeight(10000) <= panel.screenH - (horizontal ? thickness + panel.gap : 0), "height cap clears strip");
    }
    QtObject {
        id: barApi
        property string position: test.side
        property int barSize: 28
        property var activePopout: null
        property var barSizeFor: test.perScreenSize ? function(name) {
            test.check(name === bar.screen.name, "screen-specific size queried for the anchor output");
            return 48;
        } : undefined
        function requestPopout(owner) { activePopout = owner; }
        function releasePopout(owner) { if (activePopout === owner) activePopout = null; }
    }
    PanelWindow {
        id: bar
        screen: Quickshell.screens[test.output]
        anchors {
            top: test.fullScreenBar || test.side !== "bottom"
            bottom: test.fullScreenBar || test.side !== "top"
            left: test.fullScreenBar || test.side !== "right"
            right: test.fullScreenBar || test.side !== "left"
        }
        implicitWidth: test.thickness; implicitHeight: test.thickness
        color: "transparent"; exclusionMode: ExclusionMode.Ignore
        mask: Region { item: anchor }
        Rectangle {
            id: anchor
            color: "#11ee44"
            x: test.side === "right" ? bar.width - test.thickness : test.horizontal ? 150 : 0
            y: test.side === "bottom" ? bar.height - test.thickness : test.horizontal ? 0 : 150
            width: test.horizontal ? 100 : test.thickness
            height: test.horizontal ? test.thickness : 100
        }
    }
    Vendor.WindowPanel {
        id: panel
        bar: barApi; anchorItem: anchor
        centerOnBar: test.centered
        contentWidth: 320 * test.scale; contentHeight: 200 * test.scale
        gap: 12; margin: 8; animationsEnabled: false
        hoverOpen: true
        Rectangle {
            id: marker
            anchors.centerIn: parent; width: 16; height: 16; color: "#11ee44"
        }
    }
    Process {
        id: probe
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(code) {
            try {
                test.check(code === 0, "final compositor pixel check: " + stderr.text);
                test.pixelChecks++;
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); timer.stop(); Qt.quit(); }
        }
    }
    Timer {
        id: timer; interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0: break; // Allow layer configure and layout after each anchor change.
                case 1:
                    test.checkGeometry();
                    var point = marker.mapToGlobal(4, 4);
                    probe.command = ["python3", Quickshell.env("WINDOWPEEK_TEST_PIXEL_PROBE"),
                        String(Math.round(point.x)), String(Math.round(point.y))];
                    probe.running = true;
                    break;
                case 2:
                    if (probe.running) { test.step--; break; }
                    test.check(test.pixelChecks === 2 * test.scenario + 1, "card pixel check completed");
                    // Read the final output at the input proxy's coordinates.
                    // A green anchor here proves bottom/right mapping too;
                    // mapToGlobal on a strip-sized PanelWindow alone omits its
                    // compositor anchor offset and cannot establish this.
                    var input = test.find(panel.cardItem.Window.window.contentItem, "windowPeekBarInput");
                    var anchorPoint = input.mapToGlobal(input.width / 2, input.height / 2);
                    probe.command = ["python3", Quickshell.env("WINDOWPEEK_TEST_PIXEL_PROBE"),
                        String(Math.round(anchorPoint.x)), String(Math.round(anchorPoint.y))];
                    probe.running = true;
                    break;
                case 3:
                    if (probe.running) { test.step--; break; }
                    test.check(test.pixelChecks === 2 * (test.scenario + 1), "anchor pixel check completed");
                    if (test.scenario + 1 < 32 * Quickshell.screens.length) { test.scenario++; test.step = 0; }
                    else {
                        console.info("WINDOWPEEK_TEST_PASS: " + (test.scenario + 1) + " visible cards, "
                            + test.pixelChecks + " compositor pixel checks, old/new bar surfaces, four edges, centered/anchored, per-screen/fallback sizes and input mapping");
                        timer.stop(); Qt.quit();
                    }
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); timer.stop(); Qt.quit(); }
        }
    }
}
