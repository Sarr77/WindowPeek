import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance
import "WindowPeek/I18n.js" as I18n

ShellRoot {
    id: test
    property int step: 0
    property int locale: 0
    property var original: null
    property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(value, message) { if (!value) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var i = 0; i < item.children.length; i++) { var result = find(item.children[i], name); if (result) return result; }
        return null;
    }
    function header(item, workspaceId) {
        if (item.objectName === "workspaceHeader" && item.row.workspaceId === workspaceId) return item;
        for (var i = 0; i < item.children.length; i++) { var result = header(item.children[i], workspaceId); if (result) return result; }
        return null;
    }
    FakeHost {
        id: host; includeSpecial: false
        Component.onCompleted: savedAppearance = Appearance.normalize({uiScale: test.scale,
            tooltipStyle: Quickshell.env("WINDOWPEEK_TEST_STYLE")})
    }
    Window {
        id: window; visible: true
        width: preview.implicitWidth * test.scale
        height: preview.implicitHeight * test.scale
        color: "transparent"
        Plugin.TooltipContent {
            id: preview; hostWidget: host
            width: implicitWidth; height: implicitHeight
            maximumHeight: Math.min(560, 980 / test.scale)
            scale: test.scale; transformOrigin: Item.TopLeft
        }
    }
    Timer {
        interval: 60; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0:
                    test.original = JSON.parse(JSON.stringify(host.snapshot));
                    test.check(preview.preview.count === 4 && preview.preview.sections.length === 3, "ordinary windows on three workspaces");
                    test.check(preview.preview.sections[0].windows[0].active, "active window first");
                    test.check(!test.find(test.header(preview, 1), "hiddenWorkspace").visible
                        && !test.find(test.header(preview, 4), "hiddenWorkspace").visible,
                        "workspaces displayed on either monitor have no status label");
                    test.check(test.find(test.header(preview, -1337), "hiddenWorkspace").visible, "inactive named workspace is marked hidden");
                    host.persistSettings({includeSpecial: true}); break;
                case 1:
                    test.check(preview.preview.count === 5, "special setting changes preview and count");
                    test.check(test.find(test.header(preview, -99), "hiddenWorkspace").visible, "closed scratchpad is marked hidden");
                    var shown = JSON.parse(JSON.stringify(host.snapshot));
                    shown.monitors[1].activeWorkspace = {id: -1337};
                    shown.monitors[1].specialWorkspace = {id: -99};
                    host.snapshot = shown;
                    host.persistSettings({hintsUsed:100, hintsMode:"auto"}); break;
                case 2:
                    test.check(!preview.showHint && preview.preview.count === 5, "preview remains after help budget expires");
                    test.check(test.find(test.header(preview, 4), "hiddenWorkspace").visible
                        && !test.find(test.header(preview, -1337), "hiddenWorkspace").visible
                        && !test.find(test.header(preview, -99), "hiddenWorkspace").visible,
                        "workspace switch and opening scratchpad update only the hidden markers");
                    host.persistSettings({includeSpecial:false, hintsMode:"on"});
                    var many = JSON.parse(JSON.stringify(test.original));
                    for (var i = 6; i <= 20; i++) many.clients.push({address:"0x" + i.toString(16), class:"foot", app:"Terminal",
                        title:"Build output · long project title <b>plain text</b>", workspace:{id:i % 4 + 1, name:String(i % 4 + 1)}});
                    many.activeAddress = "0x14"; host.snapshot = many; break;
                case 3:
                    var visible = preview.preview.sections.reduce(function(n, s) { return n + s.windows.length; }, 0);
                    test.check(visible === 19 && preview.preview.count === 19 && preview.preview.sections.length === 5, "all windows and workspaces remain in the preview");
                    test.check(preview.preview.sections[0].windows[0].address === "0x14", "active window first in the full list");
                    break;
                case 4: host.setLanguage(I18n.languages[test.locale++].code); break;
                case 5:
                    test.check(preview.implicitHeight <= preview.maximumHeight, "preview fits height in " + host.language);
                    var header = test.find(preview, "workspaceHeader");
                    var monitor = test.find(header, "workspaceMonitor");
                    var name = test.find(header, "workspaceName");
                    var monitorX = monitor.mapToItem(header, 0, 0).x;
                    var nameX = name.mapToItem(header, 0, 0).x;
                    test.check(Math.abs(preview.rtl ? monitorX : monitorX + monitor.width - header.width) < 1,
                        "monitor stays at the trailing edge in " + host.language);
                    test.check(preview.rtl ? nameX >= monitorX + monitor.width : nameX + name.width <= monitorX,
                        "workspace name and monitor do not overlap in " + host.language);
                    if (test.locale < I18n.languages.length) test.step = 4;
                    else {
                        if (!Quickshell.env("WINDOWPEEK_TEST_DENSE")) host.snapshot = test.original;
                        host.setLanguage("pl");
                    }
                    break;
                case 6:
                    var file = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
                    if (file) preview.grabToImage(function(result) {
                        test.check(result.saveToFile(file), "preview image saved");
                        console.info("WINDOWPEEK_TEST_PASS"); Qt.quit();
                    }, Qt.size(preview.width * test.scale, preview.height * test.scale));
                    else { console.info("WINDOWPEEK_TEST_PASS"); Qt.quit(); }
                    stop();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
