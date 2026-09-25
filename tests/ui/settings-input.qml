import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property real nativeDistance: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    function named(name) { return find(panel, name); }
    function click(item) {
        if (item.objectName !== "settingsButton") panel.ensureVisible(item);
        var point = item.mapToItem(window.contentItem, item.width / 2, item.height / 2);
        check(point.x >= 0 && point.y >= 0 && point.x < window.width && point.y < window.height,
            "click target is inside the actual window: " + item.objectName);
        events.mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
    }
    function wheel(item, delta) { events.mouseWheel(item, 40, 80, Qt.NoButton, Qt.NoModifier, 0, delta || -120, 0); }
    function key(key) { check(events.keyClick(key, Qt.NoModifier, 0), "keyboard event delivered to fixture"); }
    function measure(speed) { host.persistSettings({wheelScrollSpeed: speed}); scaled.cancelFlick(); scaled.contentY = 0; wheel(scaled); }
    FakeHost { id: host }
    Window {
        id: window; visible: true; width: 640 * test.scale; height: 800 * test.scale
        title: "WindowPeek fictional input test"
        Item {
            // Target this window even when Wayland denies its activation request.
            TestEvent { id: events }
            width: window.width / test.scale; height: window.height / test.scale; scale: test.scale; transformOrigin: Item.TopLeft
            Flickable { id: native; width: (parent.width - 20) / 2; height: Math.min(300, parent.height); contentHeight: 10000; visible: test.step < 5; boundsBehavior: Flickable.StopAtBounds }
            Flickable {
                id: scaled; x: native.width + 20; width: (parent.width - 20) / 2; height: Math.min(300, parent.height); contentHeight: 10000; visible: test.step < 5
                boundsBehavior: Flickable.StopAtBounds
                Plugin.WheelScroll { view: scaled; speed: host.wheelScrollSpeed }
            }
            Plugin.PanelContent { id: panel; x: 10; y: 10; width: Math.min(540, parent.width - 20); height: parent.height - 40; hostWidget: host; visible: test.step >= 5 }
        }
    }
    Timer {
        interval: 700; running: true; repeat: true
        onTriggered: {
            try {
                switch(test.step++) {
                case 0:
                    if (Quickshell.env("QT_QPA_PLATFORM") === "wayland") window.requestActivate();
                    wheel(native); test.measure(100); break;
                case 1:
                    test.nativeDistance = native.contentY;
                    test.check(test.nativeDistance > 0 && Math.abs(scaled.contentY - test.nativeDistance) < 3, "100% matches native wheel travel");
                    test.measure(102); break;
                case 2:
                    test.check(Math.abs(scaled.contentY / test.nativeDistance - 1.02) < 0.012, "default wheel travel is 2% faster");
                    test.measure(200); break;
                case 3:
                    test.check(Math.abs(scaled.contentY / test.nativeDistance - 2) < 0.05, "200% doubles wheel travel");
                    test.measure(50); break;
                case 4:
                    test.check(Math.abs(scaled.contentY / test.nativeDistance - 0.5) < 0.05, "50% halves wheel travel");
                    panel.begin(); panel.showSettings(); test.named("settingsPersonalizationSection").expanded = true;
                    panel.ensureVisible(test.named("openLabelsButton")); break;
                case 5: test.click(test.named("openLabelsButton")); break;
                case 6:
                    test.check(panel.mode === "labels", "mouse opens editor");
                    test.click(test.named("settingsButton")); break;
                case 7:
                    var row = test.named("openLabelsButton");
                    test.check(panel.mode === "settings" && row.activeFocus && !row.visualFocus && !row.hot, "mouse return keeps tab position without a lingering highlight");
                    row.forceActiveFocus(Qt.TabFocusReason); test.key(Qt.Key_Return); break;
                case 8:
                    test.check(panel.mode === "labels", "keyboard opens editor");
                    test.key(Qt.Key_Escape); break;
                case 9:
                    test.check(panel.mode === "settings" && test.named("openLabelsButton").visualFocus, "keyboard return shows focus: mode=" + panel.mode + " focus=" + test.named("openLabelsButton").activeFocus + " reason=" + test.named("openLabelsButton").focusReason);
                    test.click(test.named("openLabelsButton")); break;
                case 10:
                    test.check(panel.mode === "labels", "second mouse click opens editor within the actual viewport");
                    test.named("settingsButton").forceActiveFocus(Qt.TabFocusReason);
                    test.key(Qt.Key_Return); break;
                case 11:
                    test.check(test.named("openLabelsButton").visualFocus, "keyboard Back shows focus after mouse entry: mode=" + panel.mode + " reason=" + test.named("settingsButton").activationFocusReason + " row=" + test.named("openLabelsButton").focusReason + " focused=" + test.named("openLabelsButton").activeFocus + " item=" + (window.activeFocusItem ? window.activeFocusItem.objectName : "none"));
                    test.named("settingsListSection").expanded = true;
                    host.persistSettings({wheelScrollSpeed: 102}); panel.ensureVisible(test.named("wheelScrollSpeedControl")); break;
                case 12:
                    var control = test.named("wheelScrollSpeedControl");
                    var slider = control.children.find(function(item) { return item.from === 50 && item.to === 300; });
                    test.check(!!slider, "speed slider exists");
                    slider.forceActiveFocus(Qt.TabFocusReason); test.key(Qt.Key_Right);
                    test.check(host.wheelScrollSpeed === 103 && control.value === 103, "slider saves a one-percent increase");
                    host.rejectSave = true; test.key(Qt.Key_Right);
                    test.check(host.wheelScrollSpeed === 103 && slider.value === 103, "failed save restores slider");
                    host.rejectSave = false; control.resetRequested();
                    test.check(host.wheelScrollSpeed === 102 && control.value === 102, "reset restores 102%");
                    panel.ensureVisible(test.named("openLabelsButton"));
                    test.click(test.named("openLabelsButton")); break;
                case 13:
                    test.key(Qt.Key_Escape); break;
                case 14:
                    test.check(test.named("openLabelsButton").visualFocus, "Escape after mouse entry returns visible keyboard focus");
                    test.named("openLabelsButton").forceActiveFocus(Qt.TabFocusReason);
                    test.key(Qt.Key_Return); break;
                case 15:
                    panel.ensureVisible(test.named("applyLabelsButton")); break;
                case 16: test.click(test.named("applyLabelsButton")); break;
                case 17:
                    test.check(panel.mode === "settings" && !test.named("openLabelsButton").visualFocus, "mouse Apply clears keyboard highlight after keyboard entry");
                    console.log("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit(); break;
                }
            } catch(error) { console.error("WINDOWPEEK_TEST_FAIL step " + (test.step - 1) + ": " + error); stop(); Qt.quit(); }
        }
    }
}
