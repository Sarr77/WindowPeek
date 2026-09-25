import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import qs.Ui as Ui
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

ShellRoot {
    id: test
    readonly property bool compileOnly: Quickshell.env("WINDOWPEEK_TEST_COMPILE_ONLY") === "1"
    Component.onCompleted: if (compileOnly) Qt.callLater(function() { console.log("WINDOWPEEK_TEST_PASS"); Qt.quit(); })
    property int step: 0
    property int editorIndex: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var modes: ["labels", "appearance", "scaling", "shortcuts"]
    readonly property var entries: ["openLabelsButton", "openColorsButton", "openScalingButton", "shortcutsEntry"]
    readonly property var body: panel.body
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    function named(name) { return find(body, name); }
    function click(item, reveal) {
        if (reveal) body.ensureVisible(item);
        check(events.mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton, Qt.NoModifier, 0), "click delivered");
    }
    function key(value) { check(events.keyClick(value, Qt.NoModifier, 0), "key delivered"); }
    Process {
        id: dialogKey
        command: [Quickshell.env("WINDOWPEEK_TEST_KEYBOARD"), "None"]
        stdinEnabled: true
        stdout: SplitParser { onRead: function(line) { if (line === "pressed") dialogKey.write("key Esc\n\n"); } }
    }
    FakeHost {
        id: host; bar: barApi
        Component.onCompleted: {
            savedAppearance = Appearance.normalize({uiScale: test.scale});
            wallpaperSource = Qt.resolvedUrl("dropdown-wallpaper.svg");
        }
    }
    Ui.PluginBarApi {
        id: barApi; pluginId: "sarr.windowpeek.test"; moduleName: panel.moduleName
        position: "top"; barSize: 28
        _requestPopout: function(owner) { activePopout = owner; }
        _releasePopout: function(owner) { if (activePopout === owner) activePopout = null; }
    }
    PanelWindow {
        visible: !test.compileOnly
        anchors { top: true; left: true; right: true }
        implicitHeight: 28; color: "transparent"; exclusionMode: ExclusionMode.Ignore
        Item {
            id: anchor; x: 100; width: 150; height: 28
            Text { anchors.centerIn: parent; text: "WindowPeek test"; color: "white" }
            MouseArea { anchors.fill: parent; onClicked: panel.open() }
        }
    }
    Plugin.Panel { id: panel; bar: barApi; anchorItem: anchor; hostWidget: host }
    Item { parent: test.body; TestEvent { id: events } }
    Timer {
        interval: 400; running: !test.compileOnly; repeat: true
        onTriggered: {
            try {
                var row = test.named(test.entries[test.editorIndex]);
                switch(test.step++) {
                case 0: test.click(anchor, false); break;
                case 1:
                    test.check(panel.opened && panel.surface.backingWindowVisible, "bar opens the production layer panel");
                    test.click(test.named("settingsButton"), false); break;
                case 2:
                    test.named("settingsPersonalizationSection").expanded = true;
                    test.named("settingsControlsSection").expanded = true; break;
                case 3: test.click(row, true); break;
                case 4:
                    test.check(test.body.mode === test.modes[test.editorIndex], "mouse opens " + test.modes[test.editorIndex]);
                    test.click(test.named("settingsButton"), false); break;
                case 5:
                    test.check(test.body.mode === "settings" && row.activeFocus && !row.visualFocus && !row.hot,
                        "mouse Back leaves no active highlight: " + test.modes[test.editorIndex]);
                    row.forceActiveFocus(Qt.TabFocusReason); test.key(Qt.Key_Return); break;
                case 6:
                    test.check(test.body.mode === test.modes[test.editorIndex], "keyboard opens editor");
                    test.key(Qt.Key_Escape); break;
                case 7:
                    test.check(test.body.mode === "settings" && row.visualFocus, "Escape restores keyboard focus");
                    if (++test.editorIndex < test.entries.length) { test.step = 3; break; }
                    test.editorIndex = 0;
                    test.click(test.named("openLabelsButton"), true); break;
                case 8:
                    test.check(test.body.mode === "labels", "Custom Text reopens");
                    test.click(test.named("applyLabelsButton"), true); break;
                case 9:
                    test.check(test.body.mode === "settings" && !test.named("openLabelsButton").visualFocus,
                        "mouse Apply leaves no Custom Text highlight");
                    test.named("settingsListSection").expanded = true;
                    test.body.ensureVisible(test.named("wheelScrollSpeedControl")); break;
                case 10:
                    var control = test.named("wheelScrollSpeedControl");
                    var slider = control.children.find(function(item) { return item.from === 50 && item.to === 300; });
                    slider.forceActiveFocus(Qt.TabFocusReason); test.key(Qt.Key_Right);
                    test.check(host.wheelScrollSpeed === 103, "slider saves speed in the layer panel");
                    control.resetRequested();
                    test.check(host.wheelScrollSpeed === 102, "slider resets to 102%");
                    host.persistSettings({panelStyle:"wallpaper"}); barApi.transparent=true;
                    test.named("settingsPersonalizationSection").expanded=true; break;
                case 11:
                    test.click(test.named("followBarStyleToggle"),true);
                    test.check(host.followBarStyle && host.panelStyle==="wallpaper", "follow switch enables on transparent bar");
                    var imagePath=Quickshell.env("WINDOWPEEK_TEST_IMAGE");
                    if (imagePath) panel.surface.cardItem.grabToImage(function(image) { image.saveToFile(imagePath); barApi.transparent=false; });
                    else barApi.transparent=false;
                    break;
                case 12:
                    test.check(host.panelStyle==="solid" && test.named("panelStylePicker").value==="wallpaper",
                        "opaque bar uses Solid without changing dropdown selection");
                    barApi.transparent=true; break;
                case 13:
                    test.check(host.panelStyle==="wallpaper", "transparent bar restores Wallpaper");
                    test.click(test.named("followBarStyleToggle"),true);
                    barApi.transparent=false;
                    test.check(!host.followBarStyle && host.panelStyle==="wallpaper", "follow switch can be disabled");
                    test.click(test.named("settingsLogoPicker"),true); break;
                case 14:
                    var options=test.find(test.body.Window.window.contentItem,"optionList");
                    test.check(!!options && options.visible,"logo options open on click");
                    options.currentIndex=2;options.forceActiveFocus();test.key(Qt.Key_Return);
                    test.step=21; break;
                case 21:
                    test.check(test.named("logoSettings").picking,"image chooser opens inside the panel");
                    var path = test.find(test.body.Window.window.contentItem,"logoFolderPath");
                    test.check(!!path,"chooser belongs to panel surface");
                    path.text=Quickshell.env("WINDOWPEEK_TEST_PROFILE");path.accepted();test.step=15;break;
                case 15:
                    var files=test.find(test.body.Window.window.contentItem,"logoFileList");
                    var index=files.model.indexOf(Qt.resolvedUrl("dropdown-wallpaper.svg"));
                    test.check(index>=0,"local image is listed");
                    files.currentIndex=index;files.forceActiveFocus();test.key(Qt.Key_Return);break;
                case 16:
                    test.check(test.find(test.body.Window.window.contentItem,"logoImagePreview").status===Image.Ready,"selected file previews before saving");
                    test.check(host.settingsLogoImage==="","selection alone does not change logo");
                    var capturePath=Quickshell.env("WINDOWPEEK_TEST_IMAGE");
                    if (capturePath) test.find(test.body.Window.window.contentItem,"logoImagePreview").parent.grabToImage(function(image) {
                        image.saveToFile(capturePath+".picker.png");
                        test.click(test.find(test.body.Window.window.contentItem,"acceptLogoImage"),false);
                    });
                    else test.click(test.find(test.body.Window.window.contentItem,"acceptLogoImage"),false);
                    break;
                case 17:
                    test.check(host.settingsLogoImage===String(Qt.resolvedUrl("dropdown-wallpaper.svg")),"Apply persists selected image");
                    test.named("settingsLogoPicker").changed("image");break;
                case 18: dialogKey.running=true; break;
                case 19:
                    test.check(!test.named("logoSettings").picking && panel.opened,"Escape closes only the image chooser: picking="+test.named("logoSettings").picking+" panel="+panel.opened+" mode="+test.body.mode);
                    test.check(host.settingsLogoImage===String(Qt.resolvedUrl("dropdown-wallpaper.svg")),"cancel leaves saved image intact");
                    panel.close(); break;
                case 20:
                    test.check(!panel.opened, "panel closes cleanly");
                    console.log("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit(); break;
                }
            } catch(error) { console.error("WINDOWPEEK_TEST_FAIL step " + (test.step - 1) + ": " + error); stop(); panel.close(); Qt.quit(); }
        }
    }
}
