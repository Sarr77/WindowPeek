import QtQuick
import QtQuick.Window
import Quickshell
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property size original
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, text) { if (!ok) throw new Error(text); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    FakeHost { id: host; settings: ({hintsMode:"on"}) }
    Window {
        id: window; visible: true; width: 560*test.scale; height: 450*test.scale
        Item {
            x: 20*test.scale; y: 20*test.scale; scale: test.scale; transformOrigin: Item.TopLeft
            Plugin.LogoPlacement { id: placement; width: 500; height: 280; baselineWidth: 250; hostWidget: host; artwork: logo }
            Plugin.PanelLogo {
                id: logo; hostWidget: host; source: "builtin:omarchy-pixel"; cooldownSlot: "settings"
                hintAnchor: placement; hintText: "Hold Ctrl: drag to move · double-click to center · wheel to resize"
            }
        }
    }
    Timer {
        interval: 500; running: true; repeat: true
        onTriggered: {
            try {
                var hint = test.find(logo, "logoHint"), bubble = hint.contentItem.parent;
                switch (test.step++) {
                case 0: hint.requested = true; break;
                case 1:
                    test.check(hint.visible, "artwork hint appears");
                    test.original = Qt.size(bubble.width*bubble.scale, bubble.height*bubble.scale);
                    test.check(Math.abs(hint.hintScale-test.scale)<0.001, "hint uses the UI scale");
                    host.persistSettings({settingsLogoLayout:{zoom:180,width:100,height:70,x:0,y:0}}); break;
                case 2:
                    test.check(placement.placedWidth>250, "artwork actually grows");
                    test.check(Math.abs(bubble.width*bubble.scale-test.original.width)<0.01 && Math.abs(bubble.height*bubble.scale-test.original.height)<0.01,
                        "enlarging and stretching artwork does not enlarge the hint");
                    host.persistSettings({settingsLogoLayout:{zoom:30,width:60,height:160,x:10,y:0}}); break;
                case 3:
                    test.check(placement.placedWidth<100, "artwork actually shrinks");
                    test.check(Math.abs(hint.hintScale-test.scale)<0.001 && Math.abs(bubble.width*bubble.scale-test.original.width)<0.01
                        && Math.abs(bubble.height*bubble.scale-test.original.height)<0.01, "small artwork keeps readable hint typography and frame");
                    test.check(bubble.x>=0 && bubble.y>=0 && bubble.x+test.original.width<=window.width && bubble.y+test.original.height<=window.height,
                        "hint remains on screen");
                    console.log("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (e) { console.error("WINDOWPEEK_TEST_FAIL: " + e); stop(); Qt.quit(); }
        }
    }
}
