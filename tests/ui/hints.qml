import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property int escapes: 0
    property int wheels: 0
    property int clicks: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    TestEvent { id: events }
    function check(value, message) { if (!value) throw new Error(message); }
    FakeHost { id: host; settings: ({hintsMode: "auto", hintsUsed: 99}) }
    Window {
        id: window
        visible: true; width: 500 * test.scale; height: 300 * test.scale
        Item { id: keyTarget; anchors.fill: parent; focus: true; Keys.onEscapePressed: test.escapes++ }
        MouseArea {
            id: underHint; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onWheel: test.wheels++
            onClicked: test.clicks++
        }
        Item {
            id: hintAnchor
            x: 20; y: 120; width: 200; height: 40
            scale: test.scale; transformOrigin: Item.TopLeft
            Plugin.PanelHint { id: hint; hostWidget: host; text: "Fictional hint" }
        }
        Plugin.HintsToggle {
            id: toggle; x: 400 * test.scale; y: 230 * test.scale
            words: host.words; hintsEnabled: host.hints.enabled
            automatic: host.hints.mode === "auto"; remaining: host.hints.remaining
            onClicked: host.toggleHints()
        }
    }
    Timer {
        interval: 500; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0:
                    if (Quickshell.env("QT_QPA_PLATFORM") === "wayland") window.requestActivate();
                    keyTarget.forceActiveFocus();
                    hint.requested = true; break;
                case 1:
                    test.check(host.hints.used === 100 && hint.visible, "100th displayed hint stays readable");
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0);
                    test.check(test.escapes === 1, "visible hint does not consume Escape: windowActive="
                        + window.active + " keyTargetActive=" + keyTarget.activeFocus);
                    hint.requested = false; break;
                case 2: hint.requested = true; break;
                case 3:
                    test.check(!hint.visible && host.hints.used === 100, "101st automatic hover stays hidden");
                    events.mouseClick(toggle, toggle.width / 2, toggle.height / 2, Qt.LeftButton, Qt.NoModifier, 0); break;
                case 4:
                    test.check(hint.visible && host.hints.used === 100 && host.hints.mode === "on", "help button enables unlimited manual hints");
                    var point = hint.contentItem.mapToItem(underHint, 10, 10);
                    var surface = hint.contentItem.parent;
                    var bounds = surface.mapToItem(underHint, 0, 0, surface.width, surface.height);
                    test.check(bounds.x >= 0 && bounds.y >= 0 && bounds.x + bounds.width <= underHint.width
                        && bounds.y + bounds.height <= underHint.height, "scaled hint fits its window");
                    events.mouseMove(underHint, point.x, point.y, 0, Qt.NoButton, Qt.NoModifier);
                    test.check(underHint.containsMouse, "hint does not intercept hover over the control underneath");
                    events.mouseWheel(underHint, point.x, point.y, Qt.NoButton, Qt.NoModifier, 0, -120, 0);
                    test.check(test.wheels === 1, "hint passes wheel input to the control underneath");
                    events.mouseClick(underHint, point.x, point.y, Qt.LeftButton, Qt.NoModifier, 0);
                    test.check(test.clicks === 1, "hint passes clicks to the control underneath");
                    events.mouseClick(toggle, toggle.width / 2, toggle.height / 2, Qt.LeftButton, Qt.NoModifier, 0); break;
                case 5:
                    test.check(!hint.visible, "manual off hides current hint");
                    hint.alwaysAvailable = true; break;
                case 6:
                    test.check(hint.visible, "help explanation remains available");
                    hintAnchor.LayoutMirroring.enabled = true;
                    hintAnchor.x = underHint.width - 40; hintAnchor.y = 5;
                    hint.text = "انقر للانتقال إلى هذه النافذة";
                    hint.maximumWidth = 100;
                    break;
                case 7:
                    var cornerSurface = hint.contentItem.parent;
                    var cornerBounds = cornerSurface.mapToItem(underHint, 0, 0, cornerSurface.width, cornerSurface.height);
                    test.check(cornerBounds.x >= 0 && cornerBounds.y >= 0 && cornerBounds.x + cornerBounds.width <= underHint.width
                        && cornerBounds.y + cornerBounds.height <= underHint.height, "wrapped hint stays inside the window near a corner");
                    test.check(hint.contentItem.effectiveHorizontalAlignment === Text.AlignRight, "hint preserves right-to-left alignment");
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
