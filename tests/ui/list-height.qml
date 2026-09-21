import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property var list: null
    property real screenSpace: 1000
    property real savedHeight: 0
    property real savedScroll: 0
    property point previewPosition
    property bool capturing: false
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    function checkFit(label) {
        check(panel.height <= panel.maximumHeight + 0.01, label + ": fits the available screen");
        var bottom = 0, count = 0;
        for (var i = 0; i < panel.rows.length; i++) {
            var row = list.itemAtIndex(i);
            if (row.y >= list.height - 0.01) break;
            check(row.y + row.height <= list.height + 0.01, label + ": no clipped row or heading");
            if (panel.rows[i].kind === "window") { bottom = row.y + row.height; count++; }
        }
        check(count > 0 && list.height - bottom >= -0.01 && list.height - bottom < 1 / scale + 0.01,
            label + ": ends at a complete window, with at most one pixel of rounding");
    }
    function pickPreview(item, x, y) {
        var picker = find(panel,"appearancePreviewPicker");
        var point = item.mapToItem(picker,x,y);
        var editor = find(panel,"editorScroll");
        var viewportPoint = item.mapToItem(editor,x,y);
        check(viewportPoint.y >= 0 && viewportPoint.y < editor.height,"sample click is inside the visible viewport");
        previewPosition = picker.mapToItem(window.contentItem,0,0);
        savedScroll = editor.contentY;
        check(events.mouseClick(picker,point.x,point.y,Qt.LeftButton,Qt.NoModifier,0),"sample receives a real click");
    }
    function checkPreviewPosition(target) {
        var picker = find(panel,"appearancePreviewPicker");
        var point = picker.mapToItem(window.contentItem,0,0);
        check(find(panel,"colorTargetPicker").value === target,"sample selects " + target);
        check(point.x === previewPosition.x && point.y === previewPosition.y
            && find(panel,"editorScroll").contentY === savedScroll,
            "preview stays under the pointer after controls for " + target + " settle");
    }
    function capture(suffix, next) {
        var prefix = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
        if (!prefix) { next(); return; }
        capturing = true;
        window.contentItem.grabToImage(function(result) {
            result.saveToFile(prefix + suffix + ".png");
            test.capturing = false; next();
        });
    }
    TestEvent { id: events }
    FakeHost {
        id: host
        Component.onCompleted: {
            var data = JSON.parse(JSON.stringify(snapshot));
            for (var i = 6; i <= 20; i++) data.clients.push({address: "0x" + i.toString(16),
                class: "foot", app: "Terminal", title: "Fictional window " + i,
                workspace: {id: -99, name: "special:scratchpad"}});
            snapshot = data;
        }
    }
    Window {
        id: window; visible: true
        width: 500 * test.scale; height: (panel.height + 34) * test.scale
        color: Color.popups.background
        Rectangle { anchors.fill: parent; color: Color.popups.background; border.width: 1; border.color: host.accent }
        Plugin.PanelContent {
            id: panel; hostWidget: host
            x: 17 * test.scale; y: 17 * test.scale; width: 466
            maximumHeight: test.screenSpace / test.scale - 34
            height: Math.min(Math.ceil(implicitHeight * test.scale) / test.scale, maximumHeight)
            scale: test.scale; transformOrigin: Item.TopLeft
        }
    }
    Timer {
        interval: 160; repeat: true; running: true
        onTriggered: {
            if (test.capturing) return;
            try {
                switch (test.step++) {
                case 0:
                    Color.shellValues = ({}); Color.background = "#1b1b26";
                    Color.foreground = "#b7bedb"; Color.accent = host.accent;
                    panel.begin(); test.list = test.find(panel, "windowList"); break;
                case 1:
                    test.checkFit("expanded");
                    test.capture("-expanded", function() {
                        test.savedHeight = panel.height;
                        events.mouseWheel(test.list, 80, 100, Qt.NoButton, Qt.NoModifier, 0, -120, 0);
                    }); break;
                case 2:
                    test.list.cancelFlick(); test.savedScroll = test.list.contentY;
                    test.check(test.savedScroll > 0 && panel.height === test.savedHeight, "scrolling does not resize the panel");
                    var data = JSON.parse(JSON.stringify(host.snapshot));
                    data.clients[0].title = "An updated window title that should not change the panel size";
                    host.snapshot = data; break;
                case 3:
                    test.check(panel.height === test.savedHeight && test.list.contentY === test.savedScroll,
                        "title refresh preserves height and scroll position");
                    test.list.positionViewAtBeginning();
                    // The screen could fit the next workspace header, but not its first window.
                    var header = test.list.itemAtIndex(3);
                    test.screenSpace = (panel.listChromeHeight + header.y + header.height + 2 + 34) * test.scale;
                    break;
                case 4:
                    test.checkFit("small screen");
                    test.check(test.list.itemAtIndex(3).y >= test.list.height, "no orphan workspace heading at the bottom");
                    test.capture("-constrained", function() {
                        test.screenSpace = 1000;
                        host.saveAppearance({tooltipStyle: "compact"});
                    }); break;
                case 5:
                    test.checkFit("compact");
                    panel.expanded = false; panel.expansion = 0; break;
                case 6:
                    test.checkFit("compact hover");
                    host.saveAppearance({tooltipStyle: "panel"}); break;
                case 7:
                    test.checkFit("spacious hover");
                    test.capture("-hover", function() {
                        panel.expanded = true; panel.expansion = 1; panel.searchField.text = "Project notes";
                    }); break;
                case 8:
                    test.checkFit("filtered");
                    test.check(test.list.contentHeight <= test.list.height + 0.01 && !test.list.scrollbar.visible,
                        "short results fit without a scrollbar");
                    panel.searchField.text = "No matching fictional window"; break;
                case 9:
                    test.check(panel.matches.length === 0 && panel.height > panel.listChromeHeight
                        && Number.isFinite(panel.height), "empty results retain room for their message");
                    test.screenSpace = 3000 * test.scale;
                    panel.mode = "appearance"; break;
                case 10:
                    var editor = test.find(panel, "editorScroll");
                    test.check(panel.height > 540 && editor.contentHeight <= editor.height + 1,
                        "color editor fits its full contents when the monitor has room");
                    test.screenSpace = 800; break;
                case 11:
                    var editor = test.find(panel, "editorScroll");
                    test.check(editor.contentY === 0,"opening Colors starts at the preview without scrolling to HEX");
                    test.check(Math.abs(panel.height - panel.maximumHeight) < 1 && editor.contentHeight > editor.height,
                        "color editor uses all available height and scrolls on smaller screens");
                    var apply = test.find(panel, "applyButton");
                    panel.ensureVisible(apply); break;
                case 12:
                    var editor = test.find(panel, "editorScroll");
                    var apply = test.find(panel, "applyButton");
                    var point = apply.mapToItem(editor, 0, 0);
                    test.check(point.y >= -1 && point.y + apply.height <= editor.height + 1,
                        "Apply remains reachable at either scale");
                    editor.contentY = 0;
                    break;
                case 13:
                    test.find(panel,"editorScroll").contentY = Style.space(24);
                    var sample = test.find(panel,"appearanceWindowSample");
                    var row = test.find(sample,"windowList").itemAtIndex(1).item;
                    test.pickPreview(row,row.width/2,row.height/2); break;
                case 14:
                    test.checkPreviewPosition("windows");
                    var sample = test.find(panel,"appearanceWindowSample");
                    test.pickPreview(sample,sample.width/2,8); break;
                case 15:
                    test.checkPreviewPosition("panel");
                    host.persistSettings({panelStyle:"wallpaper"});
                    var preview = test.find(panel,"appearanceLivePreview");
                    test.pickPreview(preview,preview.width-2,2); break;
                case 16:
                    test.checkPreviewPosition("wallpaper");
                    test.capture("-appearance-top", function() {});
                    break;
                case 17:
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL at " + (test.step - 1) + ": " + error); stop(); Qt.quit(); }
        }
    }
}
