import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Ui
import qs.Commons
import "." as Local
import "I18n.js" as I18n
import "Settings.js" as Settings
import "Appearance.js" as Appearance
import "WindowModel.js" as Model
import "Labels.js" as Labels

BarWidget {
    id: root
    moduleName: "sarr.windowpeek"
    readonly property var runtime: Local.Runtime
    readonly property var inventory: runtime.state.inventory
    readonly property var snapshot: runtime.state.snapshot
    readonly property var effectiveSettings: !settingsReady ? settings
        : (runtime.preferences.hasSavedValues ? runtime.preferences.values : runtime.fallbackSettings)
    function preference(name, fallback) {
        var value = effectiveSettings ? effectiveSettings[name] : undefined;
        return value === undefined || value === null ? fallback : value;
    }
    readonly property var windowPreview: thumbnail
    readonly property string screenName: root.QsWindow.window && root.QsWindow.window.screen ? root.QsWindow.window.screen.name : ""
    readonly property string languageSetting: String(preference("language", "auto"))
    readonly property string detectedLanguage: I18n.language("auto", Qt.locale().uiLanguages, Qt.locale().name)
    readonly property string language: I18n.language(languageSetting, Qt.locale().uiLanguages, Qt.locale().name)
    readonly property var baseWords: I18n.words(language)
    readonly property var savedLabels: Labels.normalize(effectiveSettings)
    readonly property var labels: runtime.labelsPreviewOwner ? runtime.labelsPreview : savedLabels
    readonly property var words: Labels.apply(baseWords, labels)
    readonly property var textTemplates: Labels.templates(baseWords, labels, preference("barLabel", "full"), vertical)
    readonly property bool includeSpecial: preference("includeSpecial", true) === true
    readonly property bool windowPreviews: preference("windowPreviews", true) === true
    readonly property bool openOnHover: preference("openOnHover", true) === true
    readonly property int panelHoverDelay: Settings.hoverDelay(preference("panelHoverDelay", 400))
    readonly property int previewHoverDelay: Settings.hoverDelay(preference("previewHoverDelay", 400))
    readonly property bool popupAnimations: preference("popupAnimations", true) === true
    readonly property bool scrollBounce: preference("scrollBounce", true) === true
    readonly property bool shortcutNumbersRight: preference("shortcutNumbersRight", false) === true
    readonly property var hints: Settings.hints(effectiveSettings)
    readonly property bool autoUpdates: !effectiveSettings || effectiveSettings.autoUpdates === undefined || effectiveSettings.autoUpdates === true
    readonly property bool updatesAvailable: runtime.updates.available
    readonly property string updateStatus: runtime.updates.status
    readonly property var savedAppearance: Appearance.normalize(effectiveSettings)
    readonly property var appearance: runtime.previewOwner ? runtime.previewAppearance : savedAppearance
    readonly property string themeId: runtime.themeId
    readonly property color themeAccent: Color.accent
    readonly property color accent: Appearance.resolve(appearance, themeId, String(themeAccent))
    readonly property real uiScale: appearance.uiScale
    readonly property real requestedBarFont: Style.font.body * appearance.barScale
    readonly property real effectiveBarFont: vertical ? requestedBarFont
        : Math.min(requestedBarFont, requestedBarFont * Math.max(1, barSize - Style.space(4)) / Math.max(1, metrics.height))
    readonly property real effectiveBarScale: effectiveBarFont / Style.font.body
    readonly property bool actionBusy: runtime.actions.busy
    readonly property string actionError: runtime.actions.error
    readonly property bool opened: panelLoader.item ? panelLoader.item.opened || panelLoader.item.opening : false
    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing : false
    property bool settingsReady: false
    readonly property bool saveFailed: runtime.preferences.failed
    readonly property bool hoverOpened: !!panelLoader.item && panelLoader.item.hoverOpened
    readonly property bool moveMenuOpen: !!panelLoader.item && panelLoader.item.destinationMenu.visible
    property string focusBeforePanel: ""
    property bool actionOnClose: false
    property bool reopenOnFailure: false
    property bool hoverDismissed: false
    readonly property bool canShowTooltip: openOnHover && !hoverDismissed && button.tooltipHovered && !opened && (!bar || !bar.activePopout)
    property bool tooltipReady: false
    function scheduleTooltip() {
        tooltipDelay.stop();
        // Dwell opens a new hover. Returning to an existing one retains it immediately.
        tooltipReady = canShowTooltip && (hoverOpened || panelHoverDelay === 0);
        if (canShowTooltip && !tooltipReady) tooltipDelay.start();
    }
    onCanShowTooltipChanged: scheduleTooltip()
    onPanelHoverDelayChanged: scheduleTooltip()
    signal moveCompleted()

    FontMetrics { id: metrics; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: root.requestedBarFont }

    function peers() { return bar ? bar.moduleWidgets(moduleName) : [root]; }
    function onScreen(name) {
        var target = name || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "");
        return peers().find(function(widget) { return widget.screenName === target; }) || root;
    }
    function open() {
        if (!panelLoader.item || opened || actionBusy) return;
        restoreFocus.stop();
        focusBeforePanel = snapshot ? Model.address(snapshot.activeAddress) : "";
        actionOnClose = false;
        runtime.actions.error = "";
        runtime.state.refresh();
        panelLoader.item.open();
    }
    function close() { thumbnail.dismiss(); if (panelLoader.item) panelLoader.item.close(); }
    function toggle() { opened ? close() : open(); }
    function pressBarButton() {
        if (opened) {
            // Closing by the bar is deliberate. Dwell resumes only after exit.
            hoverDismissed = true;
            close();
        } else open();
    }
    function closeForPopoutSwitch() {
        restoreFocus.stop();
        actionOnClose = true;
        if (panelLoader.item) panelLoader.item.closeForPopoutSwitch();
    }
    function panelClosed() {
        thumbnail.dismiss();
        cancelAppearance();
        cancelLabels();
        // Layer-shell normally restores focus itself. Only repair a missing
        // focus, never steal it from an application chosen while dismissing.
        if (!actionOnClose && !popoutSwitchClosing && focusBeforePanel) restoreFocus.restart();
        actionOnClose = false;
    }
    function focusWindow(address) { return activateWindow(address, false); }
    function bringWindow(address) { return activateWindow(address, true); }
    function releaseForAction(ready) {
        root.actionOnClose = true;
        root.close();
        var afterHover = function() { thumbnail.afterHidden(ready); };
        if (panelLoader.item) panelLoader.item.afterHidden(afterHover);
        else afterHover();
    }
    function activateWindow(address, bringHere) {
        if (actionBusy) return false;
        if (!opened && hoverOpened)
            focusBeforePanel = snapshot ? Model.address(snapshot.activeAddress) : "";
        reopenOnFailure = opened || hoverOpened;
        return bringHere ? runtime.actions.bring(address, screenName, releaseForAction)
            : runtime.actions.focus(address, releaseForAction);
    }
    function chooseDestination(address, position, keepPreview) {
        if (actionBusy || !panelLoader.item || !inventory.windows.some(function(window) { return window.address === address; })) return false;
        thumbnail.menuRetained = keepPreview === true && thumbnail.visible && thumbnail.address === address;
        if (!panelLoader.item.showMoveMenu(address, position)) { thumbnail.menuRetained = false; return false; }
        if (!thumbnail.menuRetained) thumbnail.dismiss();
        return true;
    }
    function moveWindow(address, destination) { return runtime.actions.move(address, destination); }
    function clearError() { runtime.actions.error = ""; }
    function persistSettings(values) {
        if (!settingsReady) return false;
        var current = Settings.merge(effectiveSettings, {}, moduleName);
        var next = Settings.merge(current, values, moduleName);
        if (JSON.stringify(current) !== JSON.stringify(next))
            next = Settings.stamp(next, runtime.preferences.values);
        if (!runtime.preferences.save(next)) return false;
        publishSettings(next);
        return true;
    }
    onSettingsChanged: {
        if (!settingsReady || runtime.publishingSettings) return;
        var saved = Settings.merge(effectiveSettings, {}, moduleName);
        if (JSON.stringify(settings) === JSON.stringify(saved)) return;
        var incoming = Settings.restore(saved, settings, moduleName);
        if (!persistSettings(incoming)) publishSettings(saved);
    }
    function publishSettings(entry) {
        // The durable file is authoritative; the host keeps a recoverable mirror.
        runtime.publishingSettings = true;
        try {
            try {
                if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
                    bar.shell.updateEntryInline(moduleName, entry);
            } catch (error) { console.warn("WindowPeek: bar settings mirror unavailable"); }
            root.settings = entry;
            var widgets = peers();
            for (var i = 0; i < widgets.length; i++) widgets[i].settings = entry;
        } finally { runtime.publishingSettings = false; }
    }
    function setLanguage(code) {
        if (code !== "auto" && !I18n.languages.some(function(item) { return item.code === code; })) return false;
        return persistSettings({ language: code });
    }
    function recordHintShown() {
        if (hints.mode !== "auto" || hints.remaining <= 0) return false;
        return persistSettings({ hintsUsed: hints.used + 1 });
    }
    function setHintsMode(mode) {
        return ["auto", "on", "off"].indexOf(mode) >= 0 && persistSettings({ hintsMode: mode });
    }
    function toggleHints() { return setHintsMode(hints.enabled ? "off" : "on"); }
    function toggleUpdates() { return updatesAvailable && persistSettings({ autoUpdates: !autoUpdates }); }
    function previewAppearance(values) { runtime.preview(root, Appearance.merge(savedAppearance, values)); }
    function cancelAppearance() { runtime.cancelPreview(root); }
    function saveAppearance(values) {
        if (!persistSettings(Appearance.merge(savedAppearance, values))) return false;
        cancelAppearance(); return true;
    }
    function previewLabels(values) { runtime.previewLabels(root, Labels.normalize(values)); }
    function cancelLabels() { runtime.cancelLabels(root); }
    function saveLabels(values) {
        if (!Labels.valid(values) || !persistSettings(Labels.normalize(values))) return false;
        cancelLabels(); return true;
    }
    function injectPanel() {
        if (!panelLoader.item) return;
        panelLoader.item.bar = bar;
        panelLoader.item.anchorItem = button;
        panelLoader.item.hostWidget = root;
        panelLoader.item.hoverRequested = Qt.binding(function() { return root.tooltipReady && root.canShowTooltip; });
    }
    onBarChanged: { injectPanel(); hydrate.restart(); }
    Component.onCompleted: hydrate.start()
    Component.onDestruction: { cancelAppearance(); cancelLabels(); }

    Timer {
        id: hydrate; interval: 60
        onTriggered: {
            if (!root.bar || root.settingsReady || !root.runtime.preferences.ready) return;
            var inline = Settings.initial(root.bar.layoutConfig, root.moduleName, root.settings);
            var saved = root.runtime.preferences.values;
            var restored = Settings.restore(saved, inline, root.moduleName);
            if (!root.runtime.preferences.hasSavedValues) {
                if (root.runtime.fallbackSettings === null)
                    root.runtime.fallbackSettings = JSON.parse(JSON.stringify(restored));
                restored = root.runtime.fallbackSettings;
            }
            if (JSON.stringify(Settings.merge(saved, {}, root.moduleName)) !== JSON.stringify(restored))
                restored = Settings.stamp(restored, saved);
            var stored = root.runtime.preferences.save(restored);
            root.settings = stored ? restored : Settings.merge(
                root.runtime.preferences.hasSavedValues ? saved : root.runtime.fallbackSettings,
                {}, root.moduleName);
            root.settingsReady = true;
            if (stored) root.publishSettings(restored);
        }
    }
    Timer {
        id: restoreFocus; interval: 100
        onTriggered: {
            if (!root.opened && !root.actionBusy && !Hyprland.activeToplevel)
                root.runtime.actions.focus(root.focusBeforePanel, null);
        }
    }
    Timer {
        interval: 60000; repeat: true; running: root.settingsReady && root.autoUpdates && root.updatesAvailable
        onTriggered: root.runtime.updates.check(root.peers())
    }
    Connections {
        target: root.runtime.preferences
        function onReadyChanged() { hydrate.restart(); }
    }
    Connections {
        target: root.runtime.actions
        function onCompleted(kind, address) {
            root.reopenOnFailure = false;
            if (kind === "move") root.moveCompleted();
        }
        function onFailed(kind, address) {
            if ((kind === "focus" || kind === "bring") && root.reopenOnFailure && panelLoader.item) {
                root.actionOnClose = false;
                panelLoader.item.open();
            }
            root.reopenOnFailure = false;
        }
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    WidgetButton {
        id: button
        objectName: "windowPeekBarButton"
        anchors.fill: parent
        bar: root.bar
        fontSize: root.effectiveBarFont
        readonly property int count: root.inventory.windows.filter(function(w) { return root.includeSpecial || !w.workspace || !w.workspace.special; }).length
        readonly property string countText: root.inventory.status === "ready" ? String(count) : "?"
        text: Labels.render(root.textTemplates.barText, {count: countText, monitor: root.screenName || "?"})
        tooltipText: ""
        activeColor: root.accent
        active: root.opened
        fixedHeight: root.vertical ? Math.max(Style.space(44), metrics.height * 2 + Style.space(12)) : root.barSize
        Accessible.name: "WindowPeek · " + root.words.searchWindows
        onTooltipHoveredChanged: if (!tooltipHovered) root.hoverDismissed = false
        onPressed: function(code) { if (code === Qt.LeftButton || code === Qt.RightButton || code === Qt.MiddleButton) root.pressBarButton(); }
    }
    Timer { id: tooltipDelay; interval: root.panelHoverDelay; onTriggered: root.tooltipReady = root.canShowTooltip }
    WindowThumbnail {
        id: thumbnail; objectName: "windowThumbnail"; hostWidget: root
        shortcutTarget: panelLoader.item ? panelLoader.item.body.previewKeyTarget : null
    }
    Rectangle {
        height: Style.space(2); width: Math.min(button.labelWidth, parent.width)
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.bar && root.bar.position === "bottom" ? 2 : parent.height - height - 2
        color: root.accent; visible: root.opened
    }
    Loader {
        id: panelLoader; active: true; visible: false
        source: Qt.resolvedUrl("Panel.qml")
        onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel); }
    }
    IpcHandler {
        target: "sarr.windowpeek"
        enabled: !!root.snapshot && root.snapshot.monitors.length > 0 && root.screenName === root.snapshot.monitors[0].name
        function toggle(screen: string): void { root.onScreen(screen).toggle(); }
        function open(screen: string): void { root.onScreen(screen).open(); }
        function close(): void { root.broadcast("close"); }
        function focusWindow(address: string): bool {
            var widget = root.peers().find(function(w) { return w.opened; }) || root.onScreen("");
            return widget.focusWindow(address);
        }
        function moveWindow(address: string, destination: string): bool { return root.moveWindow(address, destination); }
        function setLanguage(code: string): bool { return root.setLanguage(code); }
        function showSettings(screen: string): void {
            var widget = root.onScreen(screen); widget.open();
            if (widget === root && panelLoader.item) panelLoader.item.showSettings();
            else if (widget.openSettings) widget.openSettings();
        }
        function status(): string {
            return JSON.stringify(root.peers().map(function(w) {
                return { screen: w.screenName, version: "0.1.0", ready: w.inventory.status === "ready",
                    count: w.inventory.windows.length, opened: w.opened, language: w.language,
                    settingsReady: w.settingsReady, saveFailed: w.saveFailed, includeSpecial: w.includeSpecial, scrollBounce: w.scrollBounce,
                    panelHoverDelay: w.panelHoverDelay, previewHoverDelay: w.previewHoverDelay, popupAnimations: w.popupAnimations,
                    openOnHover: w.openOnHover,
                    actionBusy: w.actionBusy, actionError: w.actionError, hints: w.hints,
                    autoUpdates: w.autoUpdates, updatesAvailable: w.updatesAvailable,
                    preview: {
                        enabled: w.windowPreviews,
                        supported: !!w.windowPreview.modifierState,
                        watching: !!w.windowPreview.modifierState && w.windowPreview.modifierState.active,
                        shiftKnown: !!w.windowPreview.modifierState && w.windowPreview.modifierState.known,
                        shiftDown: !!w.windowPreview.modifierState && w.windowPreview.modifierState.shiftDown,
                        pointerOnCard: !!w.windowPreview.pointerOnCard,
                        visible: w.windowPreview.visible,
                        mapped: w.windowPreview.backingWindowVisible
                    } };
            }));
        }
    }
    function openSettings() { if (panelLoader.item) panelLoader.item.showSettings(); }
}
