import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons
import "PopupPlacement.js" as Placement

// One preview shared by both lists, with pointer handoff to the card.
Scope {
    id: root
    required property var hostWidget
    property Item shortcutTarget: null
    property Item anchorItem: null
    property Item boundsItem: null
    property bool rowHovered: false
    property string address: ""
    property bool ready: false
    property bool menuRetained: false
    property var hiddenCallback: null
    readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
    // WindowPanel aliases contentItem to a list. Window.window exposes the
    // actual scene root, independently of that component's public aliases.
    readonly property Item anchorScene: anchorItem && anchorItem.Window.window ? anchorItem.Window.window.contentItem : null
    readonly property var entry: hostWidget && hostWidget.inventory
        ? hostWidget.inventory.windows.find(function(window) { return window.address === root.address; }) || null : null
    readonly property var words: hostWidget.words
    readonly property real uiScale: hostWidget.uiScale
    readonly property int hoverDelay: hostWidget.previewHoverDelay
    readonly property bool instant: !hostWidget.popupAnimations
    readonly property bool visible: ready && available && previewAllowed
    readonly property bool backingWindowVisible: popup.backingWindowVisible || (!!instantLoader.item && instantLoader.item.backingWindowVisible)
    readonly property alias contentItem: scene
    readonly property real bridgeWidth: Style.space(8) * uiScale
    readonly property bool available: hostWidget.windowPreviews && (!hostWidget.moveMenuOpen || menuRetained) && !!entry && !!anchorItem && anchorItem.visible
        && !!anchorWindow && anchorWindow.visible && !hostWidget.actionBusy
    readonly property bool hasContent: captureLoader.item ? captureLoader.item.hasContent : false
    readonly property rect rowRect: {
        watcher.transform;
        return anchorItem && anchorScene ? anchorItem.mapToItem(anchorScene, 0, 0, anchorItem.width, anchorItem.height) : Qt.rect(0, 0, 0, 0);
    }
    readonly property rect boundsRect: {
        boundsWatcher.transform;
        return boundsItem && anchorScene ? boundsItem.mapToItem(anchorScene, 0, 0, boundsItem.width, boundsItem.height) : rowRect;
    }
    readonly property bool containsPointer: pointer.containsMouse || pointer.pressed || surfacePointer.hovered
    readonly property bool pointerOnCard: pointer.containsMouse || pointer.pressed
    readonly property var modifierState: modifiers
    readonly property bool previewAllowed: modifiers.known
        && (!modifiers.shiftDown || pointerOnCard || menuRetained)
    readonly property bool held: menuRetained || rowHovered || (!!listPointer && listPointer.hovered) || containsPointer
    Connections {
        target: root.hostWidget
        function onMoveMenuOpenChanged() { if (!root.hostWidget.moveMenuOpen) root.menuRetained = false; }
    }
    PreviewModifiers { id: modifiers; active: root.available }
    function schedulePreview() {
        if (!available || !previewAllowed) {
            dwell.stop(); ready = false;
            return;
        }
        if (rowHovered && !ready) {
            if (hoverDelay === 0) ready = true;
            else if (!dwell.running) dwell.start();
        }
    }
    function showFor(item, value, bounds) {
        if (hostWidget.moveMenuOpen) return;
        hideDelay.stop(); rowHovered = true;
        if (anchorItem === item && address === value) { schedulePreview(); return; }
        dwell.stop();
        ready = false;
        anchorItem = item; boundsItem = bounds || item; address = value;
        schedulePreview();
    }
    function hideFor(item) {
        if (anchorItem !== item) return;
        rowHovered = false;
        if (!ready) dismiss();
        else if (!held) hideDelay.restart();
    }
    function dismiss() {
        menuRetained = false;
        dwell.stop(); hideDelay.stop(); ready = false; rowHovered = false;
        address = ""; anchorItem = null; boundsItem = null;
    }
    function menuPosition(position) {
        var screen = anchorWindow.screen;
        var bounds = Qt.rect(screen.x + boundsRect.x, screen.y + boundsRect.y, boundsRect.width, boundsRect.height);
        var origin = Placement.beside(bounds, rowRect.y - boundsRect.y, rowRect.height, width, height, screen);
        var local = pointer.mapToItem(scene, position.x, position.y);
        return Qt.point(origin.x + local.x, origin.y + local.y);
    }
    function activate(value, modifiers, position) {
        if (!available || value !== address) return;
        var accepted;
        var choose = (modifiers & Qt.ControlModifier) && !(modifiers & Qt.ShiftModifier);
        if (modifiers & Qt.ControlModifier)
            accepted = modifiers & Qt.ShiftModifier ? hostWidget.bringWindow(value) : hostWidget.chooseDestination(value, position, true);
        else accepted = hostWidget.focusWindow(value);
        if (accepted && !choose) dismiss();
    }
    function afterHidden(callback) {
        if (!backingWindowVisible) Qt.callLater(callback);
        else hiddenCallback = callback;
    }
    onHeldChanged: {
        if (held) hideDelay.stop();
        else if (ready) hideDelay.restart();
    }
    onAvailableChanged: schedulePreview()
    onHoverDelayChanged: { dwell.stop(); schedulePreview(); }
    onPreviewAllowedChanged: {
        schedulePreview();
        if (!previewAllowed && !rowHovered) Qt.callLater(function() {
            if (!root.previewAllowed && !root.rowHovered) root.dismiss();
        });
    }
    Timer { id: dwell; interval: root.hoverDelay; onTriggered: root.ready = root.available && root.previewAllowed && root.rowHovered }
    Timer { id: hideDelay; interval: 300; onTriggered: if (!root.held) root.dismiss() }
    TransformWatcher { id: watcher; a: root.anchorItem; b: root.anchorScene }
    TransformWatcher { id: boundsWatcher; a: root.boundsItem; b: root.anchorScene }

    // Transparent side strips belong to this native surface, so even a stopped
    // pointer in the gap keeps the preview alive. Symmetry also covers FlipX.
    readonly property int width: Math.ceil(card.width * uiScale + bridgeWidth * 2)
    readonly property int height: Math.ceil(card.implicitHeight * uiScale)
    onBackingWindowVisibleChanged: {
        if (!backingWindowVisible && hiddenCallback) {
            var callback = hiddenCallback; hiddenCallback = null; Qt.callLater(callback);
        }
    }
    PopupWindow {
        id: popup
        visible: root.visible && !root.instant
        implicitWidth: root.width; implicitHeight: root.height
        grabFocus: false; color: "transparent"
        anchor {
            window: root.anchorWindow
            edges: Edges.Right | Edges.Top
            gravity: Edges.Right | Edges.Bottom
            adjustment: PopupAdjustment.FlipX | PopupAdjustment.SlideY | PopupAdjustment.SlideX
            rect.x: Math.round(root.boundsRect.x)
            rect.y: Math.round(Math.max(root.boundsRect.y,
                root.rowRect.y + root.rowRect.height / 2 - root.height / 2))
            rect.width: Math.round(root.boundsRect.width)
            rect.height: 1
        }
    }
    // XDG popup fades belong to the compositor. An unanimated layer gives this
    // preview an instant path without changing global Hyprland animation rules.
    LazyLoader {
        id: instantLoader
        source: root.instant && root.available ? Qt.resolvedUrl("InstantPreviewSurface.qml") : ""
        // LazyLoader must receive its component before activation.
        active: source !== ""
    }
    Binding { target: instantLoader.item; property: "preview"; value: root; when: !!instantLoader.item }
    Item {
        id: scene
        // An XDG preview may receive keys belonging to its parent layer even
        // without a keyboard grab. Keep list shortcuts on the original list.
        focus: true
        Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
        parent: root.instant && instantLoader.item ? instantLoader.item.contentItem : popup.contentItem
        width: root.width; height: root.height
        HoverHandler { id: listPointer; parent: root.boundsItem || card; enabled: root.visible }
        Item {
            objectName: "windowThumbnailHandoff"
            anchors.fill: parent
            HoverHandler { id: surfacePointer; blocking: false }
        }
        Rectangle {
            id: card; objectName: "windowThumbnailCard"
            x: root.bridgeWidth
            width: Math.min(Style.space(320), root.anchorWindow && root.anchorWindow.screen
                ? (root.anchorWindow.screen.width - Style.space(20)) / root.uiScale : Style.space(320))
            height: implicitHeight
            implicitHeight: layout.implicitHeight + Style.space(12) * 2
            scale: root.uiScale; transformOrigin: Item.TopLeft
            color: Color.popups.background; radius: Style.space(7)
            border.width: 1; border.color: Qt.alpha(root.hostWidget.accent, 0.65)
            Accessible.role: Accessible.Button
            Accessible.name: root.entry ? root.entry.app + " · " + root.entry.title : ""
            Accessible.onPressAction: root.activate(root.address, Qt.NoModifier)
            Column {
                id: layout
                x: Style.space(12); y: x; width: parent.width - x * 2
                spacing: Style.space(10)
                LayoutMirroring.enabled: root.hostWidget.language === "ar"
                LayoutMirroring.childrenInherit: true
                Item {
                    width: parent.width; height: Math.max(Style.space(34), heading.implicitHeight)
                    WindowIcon {
                        id: icon
                        width: Style.space(26); height: width
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        appId: root.entry ? root.entry.appId || root.entry.app : ""
                        imageScale: root.uiScale
                    }
                    Column {
                        id: heading
                        anchors.left: icon.right; anchors.leftMargin: Style.space(9)
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(2)
                        Text {
                            width: parent.width; text: root.entry ? root.entry.app : ""
                            textFormat: Text.PlainText; elide: Text.ElideRight
                            color: root.hostWidget.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption
                        }
                        Text {
                            objectName: "windowThumbnailTitle"
                            width: parent.width; text: root.entry ? root.entry.title || root.words.unnamed : ""
                            textFormat: Text.PlainText; elide: Text.ElideRight
                            wrapMode: Text.Wrap; maximumLineCount: 2
                            color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body
                        }
                    }
                }
                Rectangle {
                    id: display
                    width: parent.width; height: Style.space(170)
                    color: Qt.darker(Color.popups.background, 1.25); radius: Style.space(3)
                    border.width: 1; border.color: Qt.alpha(Color.popups.text, 0.14)
                    Loader {
                        id: captureLoader; objectName: "windowThumbnailCapture"
                        anchors.fill: parent; anchors.margins: Style.space(3)
                        active: root.visible && root.backingWindowVisible
                        sourceComponent: WindowCapture { address: root.address; active: true }
                    }
                    Text {
                        anchors.centerIn: parent; width: parent.width - Style.space(24)
                        visible: !root.hasContent
                        text: loading.running ? root.words.previewLoading : root.words.previewUnavailable
                        textFormat: Text.PlainText; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
                        color: Qt.alpha(Color.popups.text, 0.6); font.family: Style.font.family; font.pixelSize: Style.font.caption
                    }
                    Timer { id: loading; interval: 1200; running: root.visible && !root.hasContent }
                }
            }
            WindowClickArea {
                id: pointer; objectName: "windowThumbnailPointer"
                anchors.fill: parent; hoverEnabled: true; enabled: !root.hostWidget.actionBusy
                cursorShape: Qt.PointingHandCursor
                address: root.address
                onActivated: function(address, modifiers, position) { root.activate(address, modifiers, root.menuPosition(position)); }
            }
        }
    }
}
