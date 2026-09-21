import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui as Ui
import qs.Commons
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

ShellRoot {
    id: test
    property int step: 0
    property int waits: 0
    property bool showing: false
    property bool checking: false
    property int frames: 0
    readonly property bool compileOnly: Quickshell.env("WINDOWPEEK_TEST_COMPILE_ONLY") === "1"
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(value, message) { if (!value) throw new Error(message); }
    function waitFor(value) { if (value) { waits=0;return false; } check(waits++<35,"opening timed out");step--;return true; }
    function fail(error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); timer.stop();Qt.quit(); }
    function capture(name) {
        var prefix = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
        if (prefix) panel.surface.cardItem.grabToImage(function(result) { result.saveToFile(prefix+"-"+name+".png"); });
    }
    FakeHost {
        id: host; bar:api; themeId:"bright-test"
        settings:({panelStyle:"wallpaper",hintsMode:"off",popupAnimations:true})
        wallpaperSource:"file://" + Quickshell.env("WINDOWPEEK_TEST_PROFILE") + "/bright.ppm"
        Component.onCompleted: savedAppearance=Appearance.normalize({uiScale:test.scale})
    }
    Ui.PluginBarApi { id:api;pluginId:"sarr.windowpeek.contrast.test";position:"top";barSize:28 }
    FileView { id: themeName; path: Color.currentThemePath + "/../theme.name"; blockWrites: true }
    PanelWindow {
        id:bar;visible:test.showing
        anchors {top:true;left:true;right:true}
        implicitHeight:28;exclusionMode:ExclusionMode.Ignore;color:"transparent"
        WlrLayershell.keyboardFocus:WlrKeyboardFocus.None;mask:Region {}
        Item {id:anchor;x:80;width:140;height:28}
    }
    Plugin.Panel { id:panel;hostWidget:host;bar:api;anchorItem:anchor }
    FrameAnimation {
        running:test.checking
        onTriggered: {
            try {
                if (panel.surface.cardItem.opacity <= 0) return;
                test.frames++;
                test.check(host.wallpaperTransparencyRule.initialized && panel.surface.backgroundReady,
                    "visible frame precedes first-use contrast decision");
                test.check(host.wallpaperTransparency === (host.themeId === "bright-test" ? host.wallpaperTransparencyDefault : 70),
                    "opening uses the correct per-theme default");
            } catch(error) { test.fail(error); }
        }
    }
    Component.onCompleted: if (compileOnly) Qt.callLater(function(){ console.info("WINDOWPEEK_TEST_PASS: compilation only");Qt.quit(); })
    Timer {
        id:timer;interval:100;running:!test.compileOnly;repeat:true
        onTriggered: {
            try {
                switch(test.step++) {
                case 0:
                    Color.shellValues={};Color.background="#1f1f28";Color.foreground="#dcd7ba";
                    themeName.setText(host.themeId); themeName.waitForJob();
                    test.showing=true;break;
                case 1: test.checking=true;panel.hoverRequested=true;break;
                case 2:
                    if(test.waitFor(host.wallpaperTransparencyRule.initialized && panel.surface.cardItem.opacity===1))break;
                    test.check(host.wallpaperTransparency<=12,"bright wallpaper protects small descriptions");
                    test.check(test.frames>0,"opening frames observed");test.capture("bright");break;
                case 4: test.checking=false;panel.hoverRequested=false;panel.close();break;
                case 5:
                    if(test.waitFor(!panel.mapped))break;
                    host.themeId="acceptable-test";
                    themeName.setText(host.themeId); themeName.waitForJob();
                    host.wallpaperSource="file://"+Quickshell.env("WINDOWPEEK_TEST_PROFILE")+"/dark.ppm";
                    test.frames=0;break;
                case 6: test.checking=true;panel.hoverRequested=true;break;
                case 7:
                    if(test.waitFor(host.wallpaperTransparencyRule.initialized && panel.surface.cardItem.opacity===1))break;
                    test.check(host.wallpaperTransparency===70,"acceptable wallpaper remains untouched");
                    test.check(test.frames>0,"second opening frames observed");test.capture("acceptable");break;
                case 9: test.checking=false;panel.hoverRequested=false;panel.close();break;
                case 10:
                    if(test.waitFor(!panel.mapped))break;
                    console.info("WINDOWPEEK_TEST_PASS: first-frame contrast, bright/acceptable themes and native wallpaper");
                    stop();Qt.quit();
                }
            } catch(error) { test.fail(error); }
        }
    }
}
