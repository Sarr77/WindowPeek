import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin

// Sample painted border pixels while the content moves. A property-only check
// cannot detect a drawing defect, or accidentally replacing a fade with a jump.
ShellRoot {
    id: test
    property int step: 0
    property int intermediateFrames: 0
    property int previousRed: -1
    property int selectedRed: -1
    property int restingRed: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(value, message) { if (!value) throw new Error(message); }
    TestCase { id: pixels; when: false; name: "BorderPixels" }
    Window {
        id: window
        title: "WindowPeek fictional border test"
        visible: true; width: 300 * test.scale; height: 190 * test.scale
        color: Color.popups.background
        Rectangle {
            id: canvas
            width: 300; height: 190
            scale: test.scale; transformOrigin: Item.TopLeft
            color: Color.popups.background
            Flickable {
                id: scroll; anchors.fill: parent; contentHeight: 400
                clip: true; pixelAligned: true; boundsBehavior: Flickable.StopAtBounds
                Plugin.RowSurface { id: target; x: 16; y: 100; width: 120; height: 54; accent: "#ef98f5" }
                Plugin.RowSurface { id: selection; x: 160; y: 100; width: 120; height: 54; accent: "#ef98f5"; selected: true }
            }
        }
    }
    function borderRed(snapshot, row) {
        var p = row.mapToItem(window.contentItem, 0.5, row.height / 2);
        var factor = snapshot.width / window.contentItem.width;
        return snapshot.red(Math.floor(p.x * factor), Math.floor(p.y * factor));
    }
    Timer {
        interval: 30; running: true; repeat: true
        onTriggered: {
            try {
                if (test.step < 8) { test.step++; return; }
                scroll.contentY = (test.step * 3) % 60;
                var snapshot = pixels.grabImage(window.contentItem);
                var red = test.borderRed(snapshot, target);
                var selected = test.borderRed(snapshot, selection);
                test.check(selected >= 230, "selected outline stays fully visible: red=" + selected);
                if (test.selectedRed < 0) test.selectedRed = selected;
                test.check(Math.abs(selected - test.selectedRed) <= 2,
                    "selected border changes brightness while moving: " + test.selectedRed + " -> " + selected);
                if (test.step === 8) { test.restingRed = red; target.hovered = true; }
                if (test.step > 8 && test.step < 17) {
                    test.check(red >= test.previousRed - 2, "painted hover fade-in reverses while scrolling");
                    if (red > test.restingRed + 5 && red < 180) test.intermediateFrames++;
                }
                if (test.step === 17) {
                    test.check(red > test.restingRed + 80, "accent outline is visible at full hover");
                    test.check(test.intermediateFrames >= 2, "border must actually fade, not switch instantly");
                    target.hovered = false;
                }
                if (test.step > 17 && test.step < 26)
                    test.check(red <= test.previousRed + 2, "painted hover fade-out reverses while scrolling");
                if (test.step === 26) {
                    test.check(Math.abs(red - test.restingRed) <= 2, "resting outline returns after fade-out");
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
                test.previousRed = red;
                test.step++;
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
