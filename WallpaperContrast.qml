import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Settings.js" as Settings

Scope {
    id: root
    required property var hostWidget
    property bool active: false
    property size screenSize
    property rect panelRect
    readonly property string theme: hostWidget ? hostWidget.themeId : ""
    readonly property url source: hostWidget ? hostWidget.wallpaperSource : ""
    readonly property string paletteKey: JSON.stringify([Color.foreground, Color.background,
        Color.themeShellValues, Color.popups.text, hostWidget ? hostWidget.surfaces.panel : "",
        hostWidget ? hostWidget.surfaces.wallpaperBrightness : 0])
    readonly property bool eligible: active && !!hostWidget && hostWidget.settingsReady
        && !!theme && !Settings.wallpaperRule(hostWidget.effectiveSettings, theme).initialized
    readonly property bool pending: eligible && !settled
    property bool settled: false
    property int generation: 0

    function restart() {
        generation++; worker.running = false; deadline.stop(); delay.stop();
        settled = false;
        if (eligible) { delay.restart(); deadline.restart(); }
    }
    onEligibleChanged: restart()
    onThemeChanged: restart()
    onSourceChanged: restart()
    onPaletteKeyChanged: restart()
    onScreenSizeChanged: if (pending && !worker.running) delay.restart()
    onPanelRectChanged: if (pending && !worker.running) delay.restart()
    Connections {
        target: root.hostWidget
        function onWallpaperPendingChanged() { if (root.pending) delay.restart(); }
    }
    Timer {
        id: delay; interval: 40
        onTriggered: {
            if (!root.eligible || root.settled || worker.running) return;
            if (root.hostWidget.wallpaperPending) return;
            if (!String(root.source)) { root.settled = true; deadline.stop(); return; }
            if (root.screenSize.width <= 0 || root.screenSize.height <= 0
                    || root.panelRect.width <= 0 || root.panelRect.height <= 0) { delay.restart(); return; }
            worker.requestedTheme = root.theme; worker.requestedSource = String(root.source);
            worker.requestedGeneration = root.generation; worker.result = "";
            worker.command = ["python3", "-I", "-B",
                decodeURIComponent(Qt.resolvedUrl("wallpaper_contrast.py").toString().replace(/^file:\/\//, "")),
                JSON.stringify({source: String(root.source),
                    screen: [root.screenSize.width, root.screenSize.height],
                    panel: [root.panelRect.x, root.panelRect.y, root.panelRect.width, root.panelRect.height],
                    foreground: String(Color.popups.text), tint: String(root.hostWidget.surfaces.panel),
                    brightness: root.hostWidget.surfaces.wallpaperBrightness,
                    transparency: root.hostWidget.wallpaperTransparency,
                    themeState: {directory: Color.currentThemePath, theme: root.theme,
                        foreground: String(Color.foreground), background: String(Color.background),
                        shell: Color.themeShellValues}})];
            worker.running = true;
        }
    }
    Timer { id: deadline; interval: 3000; onTriggered: { root.settled = true; worker.running = false; } }
    Process {
        id: worker
        property string requestedTheme: ""
        property string requestedSource: ""
        property int requestedGeneration: -1
        property string result: ""
        stdout: StdioCollector { onStreamFinished: worker.result = text }
        onExited: function(code) {
            if (!root.eligible || root.settled || root.generation !== requestedGeneration
                    || root.theme !== requestedTheme || String(root.source) !== requestedSource) return;
            try {
                var response = code === 0 ? JSON.parse(result) : {};
                if (response.retry === true) { delay.restart(); return; }
                deadline.stop(); root.settled = true;
                var value = Settings.backgroundTransparency(response.value, null);
                // A manual adjustment, theme switch or the other monitor may have won.
                if (value !== null && !Settings.wallpaperRule(root.hostWidget.requestedSettings, requestedTheme).initialized)
                    root.hostWidget.persistSettings(Settings.setWallpaperTransparency(
                        root.hostWidget.requestedSettings, requestedTheme, value, value));
            } catch (error) { deadline.stop(); root.settled = true; }
        }
    }
}
