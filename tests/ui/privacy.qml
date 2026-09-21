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
    property int surface: 0
    property int sample: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(value, message) { if (!value) throw new Error(message + " (surface " + surface + ", step " + step + ")"); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var i = 0; i < item.children.length; ++i) { var found = find(item.children[i], name); if (found) return found; }
        return null;
    }
    function row() { return find(surface === 0 ? panel : overview, surface === 0 ? "windowFocusPointer" : "windowFocusPointer"); }
    function shift(down) {
        var state = thumbnail.modifierState;
        state.pending = "fixture:" + (++sample);
        state.receive("custom", "windowpeek-preview-shift," + state.pending + "," + (down ? "1" : "0"));
    }
    function hover() { var item = row(); events.mouseMove(item, item.width / 2, item.height / 2, 0, Qt.NoButton, Qt.NoModifier); }
    TestEvent { id: events }
    FakeHost {
        id: host; windowPreview: thumbnail
        Component.onCompleted: savedAppearance = Appearance.normalize({uiScale:test.scale})
        function chooseDestination(address, position) {
            destinationRequested = address;
            thumbnail.menuRetained = thumbnail.visible;
            moveMenuOpen = true;
            return true;
        }
    }
    FloatingWindow {
        id: window; visible: true; implicitWidth: 1000 * test.scale; implicitHeight: 680 * test.scale
        color: Color.popups.background
        Item {
            width: 1000; height: 680; scale: test.scale; transformOrigin: Item.TopLeft
            Plugin.PanelContent { id: panel; x: 10; y: 10; width: 480; height: 650; hostWidget: host; visible: test.surface === 0 }
            Plugin.TooltipContent {
                id: overview; x: 10; y: 10; width: 440; height: implicitHeight; hostWidget: host; visible: test.surface === 1
                onFocusRequested: function(address) { host.focusWindow(address); }
                onBringRequested: function(address) { host.bringWindow(address); }
            }
        }
    }
    Plugin.WindowThumbnail { id: thumbnail; hostWidget: host }
    Timer {
        interval: 120; running: true; repeat: true
        onTriggered: {
            try {
                var card = test.find(thumbnail.contentItem, "windowThumbnailPointer");
                switch (test.step++) {
                case 0: thumbnail.modifierState.enabled = false; panel.begin(); break;
                case 1:
                    test.hover();
                    test.check(thumbnail.available && !thumbnail.visible, "row waits for a fresh Shift sample");
                    test.shift(true); break;
                case 6:
                    test.check(!thumbnail.visible, "holding Shift prevents a preview after the dwell");
                    test.shift(false); break;
                case 7:
                    test.check(!thumbnail.visible, "releasing Shift starts a new dwell"); break;
                case 11:
                    test.check(thumbnail.visible, "stationary row resumes preview after releasing Shift");
                    test.shift(true);
                    test.check(!thumbnail.visible && !test.find(thumbnail.contentItem, "windowThumbnailCapture").active,
                        "Shift hides an existing preview and releases capture immediately");
                    events.mouseClick(test.row(), 15, 15, Qt.LeftButton, Qt.ControlModifier | Qt.ShiftModifier, 0);
                    test.check(host.brought === "0x1" && !host.focused, "private row still supports Ctrl+Shift+click");
                    host.brought = ""; break;
                case 12: test.hover(); test.shift(false); break;
                case 16:
                    test.check(thumbnail.visible, "preview can reopen after private browsing");
                    events.mouseMove(test.row(), -20, -20, 0, Qt.NoButton, Qt.NoModifier);
                    events.mouseMove(card, card.width / 2, card.height / 2, 0, Qt.NoButton, Qt.NoModifier);
                    test.check(thumbnail.pointerOnCard, "pointer reaches the preview card");
                    test.shift(true); break;
                case 17:
                    test.check(thumbnail.visible && thumbnail.previewAllowed, "Shift preserves the card under the pointer");
                    events.mouseClick(card, card.width / 2, card.height / 2, Qt.LeftButton, Qt.ControlModifier | Qt.ShiftModifier, 0);
                    test.check(host.brought === "0x1" && !host.focused && !thumbnail.visible, "Ctrl+Shift+click on card still brings the window");
                    host.brought = ""; break;
                case 18: test.hover(); test.shift(false); break;
                case 22:
                    test.check(thumbnail.visible, "preview reopens after activation");
                    events.mouseMove(test.row(), -20, -20, 0, Qt.NoButton, Qt.NoModifier);
                    events.mouseMove(card, card.width / 2, card.height / 2, 0, Qt.NoButton, Qt.NoModifier);
                    test.shift(true);
                    events.mouseMove(card, -4, card.height / 2, 0, Qt.NoButton, Qt.ControlModifier | Qt.ShiftModifier);
                    break;
                case 23:
                    test.check(!thumbnail.visible, "the transparent gap is not a Shift exception");
                    break;
                case 24: test.hover(); test.shift(false); break;
                case 28:
                    test.check(thumbnail.visible, "ordinary hover still works");
                    thumbnail.modifierState.known = false;
                    test.check(!thumbnail.visible, "unavailable modifier state cannot reveal a preview");
                    thumbnail.dismiss();
                    test.check(!thumbnail.modifierState.active && !thumbnail.modifierState.known, "dismissal stops modifier observation");
                    var state = thumbnail.modifierState;
                    state.pending = "old"; state.receive("custom", "windowpeek-preview-shift,old,0");
                    test.check(!state.known, "late reply after dismissal is ignored");
                    host.persistSettings({windowPreviews:false});
                    test.hover(); break;
                case 33:
                    test.check(!thumbnail.visible && !thumbnail.available && !thumbnail.modifierState.active,
                        "disabled previews do not start capture or Shift observation after dwell");
                    events.mouseClick(test.row(), 15, 15, Qt.LeftButton, Qt.ControlModifier | Qt.ShiftModifier, 0);
                    test.check(host.brought === "0x1", "disabling previews preserves row Ctrl+Shift+click");
                    host.brought = "";
                    host.persistSettings({windowPreviews:true});
                    test.hover(); test.shift(false); break;
                case 37:
                    test.check(thumbnail.visible, "enabling previews restores stationary row preview");
                    host.persistSettings({windowPreviews:false});
                    test.check(!thumbnail.visible && !thumbnail.modifierState.active
                        && !test.find(thumbnail.contentItem, "windowThumbnailCapture").active,
                        "disabling an open preview stops capture and modifier observation");
                    break;
                case 38:
                    host.persistSettings({windowPreviews:true});
                    test.hover(); test.shift(true); break;
                case 43:
                    test.check(!thumbnail.visible, "enabling previews still respects held Shift");
                    test.shift(false); break;
                case 47:
                    test.check(thumbnail.visible, "release restores reenabled preview");
                    events.mouseMove(test.row(), -20, -20, 0, Qt.NoButton, Qt.NoModifier);
                    events.mouseMove(card, card.width / 2, card.height / 2, 0, Qt.NoButton, Qt.NoModifier);
                    test.check(thumbnail.pointerOnCard, "pointer is on card before settings disable");
                    host.persistSettings({windowPreviews:false});
                    test.check(!thumbnail.visible, "settings disable also closes the card under the pointer");
                    break;
                case 48:
                    thumbnail.dismiss(); host.persistSettings({windowPreviews:true, previewHoverDelay:1000});
                    test.hover(); test.shift(false); break;
                case 49:
                    test.check(!thumbnail.visible, "longer preview delay does not reveal the card early");
                    host.persistSettings({previewHoverDelay:0});
                    test.check(thumbnail.visible, "zero opens a pending preview synchronously");
                    test.shift(true);
                    test.check(!thumbnail.visible, "zero delay still respects Shift privacy");
                    test.shift(false);
                    test.check(thumbnail.visible, "release uses zero delay without an extra timer tick");
                    events.mouseClick(test.row(), 15, 15, Qt.LeftButton, Qt.ControlModifier | Qt.ShiftModifier, 0);
                    test.check(host.brought === "0x1", "instant previews preserve Ctrl+Shift+click");
                    host.brought = "";
                    thumbnail.dismiss(); host.persistSettings({previewHoverDelay:800});
                    test.hover(); test.shift(false); break;
                case 50:
                    test.check(!thumbnail.visible, "nonzero delay is restored");
                    thumbnail.dismiss(); break;
                case 58:
                    test.check(!thumbnail.visible && !thumbnail.ready, "cancelled dwell cannot reopen a dismissed preview");
                    host.persistSettings({previewHoverDelay:0});
                    test.hover();
                    test.check(!thumbnail.visible, "zero delay waits for known modifier state");
                    test.shift(true);
                    test.check(!thumbnail.visible, "held Shift blocks a fresh instant preview");
                    test.shift(false);
                    test.check(thumbnail.visible, "fresh instant preview opens after a safe modifier sample");
                    host.persistSettings({windowPreviews:false});
                    test.check(!thumbnail.visible && !thumbnail.modifierState.active, "disable wins over instant preview");
                    break;
                case 59:
                    host.persistSettings({windowPreviews:true, previewHoverDelay:0});
                    test.hover(); test.shift(false); break;
                case 60:
                    events.mouseMove(test.row(), -20, -20, 0, Qt.NoButton, Qt.NoModifier);
                    events.mouseMove(card, card.width / 2, card.height / 2, 0, Qt.NoButton, Qt.NoModifier);
                    test.shift(false);
                    test.check(thumbnail.visible, "Ctrl-click keeps the hovered card available");
                    events.mouseClick(card, card.width / 2, card.height / 2, Qt.LeftButton, Qt.ControlModifier, 0);
                    test.check(host.destinationRequested === "0x1" && !host.brought && thumbnail.visible && thumbnail.menuRetained,
                        "Ctrl-only card click requests a chooser while retaining its preview");
                    test.shift(true);
                    events.mouseMove(card, -20, -20, 0, Qt.NoButton, Qt.ControlModifier);
                    thumbnail.hideFor(thumbnail.anchorItem);
                    break;
                case 64:
                    test.check(!thumbnail.pointerOnCard && thumbnail.visible && thumbnail.address === "0x1",
                        "the preview survives leaving the card and the normal hide delay while choosing");
                    thumbnail.showFor(test.row(), "0x2", test.row());
                    test.check(thumbnail.address === "0x1", "hover cannot retarget the menu's retained preview");
                    host.moveMenuOpen = false;
                    test.check(!thumbnail.menuRetained && !thumbnail.visible,
                        "closing the chooser restores Shift privacy outside the card");
                    test.hover(); test.shift(false);
                    break;
                case 65:
                    events.mouseMove(card, card.width / 2, card.height / 2, 0, Qt.NoButton, Qt.NoModifier);
                    test.shift(false);
                    events.mouseClick(card, card.width / 2, card.height / 2, Qt.LeftButton, Qt.ControlModifier, 0);
                    test.shift(true);
                    test.check(thumbnail.visible && thumbnail.menuRetained, "a later menu can retain its preview again");
                    host.persistSettings({windowPreviews:false});
                    test.check(!thumbnail.visible && !test.find(thumbnail.contentItem, "windowThumbnailCapture").active,
                        "disabling previews also releases a menu-retained capture");
                    host.moveMenuOpen = false;
                    host.destinationRequested = "";
                    thumbnail.dismiss(); host.persistSettings({windowPreviews:true, previewHoverDelay:400});
                    if (test.surface++ === 0) { test.step = 0; break; }
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (error) {
                console.error("WINDOWPEEK_TEST_FAIL: " + error, JSON.stringify({available:thumbnail.available,
                    allowed:thumbnail.previewAllowed, ready:thumbnail.ready, rowHovered:thumbnail.rowHovered,
                    known:thumbnail.modifierState.known, shift:thumbnail.modifierState.shiftDown, address:thumbnail.address}));
                stop(); Qt.quit();
            }
        }
    }
}
