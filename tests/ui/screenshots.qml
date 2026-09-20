import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons
import qs.Ui as Ui
import "WindowPeek" as Plugin

// Render the actual controls with fictional data; never capture the desktop.
ShellRoot {
    id: fixture
    property int pending: 2
    readonly property real imageScale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function sharpen(item) {
        if (item.appId !== undefined && item.imageScale !== undefined) item.imageScale = imageScale;
        for (var child of item.children) sharpen(child);
    }
    function save(item, suffix) {
        var prefix = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
        if (!prefix) { console.error("WINDOWPEEK_TEST_FAIL: --image needs a path prefix"); Qt.quit(); return; }
        item.grabToImage(function(result) {
            if (!result.saveToFile(prefix + suffix)) {
                console.error("WINDOWPEEK_TEST_FAIL: could not save " + suffix);
                Qt.quit(); return;
            }
            if (--fixture.pending === 0) { console.info("WINDOWPEEK_TEST_PASS"); Qt.quit(); }
        }, Qt.size(Math.round(item.width * imageScale), Math.round(item.height * imageScale)));
    }
    FakeHost {
        id: host
        updatesAvailable: true
        Component.onCompleted: {
            var data = JSON.parse(JSON.stringify(snapshot));
            data.clients[1].class = "windowpeek-example-notes";
            data.clients[1].app = "Notes";
            data.clients[3].workspace = {id: 4, name: "4"};
            data.clients[4].class = "windowpeek-example-music";
            data.clients[4].app = "Music";
            data.clients[4].title = "Music player";
            data.monitors[0].name = "DP-1";
            data.monitors[1].name = "DP-3";
            data.workspaces.push({id: -99, name: "special:scratchpad", monitorID: 8});
            snapshot = data;
        }
    }
    Window {
        visible: true
        width: 500; height: panel.implicitHeight + 34
        color: "transparent"
        Ui.BorderSurface {
            id: card; anchors.fill: parent
            color: Color.popups.background; radius: Style.space(8)
            borderSpec: Border.flat(host.accent, 1); padding: 16
            layer.enabled: true
            Plugin.PanelContent {
                id: panel
                anchors.fill: parent; anchors.margins: 17
                hostWidget: host
            }
        }
    }
    Window {
        visible: true
        width: 420; height: overview.implicitHeight + 34
        color: "transparent"
        Ui.BorderSurface {
            id: hoverCard; anchors.fill: parent
            color: Color.popups.background; radius: Style.space(8)
            borderSpec: Border.flat(host.accent, 1); padding: 16
            layer.enabled: true
            Plugin.PanelContent {
                id: overview
                anchors.fill: parent; anchors.margins: 17
                hostWidget: host; expanded: false; expansion: 0
            }
        }
    }
    Timer {
        interval: 800; running: true
        onTriggered: {
            // A fixed example palette, independent of the developer's current theme.
            Color.shellValues = ({});
            Color.background = "#1b1b26";
            Color.foreground = "#b7bedb";
            Color.accent = host.accent;
            panel.begin(); overview.begin(false); fixture.sharpen(card); fixture.sharpen(hoverCard); capture.start();
        }
    }
    Timer {
        id: capture; interval: 300
        onTriggered: { fixture.save(card, "-panel.png"); fixture.save(hoverCard, "-hover.png"); }
    }
}
