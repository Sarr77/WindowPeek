import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek/vendor/omarchy" as Choice
import "WindowPeek/I18n.js" as I18n

ShellRoot {
    id: test
    property int step: 0
    property int kind: 0
    property bool capturing: false
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var picker: kind ? searchable : plain
    function check(ok, message) { if (!ok) throw new Error(message + " (picker " + kind + ")"); }
    function click() { events.mouseClick(picker, picker.width / 2, picker.height - 10, Qt.LeftButton, Qt.NoModifier, 0); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var result = find(child, name); if (result) return result; }
        return null;
    }
    TestEvent { id: events }
    Window {
        id: window; visible: true; width: 520 * test.scale; height: 600 * test.scale
        color: Color.popups.background
        Item {
            width: 520; height: 600; scale: test.scale; transformOrigin: Item.TopLeft
            Column {
                x: 20; y: 20; width: 400; spacing: 20
                Choice.Dropdown {
                    id: plain; width: parent.width; label: "List density"; uiScale: test.scale
                    value: "spacious"; options: ["spacious", "compact"]
                }
                Choice.SearchableDropdown {
                    id: searchable; width: parent.width; label: "Language"; uiScale: test.scale
                    value: "en"; options: I18n.options("en", "en")
                    rowHeight: 36; popupRowHeight: 36; placeholderText: "Search languages..."
                }
            }
            Binding { target: plain.QQC.Overlay.overlay; property: "transformOrigin"; value: Item.TopLeft }
            Binding { target: plain.QQC.Overlay.overlay; property: "scale"; value: test.scale }
        }
    }
    Timer {
        interval: 120; running: true; repeat: true
        onTriggered: {
            if (test.capturing) return;
            try {
                switch (test.step++) {
                case 0: test.click(); break;
                case 1:
                    test.check(test.picker.popupOpen, "first click opens the picker");
                    if (test.kind) {
                        var overlay = searchable.QQC.Overlay.overlay;
                        var header = test.find(overlay, "searchHeader");
                        var list = test.find(overlay, "resultList");
                        test.check(header && list && list.mapToItem(header, 0, 0).y >= header.height,
                            "language results begin below the search field");
                        test.check(list.height > 0 && list.clip, "language results have a clipped viewport");
                        if (Quickshell.env("WINDOWPEEK_TEST_IMAGE")) {
                            test.capturing = true;
                            window.contentItem.grabToImage(function(result) {
                                test.check(result.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE")), "image saved");
                                test.capturing = false; test.click();
                            });
                            break;
                        }
                    }
                    test.click(); break;
                case 2:
                    test.check(!test.picker.popupOpen, "second click closes the picker without reopening");
                    test.click(); break;
                case 3:
                    test.check(test.picker.popupOpen, "third click opens again");
                    events.mouseClick(window.contentItem, window.width - 10, window.height - 10, Qt.LeftButton, Qt.NoModifier, 0); break;
                case 4:
                    test.check(!test.picker.popupOpen, "outside click closes the picker");
                    test.click(); break;
                case 5: events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0); break;
                case 6:
                    test.check(!test.picker.popupOpen, "Escape closes the picker");
                    test.click(); test.click(); break;
                case 7:
                    test.check(!test.picker.popupOpen, "rapid repeated click stays closed");
                    test.check(test.picker.value === (test.kind ? "en" : "spacious"), "opening and closing does not change the choice");
                    if (test.kind++ === 0) { test.step = 0; break; }
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL at " + (test.step - 1) + ": " + error); stop(); Qt.quit(); }
        }
    }
}
