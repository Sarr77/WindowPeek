import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Ui
import qs.Commons
import "." as Local
import "I18n.js" as I18n
import "Settings.js" as Settings
import "TextReadability.js" as Readability
import "Shortcuts.js" as Shortcuts
import "Appearance.js" as Appearance
import "WindowModel.js" as Model
import "Labels.js" as Labels

BarWidget {
    id: root
    moduleName: "sarr.windowpeek"
    readonly property string version: runtime.version
    readonly property var runtime: Local.Runtime
    readonly property var inventory: runtime.state.inventory
    readonly property var snapshot: runtime.state.snapshot
    readonly property var effectiveSettings: !settingsReady ? settings
        : (runtime.preferences.hasSavedValues ? runtime.preferences.values : runtime.fallbackSettings)
    readonly property var requestedSettings: runtime.preferences.pendingValues || effectiveSettings
    function preference(name, fallback) {
        var value = effectiveSettings ? effectiveSettings[name] : undefined;
        return value === undefined || value === null ? fallback : value;
    }
    readonly property bool barLabelHovered: button.tooltipHovered
        || (!!panelLoader.item && panelLoader.item.surface.barAnchorHovered)
        || anchorHover.inside
    BarAnchorHover {
        id: anchorHover
        anchor: button
        active: !!panelLoader.item && panelLoader.item.mapped
    }
    onBarLabelHoveredChanged: {
        // Mapping the keyboard layer transfers the same stationary pointer
        // between the bar label and its proxy. Only a settled exit rearms Esc.
        if (barLabelHovered) hoverRearm.stop(); else hoverRearm.restart();
    }
    Timer { id: hoverRearm; interval: 180; onTriggered: if (!root.barLabelHovered) root.hoverDismissed = false }
    readonly property var windowPreview: thumbnail
    readonly property var focusRecovery: runtime.recovery
    readonly property string screenName: root.QsWindow.window && root.QsWindow.window.screen ? root.QsWindow.window.screen.name : ""
    readonly property string languageSetting: String(preference("language", "auto"))
    readonly property string detectedLanguage: I18n.language("auto", Qt.locale().uiLanguages, Qt.locale().name)
    readonly property string language: I18n.language(languageSetting, Qt.locale().uiLanguages, Qt.locale().name)
    readonly property var baseWords: I18n.words(language)
    readonly property var savedLabels: Labels.normalize(effectiveSettings)
    readonly property var labels: runtime.labelsPreviewOwner ? runtime.labelsPreview : savedLabels
    readonly property var shortcuts: Shortcuts.resolve(preference("shortcuts", {}))
    readonly property var words: Labels.apply(Shortcuts.applyWords(baseWords, shortcuts), labels)
    readonly property var textTemplates: Labels.templates(baseWords, labels, preference("barLabel", "full"), vertical)
    readonly property bool includeSpecial: preference("includeSpecial", true) === true
    readonly property bool previewBackdrop: preference("previewBackdrop", true) === true
    readonly property bool previewFit: preference("previewFit", true) === true
    readonly property bool windowPreviews: preference("windowPreviews", true) === true
    readonly property bool openOnHover: preference("openOnHover", true) === true
    readonly property bool doubleClickExpand: preference("doubleClickExpand", false) === true
    // Legacy key retained so the broader pinning option preserves saved choices.
    readonly property bool pinByTitleClick: preference("pinByTitleClick", true) === true
    readonly property string textShadowMode: Readability.mode(preference("textShadowMode", "auto"))
    property TextReadabilityService textReadability: TextReadabilityService { hostWidget: root }
    property var textShadowSamples: []
    property string textShadowSampleKey: ""
    readonly property bool keepSearchFocus: preference("keepSearchFocus", false) === true
    readonly property bool barClickPending: barDoubleClick.running && !barDoubleClick.closePending
    readonly property bool hoverLogo: preference("hoverLogo", true) === true
    readonly property bool settingsLogo: preference("settingsLogo", true) === true
    readonly property bool hoverLogoLoop: preference("hoverLogoLoop", true) === true
    readonly property bool settingsLogoLoop: preference("settingsLogoLoop", true) === true
    readonly property real hoverLogoLoopDelay: Settings.logoLoopDelay(preference("hoverLogoLoopDelay", 4.2))
    readonly property real settingsLogoLoopDelay: Settings.logoLoopDelay(preference("settingsLogoLoopDelay", 4.2))
    readonly property real hoverLogoCooldown: Settings.logoCooldown(preference("hoverLogoCooldown", 0))
    readonly property real settingsLogoCooldown: Settings.logoCooldown(preference("settingsLogoCooldown", 0))
    readonly property bool sharedLogoCooldownEnabled: preference("sharedLogoCooldownEnabled", false) === true
    readonly property real sharedLogoCooldown: Settings.logoCooldown(preference("sharedLogoCooldown", 0))
    readonly property string logoImage: Settings.logoImage(preference("logoImage", ""))
    readonly property string hoverLogoImage: Settings.logoChoice(preference("hoverLogoImage", logoImage))
    readonly property string settingsLogoImage: Settings.logoChoice(preference("settingsLogoImage", logoImage))
    readonly property int panelHoverDelay: Settings.hoverDelay(preference("panelHoverDelay", 400))
    readonly property int previewHoverDelay: Settings.hoverDelay(preference("previewHoverDelay", 400))
    readonly property bool popupAnimations: preference("popupAnimations", true) === true
    readonly property bool scrollBounce: preference("scrollBounce", true) === true
    readonly property int wheelScrollSpeed: Settings.wheelScrollSpeed(preference("wheelScrollSpeed", 102))
    readonly property bool shortcutNumbersRight: preference("shortcutNumbersRight", false) === true
    readonly property string selectedPanelStyle: Settings.panelStyle(preference("panelStyle", "wallpaper"))
    readonly property bool followBarStyle: preference("followBarStyle", false) === true
    readonly property string panelStyle: Settings.effectivePanelStyle(selectedPanelStyle, followBarStyle,
        bar && typeof bar.transparent === "boolean" ? bar.transparent : undefined)
    readonly property bool glassPanels: panelStyle !== "solid"
    readonly property int glassTransparency: Settings.backgroundTransparency(preference("glassTransparency", 8), 8)
    readonly property var wallpaperTransparencyRule: Settings.wallpaperRule(effectiveSettings, themeId)
    readonly property int wallpaperTransparency: wallpaperTransparencyRule.value
    readonly property int wallpaperTransparencyDefault: wallpaperTransparencyRule.defaultValue
    function saveWallpaperTransparency(value) {
        return persistSettings(Settings.setWallpaperTransparency(requestedSettings, themeId, value));
    }
    readonly property real glassOpacity: 1 - glassTransparency / 100
    readonly property bool backgroundBlur: preference("backgroundBlur", false) === true
    readonly property bool backgroundTexture: preference("backgroundTexture", true) === true
    readonly property url wallpaperSource: runtime.wallpaper.source
    readonly property bool wallpaperPending: !runtime.wallpaper.checked
    readonly property bool needsWallpaper: panelStyle === "wallpaper" && (opened || hoverOpened || thumbnail.visible)
    onNeedsWallpaperChanged: runtime.wallpaper.observe(root, needsWallpaper)
    readonly property var hints: Settings.hints(effectiveSettings)
    readonly property bool autoUpdates: !effectiveSettings || effectiveSettings.autoUpdates === undefined || effectiveSettings.autoUpdates === true
    readonly property bool updatesAvailable: runtime.updates.available
    readonly property string updateStatus: runtime.updates.status
    readonly property var savedAppearance: Appearance.normalize(effectiveSettings)
    readonly property var appearance: runtime.previewOwner ? runtime.previewAppearance : savedAppearance
    readonly property string themeId: runtime.themeId
    readonly property color themeAccent: Color.accent
    readonly property color accent: Appearance.resolve(appearance, themeId, String(themeAccent))
    property SurfacePalette surfaces: SurfacePalette {
        appearance: root.appearance; themeId: root.themeId
        panelStyle: root.panelStyle; accent: root.accent
    }
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
    readonly property bool canShowTooltip: openOnHover && !hoverDismissed && barLabelHovered && !opened && (!bar || !bar.activePopout)
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

    function observeWallpaper(owner, enabled) { runtime.wallpaper.observe(owner, enabled); }
    function beginLogoAnimation(slot, source, cooldown) { return runtime.beginLogoAnimation(slot, source, sharedLogoCooldownEnabled ? sharedLogoCooldown : cooldown, sharedLogoCooldownEnabled); }
    function endLogoAnimation(slot, source) { runtime.endLogoAnimation(slot, source); }
    function peers() { return bar ? bar.moduleWidgets(moduleName) : [root]; }
    function onScreen(name) {
        var target = name || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "");
        return peers().find(function(widget) { return widget.screenName === target; }) || root;
    }
    function open(quickSelection, compact) {
        if (!panelLoader.item || (opened && !panelLoader.item.compactPinned) || actionBusy) return;
        if (opened) { panelLoader.item.open(quickSelection, compact); return; }
        restoreFocus.stop();
        focusBeforePanel = snapshot ? Model.address(snapshot.activeAddress) : "";
        actionOnClose = false;
        runtime.actions.error = "";
        runtime.state.refresh();
        panelLoader.item.open(quickSelection, compact);
    }
    function close() { thumbnail.dismiss(); if (panelLoader.item) panelLoader.item.close(); }
    function toggle(quickSelection) { opened ? close() : open(quickSelection); }
    function toggleBarExpansion() {
        barDoubleClick.stop(); barDoubleClick.closePending = false;
        if (panelLoader.item && opened) panelLoader.item.toggleExpanded();
        else open();
    }
    function pressBarButton(code) {
        if (doubleClickExpand && code === Qt.LeftButton) {
            if (barDoubleClick.running) {
                toggleBarExpansion();
            } else {
                barDoubleClick.closePending = opened;
                barDoubleClick.restart();
                if (!opened) open(false, true);
            }
            return;
        }
        if (opened) {
            // Closing by the bar is deliberate. Dwell resumes only after exit.
            hoverDismissed = true;
            close();
        } else open();
    }
    Timer {
        id: barDoubleClick
        interval: Qt.styleHints.mouseDoubleClickInterval
        property bool closePending: false
        onTriggered: if (closePending && root.opened) { root.hoverDismissed = true; root.close(); }
    }
    function closeForPopoutSwitch() {
        restoreFocus.stop();
        actionOnClose = true;
        if (panelLoader.item) panelLoader.item.closeForPopoutSwitch();
    }
    function panelClosed() {
        barDoubleClick.stop();
        barDoubleClick.closePending = false;
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
    function chooseDestination(address, position) {
        if (actionBusy || !panelLoader.item || !inventory.windows.some(function(window) { return window.address === address; })) return false;
        // Retain before mapping the menu so neither its anchor nor capture resets.
        thumbnail.menuRetained = thumbnail.visible;
        if (!panelLoader.item.showMoveMenu(address, position)) { thumbnail.menuRetained = false; return false; }
        if (!thumbnail.menuRetained) thumbnail.dismiss();
        return true;
    }
    function moveWindow(address, destination) { return runtime.actions.move(address, destination); }
    function clearError() { runtime.actions.error = ""; }
    function persistSettings(values, done) {
        if (!settingsReady) { if (done) done(false); return false; }
        var current = Settings.merge(runtime.preferences.pendingValues || effectiveSettings, {}, moduleName);
        var next = Settings.merge(current, values, moduleName);
        if (JSON.stringify(current) !== JSON.stringify(next))
            next = Settings.stamp(next, runtime.preferences.requestedValues);
        return runtime.preferences.save(next, function(ok) {
            if (ok) publishSettings(next);
            if (done) done(ok);
        });
    }
    onSettingsChanged: {
        if (!settingsReady || runtime.publishingSettings) return;
        var saved = Settings.merge(effectiveSettings, {}, moduleName);
        if (JSON.stringify(settings) === JSON.stringify(saved)) return;
        var incoming = Settings.restore(saved, settings, moduleName);
        persistSettings(incoming, function(ok) { if (!ok) publishSettings(saved); });
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
        var requested = Settings.hints(runtime.preferences.pendingValues || effectiveSettings);
        return requested.remaining > 0 && persistSettings({ hintsUsed: requested.used + 1 });
    }
    function setHintsMode(mode) {
        return ["auto", "on", "off"].indexOf(mode) >= 0 && persistSettings({ hintsMode: mode });
    }
    function toggleHints() { return setHintsMode(hints.enabled ? "off" : "on"); }
    function toggleUpdates() { return updatesAvailable && persistSettings({ autoUpdates: !autoUpdates }); }
    function previewAppearance(values) { runtime.preview(root, Appearance.merge(savedAppearance, values)); }
    function cancelAppearance() { runtime.cancelPreview(root); }
    function saveAppearance(values, done) {
        var preview = runtime.previewAppearance;
        return persistSettings(Appearance.merge(savedAppearance, values), function(ok) {
            if (ok && runtime.previewAppearance === preview) cancelAppearance();
            if (done) done(ok);
        });
    }
    function previewLabels(values) { runtime.previewLabels(root, Labels.normalize(values)); }
    function cancelLabels() { runtime.cancelLabels(root); }
    function saveLabels(values, done) {
        if (!Labels.valid(values)) { if (done) done(false); return false; }
        var preview = runtime.labelsPreview;
        return persistSettings(Labels.normalize(values), function(ok) {
            if (ok && runtime.labelsPreview === preview) cancelLabels();
            if (done) done(ok);
        });
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
    Component.onDestruction: { cancelAppearance(); cancelLabels(); runtime.wallpaper.observe(root, false); }

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
            root.settings = Settings.merge(
                root.runtime.preferences.hasSavedValues ? saved : root.runtime.fallbackSettings,
                {}, root.moduleName);
            root.settingsReady = true;
            root.runtime.preferences.save(restored, function(ok) { if (ok) root.publishSettings(restored); });
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
    ReadableBarButton {
        id: button
        hostWidget: root
        objectName: "windowPeekBarButton"
        anchors.fill: parent
        bar: root.bar
        fontSize: root.effectiveBarFont
        readonly property int count: root.inventory.windows.filter(function(w) { return root.includeSpecial || !w.workspace || !w.workspace.special; }).length
        readonly property string countText: root.inventory.status === "ready" ? String(count) : "?"
        text: Labels.render(root.textTemplates.barText, {count: countText, monitor: root.screenName || "?"})
        tooltipText: ""
        activeColor: root.accent
        // Osaka Jade's bright yellow separates the active label from its green
        // bar. Keep a user's custom accent and the ordinary idle label intact.
        activeFallbackColor: root.themeId === "osaka-jade"
            && Appearance.ruleFor(root.appearance, root.themeId).mode !== "custom"
                ? "#E5C736" : foreground
        active: root.opened
        fixedHeight: root.vertical ? Math.max(Style.space(44), metrics.height * 2 + Style.space(12)) : root.barSize
        Accessible.name: "WindowPeek · " + root.words.searchWindows
        onPressed: function(code) { if (code === Qt.LeftButton || code === Qt.RightButton || code === Qt.MiddleButton) root.pressBarButton(code); }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            propagateComposedEvents: true
            // The host's ModuleSlot owns press/drag and forwards single clicks.
            // Consume its composed double-click before it reaches bar chrome.
            onPressed: function(mouse) { mouse.accepted = false; }
            onClicked: function(mouse) { mouse.accepted = false; }
            onDoubleClicked: function(mouse) {
                mouse.accepted = true;
                if (!root.doubleClickExpand) return;
                root.toggleBarExpansion();
            }
        }
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
    OpenShortcut {
        active: ipcControl.enabled
        chord: root.shortcuts.open
        onPressed: root.onScreen("").toggle(true)
    }
    IpcHandler {
        id: ipcControl
        target: "sarr.windowpeek"
        enabled: !!root.snapshot && root.snapshot.monitors.length > 0 && root.screenName === root.snapshot.monitors[0].name
        function toggle(screen: string): void { root.onScreen(screen).toggle(true); }
        function open(screen: string): void { root.onScreen(screen).open(true); }
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
                return { screen: w.screenName, version: w.version, ready: w.inventory.status === "ready",
                    count: w.inventory.windows.length, opened: w.opened, language: w.language,
                    input: w.inputStatus(),
                    settingsReady: w.settingsReady, saveFailed: w.saveFailed, includeSpecial: w.includeSpecial, scrollBounce: w.scrollBounce,
                    panelHoverDelay: w.panelHoverDelay, previewHoverDelay: w.previewHoverDelay, popupAnimations: w.popupAnimations,
                    openOnHover: w.openOnHover, doubleClickExpand: w.doubleClickExpand, pinByTitleClick: w.pinByTitleClick,
                    hoverLogo: w.hoverLogo, settingsLogo: w.settingsLogo,
                    hoverLogoLoop: w.hoverLogoLoop, settingsLogoLoop: w.settingsLogoLoop,
                    hoverLogoLoopDelay: w.hoverLogoLoopDelay, settingsLogoLoopDelay: w.settingsLogoLoopDelay,
                    hoverLogoCooldown: w.hoverLogoCooldown, settingsLogoCooldown: w.settingsLogoCooldown,
                    sharedLogoCooldownEnabled: w.sharedLogoCooldownEnabled, sharedLogoCooldown: w.sharedLogoCooldown,
                    customLogo: w.hoverLogoImage.indexOf("file:") === 0 || w.settingsLogoImage.indexOf("file:") === 0,
                    hoverLogoAnimated: w.hoverLogoImage === "builtin:omarchy-pixel",
                    settingsLogoAnimated: w.settingsLogoImage === "builtin:omarchy-pixel", wheelScrollSpeed: w.wheelScrollSpeed,
                    followBarStyle: w.followBarStyle, keepSearchFocus: w.keepSearchFocus,
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
    function inputStatus() {
        var p = panelLoader.item;
        var anchor = button.mapToGlobal(0, 0);
        return p ? { mode: p.body.mode, compactPinned: p.compactPinned, hover: p.hoverOpened,
            barHovered: barLabelHovered, hoverDismissed: hoverDismissed,
            anchor: {x: anchor.x, y: anchor.y, width: button.width, height: button.height},
            recoveryOffered: !!runtime.recovery.offered, protectionGranted: runtime.recovery.granted,
            protectionActive: runtime.recovery.protecting,
            protectionPaused: p.surface.protectionPaused,
            protectionLastYieldReason: p.surface.protectionLastYieldReason,
            protectionLastYieldAt: p.surface.protectionLastYieldAt,
            recovery: runtime.recovery.diagnosticStatus(),
            keyboard: p.surface.keyboardActive, nativeActive: p.surface.nativeActive, searchFocus: p.body.searchField.focus,
            searchActiveFocus: p.body.searchField.activeFocus, mapped: p.mapped } : null;
    }
}
