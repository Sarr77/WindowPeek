import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    readonly property string directory: Quickshell.env("WINDOWPEEK_TEST_PROFILE")
    property int step: 0
    property int waits: 0
    property string previousSource: ""
    function check(ok, message) { if (!ok) throw new Error(message); }
    function waitFor(ok) {
        if (ok) { waits = 0; return false; }
        check(waits++ < 20, "wallpaper update timed out at step " + (step - 1));
        step--; return true;
    }
    Plugin.WallpaperSource { id: provider; path: test.directory + "/wallpaper link" }
    QtObject { id: secondConsumer }
    TestCase { id: pixels; when: false; name: "WallpaperSource" }
    Window {
        id: window; width: 64; height: 64; visible: true
        Image { id: wallpaper; anchors.fill: parent; source: provider.source }
    }
    Process { id: update }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            if (update.running) return;
            try {
                switch (test.step++) {
                case 0:
                    test.check(!provider.active && !String(provider.source), "closed panels do not read the wallpaper");
                    provider.observe(test, true); provider.observe(test, true); provider.observe(secondConsumer, true);
                    test.check(provider.consumers.length === 2, "a monitor registers only once");
                    provider.observe(test, false); provider.observe(secondConsumer, false);
                    provider.observe(test, true); provider.observe(secondConsumer, true);
                    test.check(!provider.checked, "reopening during the first lookup still waits for a valid result"); break;
                case 1:
                    if (test.waitFor(wallpaper.status === Image.Ready)) break;
                    test.check(pixels.grabImage(window.contentItem).red(20,20) === 255, "file URL with spaces and a query loads");
                    test.previousSource = String(provider.source);
                    update.command = ["ln", "-sfn", "--", test.directory + "/wallpaper B.svg", provider.path];
                    update.running = true; break;
                case 2:
                    if (test.waitFor(String(provider.source) !== test.previousSource && wallpaper.status === Image.Ready)) break;
                    test.check(pixels.grabImage(window.contentItem).blue(20,20) === 255, "link changes invalidate the cached image");
                    test.previousSource = String(provider.source);
                    update.command = ["cp", "--", test.directory + "/wallpaper A.svg", test.directory + "/wallpaper B.svg"];
                    update.running = true; break;
                case 3:
                    if (test.waitFor(String(provider.source) !== test.previousSource && wallpaper.status === Image.Ready)) break;
                    test.check(pixels.grabImage(window.contentItem).red(20,20) === 255, "in-place image edits invalidate the cache too");
                    provider.observe(test, false);
                    test.check(provider.active, "one monitor closing preserves the other consumer");
                    provider.path = test.directory + "/missing"; break;
                case 4:
                    if (test.waitFor(!String(provider.source) && wallpaper.status === Image.Null)) break;
                    provider.observe(secondConsumer, false);
                    test.check(!provider.active, "last consumer stops observation");
                    provider.path = test.directory + "/wallpaper link"; break;
                case 5:
                    test.check(!String(provider.source), "inactive path changes do not load images");
                    provider.observe(test, true); break;
                case 6:
                    if (test.waitFor(wallpaper.status === Image.Ready)) break;
                    provider.observe(test, false);
                    console.info("WINDOWPEEK_TEST_PASS: wallpaper source, cache invalidation and observer lifecycle");
                    stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
