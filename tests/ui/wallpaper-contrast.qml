import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.Commons
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property int waits: 0
    property int initialDefault: 70
    readonly property string directory: Quickshell.env("WINDOWPEEK_TEST_PROFILE")
    function check(value, message) { if (!value) throw new Error(message); }
    function waiting() {
        if (!checker.pending) { waits = 0; return false; }
        check(waits++ < 40, "analysis settled"); step--; return true;
    }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child,name); if (found) return found; }
        return null;
    }
    function useTheme(name, background, foreground, applyNow) {
        background = background || "#1f1f28"; foreground = foreground || "#dcd7ba";
        themeName.setText(name); themeName.waitForJob();
        themeColors.setText('background="'+background+'"\nforeground="'+foreground+'"\n'); themeColors.waitForJob();
        host.themeId = name;
        if (applyNow !== false) { Color.shellValues = {}; Color.background = background; Color.foreground = foreground; }
    }
    FileView { id: themeName; path: Color.currentThemePath + "/../theme.name"; blockWrites: true }
    FileView { id: themeColors; path: Color.currentThemePath + "/colors.toml"; blockWrites: true }
    FakeHost {
        id: host; themeId: "bright-theme"
        settings: ({panelStyle:"wallpaper",hintsMode:"off"})
        wallpaperSource: "file://" + test.directory + "/bright.ppm"
    }
    Plugin.SettingsContent { id: settings; width: 480; hostWidget: host }
    Plugin.WallpaperContrast {
        id: checker; hostWidget: host; screenSize: Qt.size(1920,1080)
        panelRect: Qt.rect(5,31,500,675)
    }
    Timer {
        interval: 80; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0:
                    test.useTheme("bright-theme");
                    checker.active = true; break;
                case 1:
                    if (test.waiting()) break;
                    test.check(host.wallpaperTransparencyRule.initialized && host.wallpaperTransparency < 60,
                        "extremely bright wallpaper gets one adapted default");
                    test.initialDefault = host.wallpaperTransparencyDefault;
                    host.saveWallpaperTransparency(85);
                    test.check(host.wallpaperTransparencyDefault === test.initialDefault, "manual adjustment preserves reset level");
                    test.useTheme("dark-theme"); host.wallpaperSource = "file://" + test.directory + "/dark.ppm"; break;
                case 2:
                    if (test.waiting()) break;
                    test.check(host.wallpaperTransparencyRule.initialized && host.wallpaperTransparency === 70,
                        "acceptable wallpaper keeps 70 percent");
                    test.useTheme("bright-theme"); break;
                case 3:
                    test.check(host.wallpaperTransparency === 85 && !checker.pending, "revisiting with another wallpaper preserves manual choice");
                    var control = test.find(settings,"backgroundTransparencyControl");
                    test.check(control.defaultValue === test.initialDefault, "slider displays this theme's reset level");
                    test.find(control,"resetDefaultButton").clicked();
                    test.check(host.wallpaperTransparency === test.initialDefault, "reset returns to adapted theme default");
                    test.useTheme("dark-theme");
                    test.check(host.wallpaperTransparency === 70, "reset does not affect other themes");
                    test.useTheme("manual-first"); control.changed(61); break;
                case 4:
                    test.check(host.wallpaperTransparency === 61 && !checker.pending, "manual choice cancels pending initialization");
                    test.check(host.settings.wallpaperTransparency === undefined, "slider never writes a shared transparency");
                    test.useTheme("missing-theme"); host.wallpaperSource = "file://" + test.directory + "/missing.ppm"; break;
                case 5:
                    if (test.waiting()) break;
                    test.check(!host.wallpaperTransparencyRule.initialized && host.wallpaperTransparency === 70,
                        "missing image opens with old value and does not cache a false assessment");
                    test.useTheme("stale-theme"); host.wallpaperSource = "file://" + test.directory + "/bright.ppm"; break;
                case 6:
                    test.useTheme("dark-theme"); break;
                case 7:
                    test.check(!checker.pending && host.wallpaperTransparency === 70, "late result never overwrites new theme");
                    test.useTheme("failed-save"); host.rejectSave = true; break;
                case 8:
                    if (test.waiting()) break;
                    test.check(!host.wallpaperTransparencyRule.initialized && host.wallpaperTransparency === 70 && host.saveFailed,
                        "failed persistence retains existing transparency without blocking opening");
                    host.rejectSave = false;
                    // Theme name arrives before the background transition applies colors.
                    test.useTheme("latte-test", "#eff1f5", "#4c4f69", false); break;
                case 12:
                    test.check(!host.wallpaperTransparencyRule.initialized,
                        "new theme must not save a default from the previous theme's pale text");
                    Color.background = "#eff1f5"; Color.foreground = "#4c4f69"; break;
                case 13:
                    if (test.waiting()) break;
                    test.check(host.wallpaperTransparency === 70 && host.wallpaperTransparencyDefault === 70,
                        "readable dark text retains 70 percent after delayed palette application");
                    test.useTheme("manual-first");
                    test.check(host.wallpaperTransparency === 61, "another theme keeps its manually chosen level");
                    console.info("WINDOWPEEK_TEST_PASS: first-use contrast, palette transition, theme isolation, reset, manual priority, missing/stale/failed samples");
                    stop(); Qt.quit();
                }
            } catch(error) { console.error("WINDOWPEEK_TEST_FAIL step " + (test.step-1) + ": " + error); stop(); Qt.quit(); }
        }
    }
}
