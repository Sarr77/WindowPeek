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
            parent: underHint
            x: 20; y: 20; width: 200; height: 140
            scale: test.scale; transformOrigin: Item.TopLeft
            Plugin.PanelHint { id: hint; hostWidget: host; text: "Fictional hint. Second sentence.\nDelay: 0.3 s." }
        }
        Plugin.HintsToggle {
            id: toggle; x: 400 * test.scale; y: 230 * test.scale
            words: host.words; hintsEnabled: host.hints.enabled
            automatic: host.hints.mode === "auto"; remaining: host.hints.remaining
            onClicked: host.toggleHints()
        }
        Plugin.ResetButton {
            id: reset; x: 250 * test.scale; y: 170 * test.scale
            hostWidget: host; words: host.words; valueText: "102%"
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
                    events.mouseMove(underHint,60*test.scale,30*test.scale,0,Qt.NoButton,Qt.NoModifier);
                    hint.requested = true; break;
                case 1:
                    test.check(host.hints.used === 100 && hint.visible, "100th displayed hint stays readable");
                    test.check(hint.contentItem.text.indexOf("Automatic hints remaining: 0")>=0,"last automatic hint reports no further displays");
                    test.check(hint.contentItem.text.indexOf(host.words.hintsDisableExpanded.replace(/\.$/, ""))>=0,"automatic hints explain the expanded-panel off switch");
                    var firstSurface=hint.contentItem.parent;
                    test.check(firstSurface.x>60*test.scale && firstSurface.x<85*test.scale
                        && firstSurface.y>30*test.scale && firstSurface.y<60*test.scale,"hint appears beside the cursor, not the anchor edge");
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
                    test.check(hint.contentItem.text==="Fictional hint. Second sentence\nDelay: 0.3 s","manual hints omit final periods without changing internal punctuation or decimals");
                    events.mouseMove(underHint,80*test.scale,40*test.scale,0,Qt.NoButton,Qt.NoModifier);
                    test.check(hint.contentItem.parent.x>80*test.scale && hint.contentItem.parent.x<105*test.scale
                        && hint.contentItem.parent.y>40*test.scale && hint.contentItem.parent.y<70*test.scale,"visible hint follows cursor movement");
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
                    events.mouseMove(underHint,underHint.width-1,2,0,Qt.NoButton,Qt.NoModifier);
                    break;
                case 7:
                    var cornerSurface = hint.contentItem.parent;
                    var cornerBounds = cornerSurface.mapToItem(underHint, 0, 0, cornerSurface.width, cornerSurface.height);
                    test.check(cornerBounds.x >= 0 && cornerBounds.y >= 0 && cornerBounds.x + cornerBounds.width <= underHint.width
                        && cornerBounds.y + cornerBounds.height <= underHint.height, "wrapped hint stays inside the window near a corner");
                    test.check(hint.contentItem.effectiveHorizontalAlignment === Text.AlignRight, "hint preserves right-to-left alignment");
                    hint.requested=false;
                    host.persistSettings({hintsMode:"auto",hintsUsed:98});
                    events.mouseMove(reset,reset.width/2,reset.height/2,0,Qt.NoButton,Qt.NoModifier);break;
                case 8:
                    var resetHint=reset.children.find(function(item) { return item.contentItem && item.statusText !== undefined; });
                    test.check(resetHint && resetHint.visible && resetHint.text.indexOf("102%")>=0,"reset control uses shared hint");
                    test.check(host.hints.used===99 && resetHint.statusText.indexOf("1")>=0,"reset hint shares the display budget and countdown");
                    host.persistSettings({hintsMode:"off"});
                    test.check(!resetHint.visible,"reset hint follows manual off");
                    hint.belowAnchor=true;hint.text="Panel instructions";hint.maximumWidth=400;
                    hintAnchor.x=20;hintAnchor.y=20;hintAnchor.height=80;
                    hint.requested=true;
                    events.mouseMove(underHint,underHint.width-1,2,0,Qt.NoButton,Qt.NoModifier);break;
                case 9:
                    var bottomSurface=hint.contentItem.parent;
                    var anchorBottom=hintAnchor.mapToItem(underHint,0,hintAnchor.height).y;
                    test.check(bottomSurface.y>=anchorBottom && bottomSurface.y<anchorBottom+10*test.scale,"panel instructions stay below their anchor instead of at cursor");
                    var fixedY=bottomSurface.y;
                    events.mouseMove(underHint,50,50,0,Qt.NoButton,Qt.NoModifier);
                    test.check(bottomSurface.y===fixedY,"bottom instructions do not follow the pointer");
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
