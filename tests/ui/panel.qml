import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

ShellRoot {
    id: test
    property int step: 0
    property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    property var originalRow: null
    property real originalRowHeight: 0
    property real originalContentHeight: 0
    function check(value, message) { if (!value) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var i = 0; i < item.children.length; i++) { var result = find(item.children[i], name); if (result) return result; }
        return null;
    }
    TestEvent { id: events }
    FakeHost {
        id: host
        Component.onCompleted: savedAppearance = Appearance.normalize({uiScale: test.scale,
            tooltipStyle: Quickshell.env("WINDOWPEEK_TEST_STYLE")})
    }
    Window {
        id: window; visible: true; width: 540 * test.scale; height: 540 * test.scale
        color: Color.popups.background
        Plugin.PanelContent {
            id: panel; x: 20; y: 20; width: window.width / test.scale - 40; height: window.height / test.scale - 40
            scale: test.scale; transformOrigin: Item.TopLeft; hostWidget: host
        }
    }
    Timer {
        interval: 120; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0: panel.begin(); break;
                case 1:
                    test.check(panel.matches.length === 5, "special workspaces start included");
                    test.check(panel.searchField.activeFocus, "opening focuses search");
                    events.keyClick(Qt.Key_P, Qt.NoModifier, 0);
                    events.keyClick(Qt.Key_R, Qt.NoModifier, 0);
                    events.keyClick(Qt.Key_O, Qt.NoModifier, 0);
                    events.keyClick(Qt.Key_J, Qt.NoModifier, 0);
                    break;
                case 2:
                    test.check(panel.searchField.text === "proj" && panel.matches.length === 2, "typing j remains text and search finds the hidden tab");
                    events.keyClick(Qt.Key_Down, Qt.NoModifier, 0);
                    test.check(panel.selectedAddress === "0x2", "arrow selects next window");
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 0);
                    test.check(host.focused === "0x2", "Enter targets hidden tab");
                    host.focused = "";
                    var next = JSON.parse(JSON.stringify(host.snapshot));
                    next.clients = next.clients.filter(function(w) { return w.address !== "0x2"; });
                    host.snapshot = next;
                    break;
                case 3:
                    test.check(panel.selectedAddress === "", "closing selected window clears selection");
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 0);
                    test.check(host.focused === "", "Enter cannot silently target a replacement");
                    panel.searchField.text = "";
                    panel.moveSelection(1);
                    events.keyClick(Qt.Key_Return, Qt.ShiftModifier, 0);
                    break;
                case 4:
                    test.check(panel.mode === "move" && panel.moveAddress === "0x1", "Shift+Enter opens explicit destination picker");
                    var picker = test.find(panel, "destinationPicker");
                    events.keyClick(Qt.Key_4, Qt.NoModifier, 0);
                    test.check(picker.filtered.length === 1 && picker.filtered[0].label === "Workspace 4"
                        && picker.filtered[0].value === "4", "number search finds the labeled workspace with its original destination");
                    panel.destination = "4";
                    test.find(panel, "confirmMove").clicked();
                    test.check(host.moved === "0x1:4", "move uses selected address and explicit destination");
                    panel.back(); panel.showSettings(); break;
                case 5:
                    test.check(panel.mode === "settings", "settings reachable");
                    test.find(panel, "settingsPanelSection").expanded = true;
                    test.find(panel, "settingsListSection").expanded = true;
                    test.check(host.windowPreviews, "window previews are enabled by default");
                    test.find(panel, "windowPreviewsToggle").clicked();
                    test.check(!host.windowPreviews, "settings can disable window previews");
                    test.find(panel, "windowPreviewsToggle").clicked();
                    test.check(host.windowPreviews, "settings can restore window previews");
                    var hover = test.find(panel, "openOnHoverToggle");
                    test.check(host.openOnHover, "hover panel defaults on");
                    host.rejectSave = true; hover.clicked();
                    test.check(host.openOnHover && hover.checked, "failed save keeps hover switch enabled");
                    host.rejectSave = false; hover.clicked();
                    test.check(!host.openOnHover && !test.find(panel, "panelHoverDelayControl").enabled,
                        "click-only mode disables the bar delay control");
                    hover.clicked();
                    test.check(host.openOnHover && test.find(panel, "panelHoverDelayControl").enabled,
                        "hover can be restored");
                    var delay = test.find(panel, "panelHoverDelayControl");
                    var input = test.find(delay, "delayInput");
                    input.forceActiveFocus();
                    events.keyClick(Qt.Key_A, Qt.ControlModifier, 0);
                    events.keyClick(Qt.Key_0, Qt.NoModifier, 0);
                    events.keyClick(Qt.Key_Return, Qt.NoModifier, 0);
                    test.check(host.panelHoverDelay === 0 && host.previewHoverDelay === 400, "bar delay saves zero independently");
                    test.check(panel.mode === "settings", "accepting a delay keeps Settings open");
                    var previewDelay = test.find(panel, "previewHoverDelayControl");
                    previewDelay.choose(1250);
                    test.check(host.previewHoverDelay === 1250 && host.panelHoverDelay === 0, "preview delay is separate");
                    input.text = ""; delay.commit();
                    test.check(input.text === "0" && host.panelHoverDelay === 0, "empty input restores saved delay");
                    host.rejectSave = true;
                    delay.choose(800);
                    test.check(input.text === "0" && host.panelHoverDelay === 0 && host.saveFailed,
                        "failed save does not confirm an unsaved delay");
                    test.find(panel, "popupAnimationsToggle").clicked();
                    test.check(host.popupAnimations, "failed save keeps animations enabled");
                    host.rejectSave = false;
                    test.find(panel, "popupAnimationsToggle").clicked();
                    test.check(!host.popupAnimations, "animations can be disabled independently");
                    delay.choose(400); previewDelay.choose(400);
                    test.find(panel, "popupAnimationsToggle").clicked();
                    test.check(host.scrollBounce, "springy scrolling defaults on");
                    test.find(panel, "scrollBounceToggle").clicked();
                    test.check(!host.scrollBounce, "settings can disable springy scrolling");
                    test.find(panel, "scrollBounceToggle").clicked();
                    test.check(host.scrollBounce, "settings can restore springy scrolling");
                    var density = test.find(panel, "listDensityPicker");
                    var oldDensity = host.savedAppearance.tooltipStyle;
                    var newDensity = oldDensity === "panel" ? "compact" : "panel";
                    host.rejectSave = true; density.value = newDensity; density.changed(newDensity);
                    test.check(host.saveFailed && density.value === oldDensity, "density cannot show an unsaved selection");
                    host.rejectSave = false; density.changed(newDensity);
                    test.check(host.savedAppearance.tooltipStyle === newDensity && density.value === newDensity,
                        "list density saves immediately outside the color editor");
                    host.saveAppearance({tooltipStyle: oldDensity});
                    test.check(density.value === oldDensity, "density follows another monitor's saved value");
                    panel.back();
                    host.setLanguage("pl");
                    panel.searchField.text = "";
                    panel.selectedAddress = "0x1";
                    break;
                case 6:
                    test.originalRow = test.find(panel, "windowFocusPointer");
                    test.originalRowHeight = test.originalRow.height;
                    test.originalContentHeight = test.find(panel, "windowList").contentHeight;
                    host.previewAppearance({tooltipStyle: panel.compact ? "panel" : "compact"});
                    break;
                case 7:
                    test.check(test.find(panel, "windowFocusPointer") === test.originalRow, "density preview preserves row identity");
                    test.check(panel.selectedAddress === "0x1", "density preview preserves selection");
                    test.check(panel.compact ? test.originalRow.height < test.originalRowHeight : test.originalRow.height > test.originalRowHeight,
                        "density changes clicked row height");
                    var contentHeight = test.find(panel, "windowList").contentHeight;
                    test.check(panel.compact ? contentHeight < test.originalContentHeight : contentHeight > test.originalContentHeight,
                        "density updates the actual scroll extent");
                    host.cancelAppearance();
                    break;
                case 8:
                    test.check(test.originalRow.height === test.originalRowHeight, "Cancel restores saved density");
                    var image = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
                    console.info("WINDOWPEEK_TEST_PASS");
                    stop();
                    if (image) window.contentItem.grabToImage(function(result) { result.saveToFile(image); Qt.quit(); });
                    else Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
