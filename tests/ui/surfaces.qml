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
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child,name); if (found) return found; }
        return null;
    }
    function pick(item, x, y, target, modifiers) {
        var preview = find(editor,"appearanceLivePreview");
        var picker = find(preview,"appearancePreviewPicker");
        var point = item.mapToItem(picker,x,y);
        var before = preview.mapToItem(window.contentItem,0,0);
        var draft = JSON.stringify(editor.draft), saved = JSON.stringify(host.savedAppearance);
        check(events.mouseClick(picker,point.x,point.y,Qt.LeftButton,modifiers || Qt.NoModifier,0),"preview receives real click");
        check(editor.colorTarget === target && find(editor,"colorTargetPicker").value === target,"click selects " + target);
        check(JSON.stringify(editor.draft) === draft && JSON.stringify(host.savedAppearance) === saved,"selection preserves draft and saved values");
        check(!host.focused && !host.moved && !host.brought && !host.destinationRequested,"sample never invokes window actions");
        editor.forceLayout();
        var after = preview.mapToItem(window.contentItem,0,0);
        check(before.x === after.x && before.y === after.y,"picking " + target + " keeps preview under the pointer");
    }
    TestEvent { id: events }
    FakeHost {
        id: host
        Component.onCompleted: savedAppearance = Appearance.normalize({uiScale:test.scale})
    }
    Window {
        id: window; visible:true; width:500*test.scale; height:(editor.height+24)*test.scale
        minimumHeight: (editor.height+24)*test.scale
        Plugin.AppearanceEditor { id:editor; width:480; hostWidget:host; scale:test.scale; transformOrigin:Item.TopLeft }
    }
    Timer {
        interval:100; repeat:true; running:true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0:
                    var originalShell = Color.shellValues;
                    Color.shellValues = {"popups.background":"#112233", "popups.background-alpha":"0.4"};
                    test.check(host.surfaces.baseColor("panel") === "#112233",
                        "theme alpha must not turn the RGB editor fallback white");
                    test.check(Math.abs(host.surfaces.panel.a - .4) < .005,
                        "unmodified solid panel preserves theme opacity");
                    host.persistSettings({panelStyle:"wallpaper"});
                    test.check(String(host.surfaces.panel) === "#112233",
                        "wallpaper uses theme RGB and its independent transparency");
                    host.persistSettings({panelStyle:"solid"}); Color.shellValues = originalShell;
                    editor.begin(); editor.selectTarget("windows");
                    test.find(editor,"colorTargetPicker").changed("windows");
                    editor.changeRule("custom","theme","#204060");
                    test.find(editor,"surfaceBrightnessControl").changed(20);
                    test.find(editor,"surfaceOpacityControl").changed(65);
                    break;
                case 1:
                    var preview = test.find(editor,"appearanceLivePreview");
                    test.check(preview.y + preview.height < test.find(editor,"colorTargetPicker").y,
                        "preview precedes all changing editing controls");
                    test.check(preview.height >= 250 && preview.height <= 400,"background preview keeps a bounded, visible size");
                    test.check(String(host.surfaces.windows) === "#4d6680" && Math.abs(host.surfaces.windowOpacity-.35)<.001,
                        "row color, brightness and transparency preview together");
                    test.check(host.savedAppearance.surfaceColors.windows === undefined,"draft does not persist before Apply");
                    editor.selectTarget("panel"); editor.changeRule("custom","all","#112233");
                    editor.selectTarget("menu"); editor.changeRule("custom","theme","#884422");
                    test.find(editor,"surfaceOpacityControl").changed(55);
                    editor.selectTarget("grain"); editor.changeRule("custom","theme","#00CCFF");
                    test.find(editor,"surfaceOpacityControl").changed(12);
                    editor.selectTarget("wallpaper");
                    test.check(!test.find(editor,"colorPlane").visible,"wallpaper exposes brightness without a meaningless color picker");
                    test.find(editor,"surfaceBrightnessControl").changed(18);
                    editor.editPreset(""); test.find(editor,"presetNameInput").text = "Surfaces"; editor.savePreset();
                    editor.apply();
                    break;
                case 2:
                    test.check(host.surfaces.customMenu && Math.abs(host.surfaces.menuOpacity-.45)<.001,"menu fill independent from row fill");
                    test.check(host.surfaces.customGrain && Math.abs(host.surfaces.grainOpacity-.12)<.001,"grain has separate color and intensity");
                    test.check(host.surfaces.wallpaperBrightness === .18,"wallpaper brightness reaches backdrop");
                    host.themeId = "nord";
                    test.check(String(host.surfaces.panel) === "#112233","all-theme panel tint survives theme change");
                    test.check(host.surfaces.rule("windows").color === "","theme row tint does not leak to other themes");
                    editor.begin(); editor.choosePreset(editor.draft.colorPresets[0]); editor.apply();
                    test.check(host.surfaces.rule("windows").color === "#204060","full preset can be applied to another theme");
                    editor.begin(); editor.resetStyle();
                    test.check(host.surfaces.rule("grain").color === "","whole-scope reset previews defaults");
                    editor.cancel();
                    test.check(host.surfaces.rule("grain").color === "#00CCFF","Cancel restores the complete saved style");
                    host.rejectSave = true; editor.begin(); editor.resetStyle(); editor.apply();
                    test.check(editor.saveFailed,"failed style write keeps editor open");
                    editor.cancel(); host.rejectSave = false;
                    editor.begin(); editor.resetStyle(); editor.apply();
                    host.themeId = "tokyo-night";
                    test.check(host.surfaces.rule("windows").color === "#204060","reset preserves the other theme");
                    test.check(host.savedAppearance.colorPresets.length === 1,"reset retains preset library");
                    editor.begin(); editor.selectTarget("windows"); editor.changeSurfaceValue("brightness",-55);
                    editor.restoreSavedColor();
                    test.check(host.surfaces.rule("windows").brightness === 20,"restore restores brightness and color");
                    editor.resetColor();
                    test.check(host.surfaces.rule("windows").color === "" && host.surfaces.rule("menu").color === "#884422",
                        "single-element reset leaves other roles intact");
                    editor.cancel();
                    editor.begin(); editor.selectTarget("windows"); editor.changeRule("custom","theme","#ABCDEF");
                    break;
                case 3: case 4: case 5:
                    var live = test.find(editor,"appearanceLivePreview");
                    var sample = test.find(live,"appearanceWindowSample");
                    var menu = test.find(live,"appearanceMenuSample");
                    var list = test.find(sample,"windowList");
                    var row = list.itemAtIndex(1).item;
                    test.pick(sample,sample.width/2,8,"panel");
                    test.pick(row,row.width/2,row.height/2,"windows",Qt.ControlModifier);
                    var label = test.find(row,"activeWindowLabel");
                    test.pick(label,label.width/2,label.height/2,"accent");
                    var marker = test.find(row,"activeWindowMarker");
                    test.pick(marker,marker.width/2,marker.height/2,"accent");
                    test.pick(sample,1,sample.height/2,"accent");
                    test.pick(menu,menu.width/2,menu.height/2,"menu");
                    if (host.panelStyle === "wallpaper") test.pick(live,live.width-2,2,"wallpaper");
                    if (test.step === 4) { host.persistSettings({panelStyle:"wallpaper"}); host.language="ar"; }
                    else if (test.step === 5) { host.persistSettings({panelStyle:"glass"}); host.language="en"; }
                    else {
                        editor.cancel();
                        test.check(host.surfaces.rule("windows").color === "#204060","Cancel still discards colors after preview selections");
                        console.info("WINDOWPEEK_TEST_PASS: surface colors/presets and real preview clicks in all backgrounds, RTL, draft safety and no window actions");
                        stop();
                        var path=Quickshell.env("WINDOWPEEK_TEST_IMAGE");
                        if (path) capture.start();
                        else Qt.quit();
                    }
                    break;
                }
            } catch(error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
    Timer {
        id: capture; interval:100
        onTriggered: window.contentItem.grabToImage(function(result) {
            result.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE")); Qt.quit();
        })
    }
}
