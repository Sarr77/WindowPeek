import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui as Ui
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

// Delay the first wallpaper lookup to make an early dark frame reproducible.
ShellRoot {
    id: test
    property int step: 0
    property int waits: 0
    property bool showing: false
    property bool verifyOpening: false
    property int openingFrames: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property bool compileOnly: Quickshell.env("WINDOWPEEK_TEST_COMPILE_ONLY") === "1"
    function check(ok, message) { if (!ok) throw new Error(message); }
    function waitFor(ok) {
        if (ok) { waits = 0; return false; }
        check(waits++ < 20, "timeout at step " + (step - 1)); step--; return true;
    }
    function fail(error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); timer.stop(); Qt.quit(); }
    FakeHost {
        id: host; bar: barApi
        settings: ({panelStyle:"wallpaper",popupAnimations:true,hintsMode:"off"})
        wallpaperSource: provider.source
        wallpaperPending: !provider.checked
        Component.onCompleted: savedAppearance = Appearance.normalize({uiScale:test.scale})
    }
    Plugin.WallpaperSource { id: provider; path: Quickshell.env("WINDOWPEEK_TEST_BACKGROUND") || "" }
    Ui.PluginBarApi { id: barApi; pluginId:"sarr.windowpeek.wallpaper.test"; position:"top"; barSize:28 }
    PanelWindow {
        id: backdrop; visible: test.showing
        anchors { top:true; bottom:true; left:true; right:true }
        exclusionMode: ExclusionMode.Ignore; color:"#51466e"
        WlrLayershell.namespace:"windowpeek-wallpaper-opening-test"
        WlrLayershell.layer:WlrLayer.Top; WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
        mask: Region {}
    }
    PanelWindow {
        id: bar; visible:test.showing; screen:backdrop.screen
        anchors { top:true; left:true; right:true }
        implicitHeight:28; exclusionMode:ExclusionMode.Ignore; color:"transparent"
        WlrLayershell.keyboardFocus:WlrKeyboardFocus.None; mask:Region {}
        Item { id:anchor; x:80; width:140; height:28 }
    }
    Plugin.Panel { id:panel; hostWidget:host; bar:barApi; anchorItem:anchor }
    FrameAnimation {
        running: test.verifyOpening
        onTriggered: {
            try {
                if (panel.surface.cardItem.opacity <= 0) return;
                test.check(panel.surface.backgroundReady, "opening paints a dark fallback before wallpaper is ready");
                if (panel.surface.cardItem.opacity < 1) test.openingFrames++;
            } catch (error) { test.fail(error); }
        }
    }
    Timer {
        id:timer; interval:100; running:true; repeat:true
        onTriggered: {
            try {
                if (test.compileOnly) { console.info("WINDOWPEEK_TEST_PASS: wallpaper opening compile"); Qt.quit(); return; }
                switch (test.step++) {
                case 0:
                    test.showing = true; test.verifyOpening = true; panel.hoverRequested = true; break;
                case 1:
                case 2:
                    test.check(panel.mapped && panel.surface.cardItem.opacity === 0,
                        "hover waits for the initial wallpaper lookup"); break;
                case 3:
                    provider.observe(test,true); break;
                case 4:
                    if (test.waitFor(panel.surface.cardItem.opacity === 1)) break;
                    test.check(test.openingFrames > 0, "hover still has its normal fade-in");
                    test.verifyOpening = false;
                    // A refresh of an already open card must not hide it.
                    provider.checked = false; break;
                case 5:
                    test.check(panel.surface.cardItem.opacity === 1, "refresh keeps the open card visible");
                    provider.checked = true;
                    panel.hoverRequested = false; panel.close(); break;
                case 6:
                    if (test.waitFor(!panel.mapped)) break;
                    provider.observe(test,false); provider.path = provider.path + ".missing";
                    host.persistSettings({popupAnimations:false});
                    panel.open(); break;
                case 7:
                    test.check(panel.surface.cardItem.opacity === 0, "instant search also waits for wallpaper resolution");
                    provider.observe(test,true); break;
                case 8:
                    if (test.waitFor(provider.checked && panel.surface.cardItem.opacity === 1)) break;
                    test.check(!String(provider.source), "missing wallpaper opens with the opaque fallback");
                    panel.close(); break;
                case 9:
                    if (test.waitFor(!panel.mapped)) break;
                    provider.observe(test,false);
                    host.persistSettings({popupAnimations:true});
                    panel.hoverRequested = true; break;
                case 10:
                    test.check(panel.surface.cardItem.opacity === 0, "new opening resets the readiness latch");
                    panel.hoverRequested = false; panel.close(); break;
                case 11:
                    test.check(!panel.mapped, "closing before the wallpaper resolves does not leave an invisible panel");
                    test.showing = false;
                    console.info("WINDOWPEEK_TEST_PASS: wallpaper first frame, fade, refresh, fallback and early close");
                    stop(); Qt.quit();
                }
            } catch (error) { test.fail(error); }
        }
    }
}
