import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Wayland
import qs.Ui as Ui
import qs.Commons
import "vendor/omarchy" as Native

// One list surface from compact browsing through keyboard search; a transient move menu.
Ui.Panel {
    id: root
    objectName: "windowPeekController"
    moduleName: "sarr.windowpeek"
    manageIpc: false
    property var anchorItem: null
    property var hostWidget: null
    property var hiddenCallback: null
    property bool opening: false
    property bool settingsRequested: false
    property bool hoverRequested: false
    property bool hoverRetained: false
    property bool promoted: false
    property bool collapsing: false
    property bool expandedGeometry: false
    property bool compactPinned: false
    // Keep the original saved key so an already-disabled switch stays disabled.
    readonly property bool pinningAllowed: !hostWidget || hostWidget.pinByTitleClick !== false
    onPinningAllowedChanged: if (!pinningAllowed && compactPinned) Qt.callLater(function() {
        if (!root.pinningAllowed) root.unpinCompact();
    })
    readonly property bool hoverOpened: hoverRetained && !opened && !opening
    readonly property bool mapped: panel.contentMapped || menuSurface.backingWindowVisible || menuPopup.backingWindowVisible
    property bool menuNeedsPopup: false
    readonly property var surface: panel
    readonly property var body: content
    readonly property var recovery: hostWidget && hostWidget.focusRecovery ? hostWidget.focusRecovery : null
    readonly property var destinationMenu: moveMenu
    readonly property real uiScale: hostWidget ? hostWidget.uiScale : 1
    readonly property bool hoverEnabled: !!hostWidget && hostWidget.openOnHover
    onHoverEnabledChanged: if (!hoverEnabled && hoverRetained) dismissHover()
    readonly property bool animationsEnabled: !hostWidget || hostWidget.popupAnimations
    readonly property bool childPreviewVisible: !!hostWidget && !!hostWidget.windowPreview
        && hostWidget.windowPreview.visible && hostWidget.windowPreview.anchorWindow === panel.contentWindow
    readonly property bool available: !!hostWidget && (!bar || !bar.activePopout || bar.activePopout === root)
    readonly property bool canHideHover: !hoverRequested && !pointer.hovered && !panel.barBridgeHovered && !panel.barAnchorHovered
        && !(hostWidget && hostWidget.barLabelHovered)
        && !panel.hoverHandoffActive
        && !(hostWidget && hostWidget.barClickPending)
        && !content.controlHeld && !content.interacting && !childPreviewVisible && !moveMenu.visible
    readonly property real expansion: expansionMotion.value
    Native.PopupMotion {
        id: expansionMotion
        frameWindow: panel.cardItem.Window.window
        targetValue: root.expandedGeometry ? 1 : 0
        animated: root.animationsEnabled && root.promoted && panel.backingWindowVisible
        // Surface transfer temporarily displays a still frame. Start/resume
        // expansion only once its live destination has rendered that frame.
        paused: panel.transferringSurface || (panel.protectionRequested && !panel.usingNative)
        duration: 200
    }
    onHoverRequestedChanged: {
        if (hoverRequested && available && !opened && !opening) showHover();
        else if (canHideHover) hideDelay.restart();
    }
    onCanHideHoverChanged: { if (canHideHover) hideDelay.restart(); else hideDelay.stop(); }
    onAvailableChanged: if (!available && hoverRetained) dismissHover()

    function showHover(explicitOpen) {
        if ((!hoverEnabled && explicitOpen !== true) || !available || opened || opening) return;
        hideDelay.stop();
        if (!hoverRetained) {
            promoted = false;
            expandedGeometry = false;
            panel.pinOrigin = false;
            content.begin(false);
        }
        hoverRetained = true;
        if (explicitOpen === true && canHideHover) hideDelay.restart();
    }
    function dismissHover() {
        if (!opened && !opening) content.prepareClose();
        hideDelay.stop();
        panel.releaseHoverFootprint();
        moveMenu.close();
        hoverRetained = false;
        if (!opened && !opening) {
            if (hostWidget && hostWidget.windowPreview) hostWidget.windowPreview.dismiss();
            content.dismiss();
        }
    }
    function showSettings() {
        moveMenu.close();
        if (!opened && !opening) open();
        if (opening) settingsRequested = true;
        else content.showSettings();
    }
    function showMoveMenu(address, position) {
        if ((!opened && !hoverOpened) || !mapped || content.mode !== "windows") return false;
        menuNeedsPopup = !!hostWidget.windowPreview && hostWidget.windowPreview.menuRetained
            && !hostWidget.windowPreview.instant;
        moveMenu.show(address, position || Qt.point(panel.cardOrigin.x + panel.padding, panel.cardOrigin.y + panel.padding));
        return true;
    }
    property bool quickSelectionRequested: false
    function open(quickSelection, compact) {
        moveMenu.close();
        if (compact === true && !pinningAllowed && !opened) {
            compactPinned = false;
            showHover(true);
            return;
        }
        panel.releaseHoverFootprint();
        if (opened && compactPinned && !compact) {
            // A pinned panel opened by click has no prior hover promotion.
            // Arm the same resize motion before changing its geometry.
            panel.retainedOrigin = panel.cardOrigin;
            panel.pinOrigin = true;
            promoted = true;
            compactPinned = false; expandedGeometry = true; content.promote();
            return;
        }
        if (opened || opening) return;
        compactPinned = compact === true;
        quickSelectionRequested = !!quickSelection;
        hideDelay.stop();
        if (hoverRetained && panel.backingWindowVisible) {
            panel.retainedOrigin = panel.cardOrigin;
            panel.pinOrigin = true;
            promoted = true;
            expandedGeometry = !compactPinned;
            controller.show();
            hoverRetained = false;
        } else if (panel.backingWindowVisible) {
            opening = true;
            if (bar) bar.requestPopout(root);
        } else {
            promoted = false;
            panel.pinOrigin = false;
            expandedGeometry = !compactPinned;
            controller.show();
        }
    }
    function toggleExpanded() {
        if (!hostWidget || !content.backgroundToggleAllowed || opening) return;
        if (compactPinned) hostWidget.open();
        else if (opened) collapse();
        else if (hoverOpened) hostWidget.open();
    }
    function unpinCompact() {
        if (!opened || !compactPinned) return;
        hideDelay.stop();
        hoverRetained = true;
        collapsing = true;
        content.demote();
        controller.hide();
        compactPinned = false;
        collapsing = false;
        if (canHideHover) hideDelay.restart();
    }
    function collapse() {
        if ((!hoverEnabled && !hostWidget.doubleClickExpand) || !opened || !content.backgroundToggleAllowed) return;
        hideDelay.stop();
        panel.retainedOrigin = panel.cardOrigin;
        panel.pinOrigin = true;
        promoted = true;
        if (hostWidget.doubleClickExpand && pinningAllowed) {
            compactPinned = true;
            expandedGeometry = false;
            content.demote(); content.forceActiveFocus();
            return;
        }
        // Retain the mapped card before releasing keyboard and bar ownership.
        hoverRetained = true;
        if (pointer.hovered) panel.retainHoverFootprint();
        collapsing = true;
        content.demote();
        expandedGeometry = false;
        controller.hide();
        collapsing = false;
        if (canHideHover) hideDelay.restart();
    }
    function close() {
        content.prepareClose();
        panel.prepareClose();
        // Dismissing beneath the bar label must wait for a real pointer exit;
        // handing its input area back to the bar is not a fresh hover gesture.
        if (hostWidget && "hoverDismissed" in hostWidget) hostWidget.hoverDismissed = hostWidget.barLabelHovered === true;
        var pending = opening;
        opening = false; settingsRequested = false; quickSelectionRequested = false; moveMenu.close();
        // Hold the expanded geometry during fade-out; reset after unmap.
        promoted = false;
        controller.hide();
        compactPinned = false;
        dismissHover();
        if (pending && bar && bar.activePopout === root) bar.releasePopout(root);
    }
    function afterHidden(callback) {
        if (!mapped) Qt.callLater(callback);
        else hiddenCallback = callback;
    }
    onMappedChanged: if (!mapped) {
        if (!opened && !opening && !hoverRetained) content.finishDismiss();
        if (hiddenCallback) {
            var callback = hiddenCallback; hiddenCallback = null; Qt.callLater(callback);
        }
    }
    Connections {
        target: panel
        function onBackingWindowVisibleChanged() {
            if (panel.backingWindowVisible) return;
            panel.pinOrigin = false;
            root.expandedGeometry = false;
            if (root.opening) Qt.callLater(function() {
                if (!root.opening) return;
                root.opening = false; root.open(root.quickSelectionRequested, root.compactPinned);
            });
        }
    }
    onOpenedChanged: {
        if (opened) {
            if (recovery) recovery.attach(root);
            if (compactPinned) {
                if (!promoted) content.begin(false);
                content.forceActiveFocus();
            } else if (promoted) content.promote(); else content.begin();
            if (quickSelectionRequested) {
                quickSelectionRequested = false;
                // Let expanded/available bindings settle after controller.show().
                Qt.callLater(function() { if (root.opened) content.startQuickSelection(); });
            }
            if (settingsRequested) { settingsRequested = false; content.showSettings(); }
        } else if (!collapsing) {
            content.dismiss();
            if (hostWidget) hostWidget.panelClosed();
        }
        if (!opened && recovery) recovery.detach(root);
    }
    Timer { id: hideDelay; interval: 160; onTriggered: if (root.canHideHover && root.hoverRetained) root.dismissHover() }
    function hitItem(item, x, y) {
        if (!item || !item.visible || !item.Window.window) return false;
        var local = item.mapFromGlobal(x, y);
        var surface = item.QsWindow.window;
        if (surface && surface.overlayScene) {
            local = item.mapFromItem(item.Window.window.contentItem,
                x - panel.nativeSurfaceOrigin.x, y - panel.nativeSurfaceOrigin.y);
        }
        return local.x >= 0 && local.y >= 0 && local.x < item.width && local.y < item.height;
    }
    OutsideClicks {
        active: root.opened || moveMenu.opened
        onPressed: function(x, y) {
            if (moveMenu.opened) {
                if (root.recovery) root.recovery.suspend();
                if (!root.hitItem(moveMenu.card, x, y)) moveMenu.close();
                return;
            }
            if (panel.hitCard(x, y) || root.hitItem(panel.popupInputItem, x, y)
                || root.hitItem(root.anchorItem, x, y)
                || (root.childPreviewVisible && root.hitItem(root.hostWidget.windowPreview.cardItem, x, y))) return;
            if (root.recovery) root.recovery.suspend();
            root.close();
        }
    }
    // Keep keyboard ownership and outside-click dismissal in a separate layer.
    // Hyprland renders XDG popups after overlay layers, so a menu covering an
    // animated preview must itself be a popup. Plain layer previews need no popup.
    Connections {
        target: root.hostWidget ? root.hostWidget.windowPreview : null
        function onInstantChanged() {
            // Upgrade if another monitor enables animations while choosing.
            // Keep that host until close; reparenting back could put a newly
            // mapped layer preview above the menu.
            if (moveMenu.opened && target.menuRetained && !target.instant) root.menuNeedsPopup = true;
        }
    }
    PanelWindow {
        id: menuSurface
        visible: moveMenu.opened
        screen: panel.screen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"; exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "omarchy-keyboard-panel"
        WlrLayershell.layer: WlrLayer.Overlay
        property bool focusPrimed: false
        property bool pointerReady: false
        mask: Region {
            width: !menuSurface.pointerReady ? menuSurface.width : 0
            height: !menuSurface.pointerReady ? menuSurface.height : 0
            Region { item: root.menuNeedsPopup ? null : moveMenu.card }
        }
        WlrLayershell.keyboardFocus: focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive
        onVisibleChanged: { focusPrimed = false; pointerReady = false; menuPointerReady.stop(); if (visible) menuFocusPrime.restart(); else menuFocusPrime.stop(); }
        Timer { id: menuFocusPrime; interval: 75; onTriggered: { menuSurface.focusPrimed = true; menuPointerReady.restart(); } }
        Timer { id: menuPointerReady; interval: 35; onTriggered: menuSurface.pointerReady = true }
        onBackingWindowVisibleChanged: if (backingWindowVisible)
            Qt.callLater(function() { if (moveMenu.opened) moveMenu.searchField.forceActiveFocus(); });
        PopupWindow {
            id: menuPopup
            // The layer's size starts at zero until Wayland configures it.
            // An XDG positioner with that size disconnects the whole client.
            visible: menuSurface.visible && menuSurface.backingWindowVisible
                && menuSurface.width > 0 && menuSurface.height > 0 && root.menuNeedsPopup
            color: "transparent"; grabFocus: false
            mask: Region { item: moveMenu.card }
            implicitWidth: Math.max(1, menuSurface.width)
            implicitHeight: Math.max(1, menuSurface.height)
            anchor {
                window: menuSurface
                edges: Edges.Top | Edges.Left
                gravity: Edges.Bottom | Edges.Right
                adjustment: PopupAdjustment.None
                rect.width: 1; rect.height: 1
            }
            onBackingWindowVisibleChanged: if (backingWindowVisible)
                Qt.callLater(function() { if (moveMenu.opened) moveMenu.searchField.forceActiveFocus(); });
        }
        MoveMenu {
            id: moveMenu
            parent: root.menuNeedsPopup ? menuPopup.contentItem : menuSurface.contentItem
            hostWidget: root.hostWidget
        }
    }
    // Native stay_focused can keep Qt's pointer target on the parent surface.
    // Check the preview's real screen bounds before handing pointer input to it.
    BarAnchorHover {
        id: previewPointer
        active: root.opened && root.childPreviewVisible && panel.protectionRequested
        anchor: root.hostWidget ? root.hostWidget.windowPreview.cardItem : null
        globalBounds: root.childPreviewVisible ? Qt.rect(root.hostWidget.windowPreview.globalOrigin.x,
            root.hostWidget.windowPreview.globalOrigin.y, root.hostWidget.windowPreview.width, root.hostWidget.windowPreview.height) : null
    }
    Native.WindowPanel {
        protectionRequested: !!root.recovery && root.recovery.requested && root.recovery.panel === root && root.opened
        // Keep the presentation policy through fade-out, after recovery detaches.
        protectionStrict: !!root.hostWidget && root.hostWidget.keepSearchFocus
        protectionHold: !!root.recovery && root.recovery.protecting
        onProtectionFailed: function(reason) { if (root.recovery) root.recovery.stop("backend-unavailable", reason) }
        panelColor: root.hostWidget ? root.hostWidget.surfaces.panel : Color.popups.background
        glassEnabled: !!root.hostWidget && root.hostWidget.panelStyle === "glass"
        glassOpacity: root.hostWidget ? root.hostWidget.glassOpacity : 0.92
        backgroundComponent: root.hostWidget && (root.hostWidget.panelStyle === "wallpaper"
            || (root.hostWidget.glassPanels && root.hostWidget.backgroundTexture)) ? styledBackground : null
        property Component styledBackground: WallpaperBackdrop {
                id: background
                objectName: "panelWallpaper"
                palette: root.hostWidget.surfaces
                source: root.hostWidget.wallpaperSource
                pending: root.hostWidget.wallpaperPending || contrast.pending
                wallpaper: root.hostWidget.panelStyle === "wallpaper"
                blurred: root.hostWidget.backgroundBlur
                textured: root.hostWidget.backgroundTexture
                tintOpacity: 1 - root.hostWidget.wallpaperTransparency / 100
                screenSize: Qt.size(panel.screenW, panel.screenH)
                screenOrigin: Qt.point(panel.cardOrigin.x + 1, panel.cardOrigin.y + 1)
                radius: Math.max(0, panel.cornerRadius - 1)
                TextShadowSampler {
                    hostWidget: root.hostWidget
                    active: root.opened || root.opening || root.hoverRetained
                    screenSize: background.screenSize
                    panelRect: Qt.rect(background.screenOrigin.x, background.screenOrigin.y, background.width, background.height)
                }
                WallpaperContrast {
                    id: contrast
                    hostWidget: root.hostWidget
                    active: background.wallpaper && (root.opened || root.opening || root.hoverRetained)
                    screenSize: background.screenSize
                    panelRect: Qt.rect(background.screenOrigin.x, background.screenOrigin.y, background.width, background.height)
                }
        }
        id: panel
        objectName: "windowPeekPanel"
        anchorItem: root.anchorItem
        owner: root
        bar: root.bar
        open: root.opened
        doubleClickExpand: !!root.hostWidget && root.hostWidget.doubleClickExpand
        hoverOpen: root.hoverRetained
        shortcutKeyboard: content.shortcutsAvailable
        // Browsing compact mode follows the pointer; visible Search retains typing.
        retainSearchFocus: content.expanded
        pointerPreviewVisible: root.childPreviewVisible
        pointerOnPreview: root.childPreviewVisible && (panel.protectionRequested ? previewPointer.inside : root.hostWidget.windowPreview.containsPointer)
        transientOpen: moveMenu.visible
        keyboardSuppressed: moveMenu.visible
        onBarPressed: function(button) { if (root.hostWidget) root.hostWidget.pressBarButton(button) }
        onBarDoubleClicked: if (root.hostWidget && root.hostWidget.doubleClickExpand) root.hostWidget.toggleBarExpansion()
        onTransientCloseRequested: moveMenu.close()
        animationsEnabled: root.animationsEnabled
        onBackgroundClicked: root.toggleExpanded()
        onBackRequested: content.navigateBack()
        previewInputItem: root.childPreviewVisible && root.hostWidget.windowPreview.embedded ? root.hostWidget.windowPreview.contentItem : null
        previewBlurItem: previewInputItem ? root.hostWidget.windowPreview.cardItem : null
        previewBlurRadius: Style.space(7) * root.uiScale
        popupInputItem: content.currentPopup ? (content.currentPopup.popupInputItem || content.currentPopup.background || null) : null
        focusTarget: content.mode === "windows" && (root.opened || root.hoverOpened) ? content.searchField : null
        padding: Style.space(16) * root.uiScale
        contentWidth: fittedContentWidth(Style.space((content.compact ? 360 : 420)
            + (500 - (content.compact ? 360 : 420)) * root.expansion) * root.uiScale)
        contentHeight: fittedContentHeight(Math.ceil(content.implicitHeight * root.uiScale))
        borderSpec: Border.flat(root.hostWidget ? root.hostWidget.accent : Color.accent, 1)
        cornerRadius: Style.space(8) * root.uiScale
        Item {
            id: bounds
            x: -(panel.padding + Border.left(panel.borderSpec))
            y: -(panel.padding + Border.top(panel.borderSpec))
            width: panel.contentWidth
            height: panel.contentHeight
            HoverHandler { id: pointer }
            PanelContent {
                id: content
                objectName: "windowPeekContent"
                hostWidget: root.hostWidget
                recovery: root.recovery
                protectionPaused: panel.protectionPaused
                expanded: content.closingExpanded !== null ? content.closingExpanded : root.opened && !root.compactPinned
                compactPinned: root.compactPinned
                barLabelHovered: !!root.hostWidget && root.hostWidget.barLabelHovered === true
                expansion: root.expansion
                outerBackgroundHovered: panel.backgroundHovered
                pointerInsidePanel: pointer.hovered
                previewBoundsItem: bounds
                scrollbarGutter: (panel.padding + Border.right(panel.borderSpec)) / root.uiScale
                maximumHeight: panel.availableCardHeight > 0
                    ? Math.max(0, panel.availableCardHeight - panel.verticalContentInset) / root.uiScale : Infinity
                x: -bounds.x; y: -bounds.y
                width: bounds.parent.width / root.uiScale
                height: bounds.parent.height / root.uiScale
                scale: root.uiScale; transformOrigin: Item.TopLeft
                onCloseRequested: root.close()
                onBackgroundClicked: root.toggleExpanded()
                onExpandRequested: if (root.hostWidget && typeof root.hostWidget.open === "function") root.hostWidget.open()
                Binding { target: content.QQC.Overlay.overlay; property: "transformOrigin"; value: Item.TopLeft; when: content.QQC.Overlay.overlay !== null }
                Binding { target: content.QQC.Overlay.overlay; property: "scale"; value: root.uiScale; when: content.QQC.Overlay.overlay !== null }
            }
        }
    }
}
