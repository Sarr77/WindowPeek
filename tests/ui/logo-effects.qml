import QtQuick
import QtQuick.Window
import Quickshell
import "WindowPeek" as Plugin

// Real Qt GIF playback must end on the original clean poster, without trails.
ShellRoot {
    id: test
    property int effectIndex: 0
    property int step: 0
    property int waits: 0
    property bool grabbing: false
    readonly property var names: ["bouncyballs", "burn"]
    readonly property string effect: names[Math.min(effectIndex, names.length - 1)]
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    function capture(item, suffix) {
        var path = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
        if (!path) return;
        grabbing = true;
        item.grabToImage(function(result) {
            if (!result.saveToFile(path + "." + test.effect + "." + suffix + ".png")) {
                console.error("WINDOWPEEK_TEST_FAIL image save"); Qt.exit(1);
            }
            test.grabbing = false;
        });
    }
    Window {
        visible: true; width: 620; height: 400; color: "#111824"
        Plugin.LogoArt {
            id: art; x: 16; y: 16; width: 588; height: 169
            source: "builtin:ttfx-" + test.effect
            themeColors: false; playing: true; loopAnimation: false
        }
        Image {
            id: poster; x: 16; y: 200; width: 588; height: 169
            source: Qt.resolvedUrl("WindowPeek/vendor/ttfx/" + test.effect + ".png")
        }
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            if (test.grabbing) return;
            switch (test.step++) {
            case 0:
                if (!test.find(art, "customPanelLogo").finished || poster.status !== Image.Ready) {
                    if (++test.waits > 100) { console.error("WINDOWPEEK_TEST_FAIL playback did not finish"); Qt.exit(1); }
                    test.step--; break;
                }
                test.capture(art, "played"); break;
            case 1: test.capture(poster, "poster"); break;
            case 2:
                console.log("EFFECT_PLAYBACK_PASS", test.effect);
                if (++test.effectIndex < test.names.length) { test.step = 0; test.waits = 0; }
                else { console.log("WINDOWPEEK_TEST_PASS"); Qt.quit(); }
                break;
            }
        }
    }
}
