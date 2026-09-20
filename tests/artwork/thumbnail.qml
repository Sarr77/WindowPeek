import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin

ShellRoot {
    id: fixture
    property var previewCard: null
    function sharpen(item) {
        if (item.appId !== undefined && item.imageScale !== undefined) item.imageScale = 3;
        for (var child of item.children) sharpen(child);
    }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children) { var result = find(child, name); if (result) return result; }
        return null;
    }
    FakeHost { id: host }
    Plugin.WindowThumbnail { id: thumbnail; hostWidget: host; address: "0x1" }
    Window {
        id: window; visible: true
        width: 320; height: 238; color: "transparent"
    }
    Component {
        id: sourceWindow
        Item {
            readonly property bool hasContent: true
            FictionalEditor {
                anchors.centerIn: parent
                scale: Math.min(parent.width / width, parent.height / height)
            }
        }
    }
    Timer {
        interval: 800; running: true
        onTriggered: {
            Color.shellValues = ({});
            Color.background = "#1b1b26";
            Color.foreground = "#b7bedb";
            Color.accent = host.accent;
            thumbnail.modifierState.enabled = false;
            fixture.previewCard = fixture.find(thumbnail.contentItem, "windowThumbnailCard");
            var capture = fixture.find(thumbnail.contentItem, "windowThumbnailCapture");
            fixture.previewCard.parent = window.contentItem;
            fixture.previewCard.x = 0;
            window.width = fixture.previewCard.width;
            window.height = fixture.previewCard.height;
            capture.sourceComponent = sourceWindow;
            capture.active = true;
            fixture.sharpen(fixture.previewCard);
            save.start();
        }
    }
    Timer {
        id: save; interval: 350
        onTriggered: fixture.previewCard.grabToImage(function(result) {
            if (!result.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE")))
                console.error("WINDOWPEEK_TEST_FAIL: save");
            else console.info("WINDOWPEEK_TEST_PASS: production preview frame with fictional source content");
            Qt.quit();
        }, Qt.size(fixture.previewCard.width * 3, fixture.previewCard.height * 3))
    }
}
