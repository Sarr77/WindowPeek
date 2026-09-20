import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Wayland
import qs.Ui as Ui
import qs.Commons
import "vendor/omarchy" as Native

// One list surface from passive hover through keyboard search; a transient move menu.
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
    property bool hintLatched: false
    property bool promoted: false
    property bool collapsing: false
    property bool expandedGeometry: false
    readonly property bool hoverOpened: hoverRetained && !opened && !opening
    readonly property bool mapped: panel.backingWindowVisible || menuSurface.backingWindowVisible || menuPopup.backingWindowVisible
    property bool menuNeedsPopup: false
    readonly property var surface: panel
    readonly property var body: content
    readonly property var destinationMenu: moveMenu
    readonly property real uiScale: hostWidget ? hostWidget.uiScale : 1
    readonly property bool hoverEnabled: !!hostWidget && hostWidget.openOnHover
    onHoverEnabledChanged: if (!hoverEnabled && hoverRetained) dismissHover()
    readonly property bool animationsEnabled: !hostWidget || hostWidget.popupAnimations
    readonly property bool childPreviewVisible: !!hostWidget && !!hostWidget.windowPreview
        && hostWidget.windowPreview.visible && hostWidget.windowPreview.anchorWindow === panel
    readonly property bool available: !!hostWidget && (!bar || !bar.activePopout || bar.activePopout === root)
    readonly property bool canHideHover: !hoverRequested && !pointer.hovered && !panel.barBridgeHovered
        && !content.interacting && !childPreviewVisible && !moveMenu.visible
    readonly property real expansion: expansionMotion.value
    Native.PopupMotion {
        id: expansionMotion
        targetValue: root.expandedGeometry ? 1 : 0
        animated: root.animationsEnabled && root.promoted && panel.backingWindowVisible
        duration: 200
    }
    onHoverRequestedChanged: {
        if (hoverRequested && available && !opened && !opening) showHover();
        else if (canHideHover) hideDelay.restart();
    }
    onCanHideHoverChanged: { if (canHideHover) hideDelay.restart(); else hideDelay.stop(); }
    onAvailableChanged: if (!available && hoverRetained) dismissHover()

    function showHover() {
        if (!hoverEnabled || !available || opened || opening) return;
        hideDelay.stop();
        if (!hoverRetained) {
            promoted = false;
            expandedGeometry = false;
            panel.pinOrigin = false;
            content.begin(false);
            hintLatched = !!hostWidget && hostWidget.hints.enabled;
            // Persist outside the binding that may have triggered an instant hover.
            if (hintLatched) Qt.callLater(function() { if (root.hostWidget) root.hostWidget.recordHintShown(); });
        }
        hoverRetained = true;
    }
    function dismissHover() {
        hideDelay.stop();
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
    function open() {
        moveMenu.close();
        if (opened || opening) return;
        hideDelay.stop();
        if (hoverRetained && panel.backingWindowVisible) {
            panel.retainedOrigin = panel.cardOrigin;
            panel.pinOrigin = true;
            promoted = true;
            expandedGeometry = true;
            controller.show();
            hoverRetained = false;
        } else if (panel.backingWindowVisible) {
            opening = true;
            if (bar) bar.requestPopout(root);
        } else {
            promoted = false;
            panel.pinOrigin = false;
            expandedGeometry = true;
            controller.show();
        }
    }
    function toggleExpanded() {
        if (!hostWidget || !content.backgroundToggleAllowed || opening) return;
        if (opened) collapse();
        else if (hoverOpened) hostWidget.open();
    }
    function collapse() {
        if (!hoverEnabled || !opened || !content.backgroundToggleAllowed) return;
        hideDelay.stop();
        panel.retainedOrigin = panel.cardOrigin;
        panel.pinOrigin = true;
        if (!promoted) {
            hintLatched = hostWidget.hints.enabled;
            // Persist outside the binding that may have triggered an instant hover.
            if (hintLatched) Qt.callLater(function() { if (root.hostWidget) root.hostWidget.recordHintShown(); });
        }
        promoted = true;
        // Retain the mapped card before releasing keyboard and bar ownership.
        hoverRetained = true;
        collapsing = true;
        content.demote();
        expandedGeometry = false;
        controller.hide();
        collapsing = false;
        if (canHideHover) hideDelay.restart();
    }
    function close() {
        var pending = opening;
        opening = false; settingsRequested = false; moveMenu.close();
        // Hold the expanded geometry during fade-out; reset after unmap.
        promoted = false;
        controller.hide();
        dismissHover();
        if (pending && bar && bar.activePopout === root) bar.releasePopout(root);
    }
    function afterHidden(callback) {
        if (!mapped) Qt.callLater(callback);
        else hiddenCallback = callback;
    }
    onMappedChanged: if (!mapped && hiddenCallback) {
        var callback = hiddenCallback; hiddenCallback = null; Qt.callLater(callback);
    }
    Connections {
        target: panel
        function onBackingWindowVisibleChanged() {
            if (panel.backingWindowVisible) return;
            panel.pinOrigin = false;
            root.expandedGeometry = false;
            if (root.opening) Qt.callLater(function() {
                if (!root.opening) return;
                root.opening = false; root.open();
            });
        }
    }
    onOpenedChanged: {
        if (opened) {
            if (promoted) content.promote(); else content.begin();
            if (settingsRequested) { settingsRequested = false; content.showSettings(); }
        } else if (!collapsing) {
            content.dismiss();
            if (hostWidget) hostWidget.panelClosed();
        }
    }
    Timer { id: hideDelay; interval: 160; onTriggered: if (root.canHideHover && root.hoverRetained) root.dismissHover() }
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
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        onBackingWindowVisibleChanged: if (backingWindowVisible)
            Qt.callLater(function() { if (moveMenu.opened) moveMenu.searchField.forceActiveFocus(); });
        PopupWindow {
            id: menuPopup
            // The layer's size starts at zero until Wayland configures it.
            // An XDG positioner with that size disconnects the whole client.
            visible: menuSurface.visible && menuSurface.backingWindowVisible
                && menuSurface.width > 0 && menuSurface.height > 0 && root.menuNeedsPopup
            color: "transparent"; grabFocus: false
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
    Native.WindowPanel {
        id: panel
        objectName: "windowPeekPanel"
        anchorItem: root.anchorItem
        owner: root
        bar: root.bar
        open: root.opened
        hoverOpen: root.hoverRetained
        transientOpen: moveMenu.visible
        keyboardSuppressed: moveMenu.visible
        onTransientCloseRequested: moveMenu.close()
        animationsEnabled: root.animationsEnabled
        onBackgroundClicked: root.toggleExpanded()
        onBackRequested: content.navigateBack()
        focusTarget: content.mode === "windows" ? content.searchField : null
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
                expanded: root.opened
                expansion: root.expansion
                showHint: !!root.hostWidget && (root.hostWidget.hints.enabled
                    || (root.hintLatched && root.hostWidget.hints.mode === "auto"))
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
                Binding { target: content.QQC.Overlay.overlay; property: "transformOrigin"; value: Item.TopLeft; when: content.QQC.Overlay.overlay !== null }
                Binding { target: content.QQC.Overlay.overlay; property: "scale"; value: root.uiScale; when: content.QQC.Overlay.overlay !== null }
            }
        }
    }
}
