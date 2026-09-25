import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

ShellRoot {
    id: test
    property int step: 0
    property int closed: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name && item.visible) return item;
        for (var child of item.children || []) { var result = find(child, name); if (result) return result; }
        return null;
    }
    function named(name) { return find(panel, name); }
    function right(item) {
        check(!!item, "right-click target exists");
        events.mouseClick(item, item.width / 2, item.height / 2, Qt.RightButton, Qt.NoModifier, 0);
    }
    function popupBack() { return find(panel.QQC.Overlay.overlay, "popupBackPointer"); }
    TestEvent { id: events }
    FakeHost {
        id: host; updatesAvailable: true
        Component.onCompleted: savedAppearance = Appearance.normalize({uiScale:test.scale})
    }
    Window {
        visible: true; width: 580 * test.scale; height: 720 * test.scale
        color: Color.popups.background
        Plugin.PanelContent {
            id: panel; x: 10 * test.scale; y: 10 * test.scale; width: 540; height: 680
            hostWidget: host; scale: test.scale; transformOrigin: Item.TopLeft
            onCloseRequested: test.closed++
            Binding { target: panel.QQC.Overlay.overlay; property: "transformOrigin"; value: Item.TopLeft }
            Binding { target: panel.QQC.Overlay.overlay; property: "scale"; value: test.scale }
        }
    }
    Timer {
        interval: 130; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0: panel.begin(); panel.showSettings(); test.named("settingsPanelSection").expanded = true; break;
                case 1:
                    test.right(test.named("windowPreviewsToggle"));
                    test.check(panel.mode === "settings" && !test.named("settingsPanelSection").expanded && host.windowPreviews,
                        "right-click over a switch collapses only its section without toggling it");
                    test.right(test.named("settingsButton"));
                    test.check(panel.mode === "windows", "the next right click leaves the collapsed Settings overview");
                    test.right(test.named("settingsButton"));
                    test.check(test.closed === 1 && panel.mode === "windows", "right-click on the main list requests dismissal instead of opening Settings");
                    panel.showSettings(); test.named("languages").open(); break;
                case 2: test.right(test.popupBack()); break;
                case 3:
                    test.check(!test.named("languages").popupOpen && panel.mode === "settings" && host.language === "en",
                        "right-click in searchable picker closes one level without changing language");
                    test.named("settingsListSection").expanded = true;
                    panel.ensureVisible(test.named("listDensityPicker")); test.named("listDensityPicker").open(); break;
                case 4: test.right(test.named("settingsButton")); break;
                case 5:
                    test.check(!test.named("listDensityPicker").popupOpen && panel.mode === "settings" && !panel.compact
                        && test.named("settingsListSection").expanded,
                        "right-click outside a picker closes only the picker, preserving its section");
                    panel.mode = "appearance"; host.previewAppearance({uiScale:test.scale + 0.1});
                    test.right(test.named("settingsButton"));
                    test.check(panel.mode === "settings" && host.appearance.uiScale === host.savedAppearance.uiScale,
                        "Back over the header discards the color editor preview");
                    panel.mode = "scaling"; host.previewAppearance({barScale:1.5});
                    test.right(test.named("settingsButton"));
                    test.check(panel.mode === "settings" && host.appearance.barScale === host.savedAppearance.barScale,
                        "Back discards the scaling preview");
                    panel.mode = "labels"; break;
                case 6:
                    var editor = test.named("labelsEditor");
                    editor.setStyle("custom"); editor.setText("panelTitle", "Unsaved title");
                    panel.ensureVisible(test.named("labelInput_panelTitle")); break;
                case 7:
                    test.right(test.named("labelInput_panelTitle"));
                    test.check(panel.mode === "settings" && !host.labelsPreview && !host.savedLabels.customLabels.panelTitle,
                        "right-click in a text field goes back and discards the custom text draft");
                    panel.openMove("0x1"); break;
                case 8: test.right(test.popupBack()); break;
                case 9:
                    test.check(panel.mode === "move" && !test.named("destinationPicker").popupOpen && !host.moved,
                        "right-click in destination picker returns to the form without moving");
                    test.right(test.named("settingsButton"));
                    test.check(panel.mode === "windows" && !host.moved, "right-click Back leaves the move form");
                    test.named("updateSwitch").clicked(); break;
                case 10:
                    test.right(test.named("confirmUpdateOff"));
                    test.check(!test.named("confirmUpdateOff") && host.autoUpdates, "right-click cancels update confirmation without disabling updates");
                    panel.showSettings(); break;
                case 11:
                    var button = test.named("settingsButton");
                    events.mouseMove(button, button.width / 2, button.height / 2, 0, Qt.NoButton, Qt.NoModifier);
                    test.check(button.hot, "the Back gesture does not block normal hover feedback");
                    events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(panel.mode === "windows", "normal primary-click Back still works");
                    panel.showSettings();
                    test.named("settingsPersonalizationSection").expanded = true;
                    test.named("settingsControlsSection").expanded = true;
                    break;
                case 12:
                    panel.ensureVisible(test.named("settingsPersonalizationSection").headerItem);
                    test.right(test.named("settingsPersonalizationSection").headerItem);
                    test.check(!test.named("settingsControlsSection").expanded && test.named("settingsPersonalizationSection").expanded,
                        "right-click unwinds most recently opened section regardless of pointer position");
                    events.mouseClick(test.named("settingsButton"),10,10,Qt.LeftButton,Qt.NoModifier,0);
                    test.check(panel.mode === "windows", "Back deliberately skips the remaining inner section");
                    panel.showSettings();test.named("settingsPersonalizationSection").expanded = true;
                    panel.mode = "appearance";break;
                case 13:
                    test.named("appearanceEditor").colorsExpanded = true;
                    panel.navigateBack();
                    test.check(panel.mode === "appearance" && !test.named("appearanceEditor").colorsExpanded,
                        "right-click first closes inner color editor");
                    test.named("appearanceEditor").colorsExpanded = true;
                    events.mouseClick(test.named("settingsButton"),10,10,Qt.LeftButton,Qt.NoModifier,0);
                    test.check(panel.mode === "settings" && test.named("settingsPersonalizationSection").expanded,
                        "Back skips inner editor but preserves the section used to enter it");
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL at " + (test.step - 1) + ": " + error); stop(); Qt.quit(); }
        }
    }
}
