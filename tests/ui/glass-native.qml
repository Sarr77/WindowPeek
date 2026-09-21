import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui as Ui
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

// A fictional backdrop covers the capture region; notifications sit outside it.
// This fixture never moves the pointer, sends input or asks for keyboard focus.
ShellRoot {
    id: test
    property int step: 0
    property bool showing: false
    property bool useWallpaper: false
    property bool failed: false
    property int waits: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property bool compileOnly: Quickshell.env("WINDOWPEEK_TEST_COMPILE_ONLY") === "1"
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    function capture(name) {
        var prefix = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
        if (!prefix) return;
        var screen = backdrop.screen;
        var width = Math.min(screen.width, Math.ceil(panel.surface.cardItem.x + panel.surface.cardItem.width + thumbnail.width + 2));
        screenshot.command = ["grim", "-s", "1", "-g", screen.x + "," + screen.y + " " + width + "x" + screen.height,
            prefix + "-" + name + ".png"];
        screenshot.running = true;
    }
    TestEvent { id: events }
    FakeHost {
        id: host; bar: barApi
        function open() { panel.open(); }
        settings: ({popupAnimations:false, previewHoverDelay:0, hintsMode:"off"})
        windowPreview: thumbnail
        wallpaperSource: wallpaperProvider.source
        wallpaperPending: !wallpaperProvider.checked
        Component.onCompleted: savedAppearance = Appearance.normalize({uiScale:test.scale})
    }
    Plugin.WallpaperSource {
        id: wallpaperProvider
        path: Quickshell.env("WINDOWPEEK_TEST_BACKGROUND") || ""
    }
    Ui.PluginBarApi { id: barApi; pluginId: "sarr.windowpeek.glass.test"; position: "top"; barSize: 28 }
    PanelWindow {
        id: backdrop
        visible: test.showing
        anchors { top:true; bottom:true; left:true; right:true }
        exclusionMode: ExclusionMode.Ignore; color: "#404050"
        WlrLayershell.namespace: "windowpeek-glass-test-background"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
        Image {
            anchors.fill: parent; visible: test.useWallpaper
            source: Quickshell.env("WINDOWPEEK_TEST_BACKGROUND") || ""
            fillMode: Image.PreserveAspectCrop
        }
        Repeater {
            model: test.useWallpaper ? 0 : Math.ceil(backdrop.width / 16)
            Rectangle {
                required property int index
                x: index * 16; width: 16; height: backdrop.height
                color: index % 2 ? "#28cbaa" : "#f4eee0"
            }
        }
    }
    PanelWindow {
        id: bar
        visible: test.showing; screen: backdrop.screen
        anchors { top:true; left:true; right:true }
        implicitHeight: 28; exclusionMode: ExclusionMode.Ignore; color: "transparent"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
        Item { id: anchor; x: 80; width: 140; height: 28 }
    }
    Plugin.Panel { id: panel; hostWidget: host; bar: barApi; anchorItem: anchor }
    Plugin.WindowThumbnail { id: thumbnail; hostWidget: host }
    Process {
        id: screenshot
        onExited: function(code) {
            if (code !== 0) { test.failed = true; console.error("WINDOWPEEK_TEST_FAIL: capture failed"); Qt.quit(); }
        }
    }
    Timer {
        interval: 350; running: true; repeat: true
        onTriggered: {
            if (screenshot.running) return;
            try {
                if (test.compileOnly) { console.info("WINDOWPEEK_TEST_PASS: glass native compile"); Qt.quit(); return; }
                switch (test.step++) {
                case 0:
                    Color.shellValues = {}; Color.background = "#1b1b26"; Color.foreground = "#b7bedb"; Color.accent = "#d898f5";
                    test.showing = true; panel.hoverRequested = true; break;
                case 1:
                    test.check(panel.mapped && panel.surface.cardItem.color.a === 1, "solid panel opens");
                    test.check(panel.surface.cardItem.y >= 0 && panel.surface.cardItem.y + panel.surface.cardItem.height <= backdrop.screen.height,
                        "card is inside the captured monitor");
                    test.check(!panel.surface.BackgroundEffect.blurRegion, "solid does not request blur");
                    test.capture("solid"); break;
                case 2:
                    host.persistSettings({panelStyle:"glass"}); break;
                case 3:
                    test.check(panel.surface.cardItem.opacity === 1 && panel.surface.cardItem.color.a < 0.99,
                        "only the card background is translucent");
                    var region = panel.surface.BackgroundEffect.blurRegion;
                    test.check(region && region.radius === Math.round(panel.surface.cardItem.radius), "rounded blur region matches card");
                    test.check(panel.surface.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None, "glass hover does not grab focus");
                    console.info("GLASS_GEOMETRY " + JSON.stringify({
                        x: panel.surface.cardItem.x, y: panel.surface.cardItem.y,
                        width: panel.surface.cardItem.width, height: panel.surface.cardItem.height,
                        screenX: backdrop.screen.x, screenY: backdrop.screen.y, scale:test.scale}));
                    test.capture("glass"); break;
                case 4:
                    test.useWallpaper = !!Quickshell.env("WINDOWPEEK_TEST_BACKGROUND");
                    thumbnail.showFor(test.find(panel.body, "windowList").itemAtIndex(1), "0x1", panel.surface.cardItem);
                    break;
                case 5:
                    test.check(thumbnail.backingWindowVisible && thumbnail.cardItem.color.a < 0.99, "instant preview uses glass");
                    test.capture("wallpaper"); break;
                case 6:
                    host.persistSettings({popupAnimations:true}); break;
                case 7:
                    test.check(thumbnail.backingWindowVisible && thumbnail.cardItem.color.a < 0.99, "animated preview also uses glass");
                    Color.background = "#eeeeee"; Color.foreground = "#222222"; host.themeId = "light"; host.themeAccent = "#227799";
                    break;
                case 8:
                    test.check(panel.surface.cardItem.color.r > 0.9 && panel.surface.cardItem.color.a < 0.99,
                        "native card follows a light theme without losing glass");
                    test.capture("light"); break;
                case 9:
                    host.persistSettings({panelStyle:"solid"}); break;
                case 10:
                    test.check(panel.surface.cardItem.color.a === 1 && !panel.surface.BackgroundEffect.blurRegion,
                        "restoring solid removes native blur");
                    test.check(thumbnail.cardItem.color.a === 1, "preview returns to solid too");
                    thumbnail.dismiss(); panel.hoverRequested = false; panel.close(); test.useWallpaper = true;
                    Color.background = "#1b1b26"; Color.foreground = "#b7bedb"; host.themeId = "tokyo-night"; host.themeAccent = "#7aa2f7";
                    wallpaperProvider.observe(test, true); break;
                case 11:
                    test.check(!panel.mapped, "reference wallpaper has no panel");
                    test.capture("reference"); break;
                case 12:
                    host.persistSettings({panelStyle:"wallpaper", wallpaperTransparency:100, popupAnimations:false});
                    test.useWallpaper = false; panel.hoverRequested = true; break;
                case 13:
                    var wallpaper = test.find(panel.surface.cardItem, "panelWallpaper");
                    if ((!wallpaper || !wallpaper.ready) && test.waits++ < 12) { test.step--; break; }
                    test.check(wallpaper && wallpaper.ready, "wallpaper link loads behind the panel");
                    test.check(!panel.surface.BackgroundEffect.blurRegion && panel.surface.cardItem.color.a === 1,
                        "wallpaper never reveals windows behind it");
                    thumbnail.showFor(test.find(panel.body, "windowList").itemAtIndex(1), "0x1", panel.surface.cardItem); break;
                case 14:
                    test.check(test.find(thumbnail.cardItem, "previewWallpaper").ready, "preview uses the same wallpaper");
                    console.info("WALLPAPER_GEOMETRY " + JSON.stringify({
                        panel:{x:panel.surface.cardItem.x,y:panel.surface.cardItem.y,width:panel.surface.cardItem.width,height:panel.surface.cardItem.height},
                        preview:{x:thumbnail.screenOrigin.x + thumbnail.cardItem.x,y:thumbnail.screenOrigin.y,width:thumbnail.cardItem.width * test.scale,height:thumbnail.cardItem.height * test.scale},
                        scale:test.scale}));
                    test.capture("aligned-raw"); break;
                case 15:
                    host.persistSettings({wallpaperTransparency:70}); test.useWallpaper = true; break;
                case 16:
                    test.capture("wallpaper-only"); break;
                case 17:
                    host.persistSettings({popupAnimations:true, wallpaperTransparency:100}); test.useWallpaper = false; break;
                case 18:
                    test.capture("popup-raw"); break;
                case 19:
                    host.persistSettings({wallpaperTransparency:70, backgroundBlur:true, backgroundTexture:false});
                    test.useWallpaper = true; break;
                case 20:
                    test.capture("blur"); break;
                case 21:
                    host.persistSettings({backgroundTexture:true}); break;
                case 22:
                    test.capture("effects"); break;
                case 23:
                    host.saveAppearance(Appearance.applyStyle(host.savedAppearance,"tokyo-night","theme",{
                        accent:{mode:"adaptive"},surfaces:{
                            panel:{color:"#26354A",brightness:5},
                            windows:{color:"#192238",brightness:8,opacity:65},
                            menu:{color:"#7F619C",brightness:12,opacity:30},
                            grain:{color:"#77DBFF",opacity:15},wallpaper:{brightness:12}}}));
                    break;
                case 24:
                    test.check(test.find(panel.surface.cardItem,"panelWallpaper").palette.wallpaperBrightness === .12,
                        "custom wallpaper brightness reaches native effect");
                    test.capture("custom-wallpaper"); break;
                case 25:
                    host.persistSettings({panelStyle:"glass"}); test.useWallpaper = false; break;
                case 26:
                    test.capture("custom-transparency"); break;
                case 27:
                    host.persistSettings({panelStyle:"wallpaper"}); test.useWallpaper = true; thumbnail.dismiss();
                    events.mouseClick(test.find(panel.body,"windowList").itemAtIndex(0),80,12,Qt.MiddleButton,Qt.NoModifier,0);
                    break;
                case 28:
                    test.check(panel.opened,"middle button expands hover");
                    events.mouseClick(test.find(panel.surface.cardItem,"windowPanelBackground"),4,12,Qt.MiddleButton,Qt.NoModifier,0);
                    break;
                case 29:
                    test.check(panel.hoverOpened && !panel.opened,"middle button collapses expanded panel");
                    panel.open(); break;
                case 30:
                    panel.body.showSettings(); break;
                case 31:
                    test.check(test.find(panel.body,"authorCredit").text.indexOf(host.version) !== -1,"native footer version");
                    test.capture("custom-settings"); break;
                case 32:
                    panel.body.mode = "appearance"; break;
                case 33:
                    var editor = test.find(panel.body,"appearanceEditor");
                    editor.selectTarget("windows"); panel.body.ensureVisible(test.find(editor,"appearanceLivePreview")); break;
                case 34:
                    test.capture("wallpaper-editor-preview"); break;
                case 35:
                    host.persistSettings({panelStyle:"glass"}); break;
                case 36:
                    test.capture("transparency-editor-preview"); break;
                case 37:
                    panel.body.back(); panel.body.back(); host.persistSettings({panelStyle:"wallpaper"});
                    break;
                case 38:
                    host.persistSettings({backgroundBlur:false, backgroundTexture:false});
                    test.useWallpaper = false; wallpaperProvider.path = "/nonexistent-windowpeek-wallpaper-test"; break;
                case 39:
                    test.useWallpaper = false;
                    if ((String(wallpaperProvider.source) !== "" || test.find(panel.surface.cardItem,"panelWallpaper").ready)
                        && test.waits++ < 12) { test.step--; break; }
                    test.check(String(wallpaperProvider.source) === "" && !test.find(panel.surface.cardItem,"panelWallpaper").ready,
                        "missing wallpaper falls back to an opaque surface");
                    test.capture("fallback"); break;
                case 40:
                    thumbnail.dismiss(); panel.close(); test.showing = false; wallpaperProvider.observe(test, false);
                    test.check(!wallpaperProvider.active, "wallpaper observation stops on close");
                    console.info("WINDOWPEEK_TEST_PASS: native wallpaper, transparency, blur and texture"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
