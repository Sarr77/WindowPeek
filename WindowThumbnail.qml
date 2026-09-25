import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "PopupPlacement.js" as Placement
import "PreviewGeometry.js" as Geometry
import "Shortcuts.js" as Shortcuts

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
    // Share the panel layer so animated placement is one scene update, not a
    // separate Wayland popup configure/swap on every animation frame.
    readonly property var panelWindow: anchorWindow && anchorWindow.overlayWindow ? anchorWindow.overlayWindow : anchorWindow
    readonly property bool embedded: !!panelWindow && !!panelWindow.panelScene
    readonly property point overlayOffset: anchorWindow && anchorWindow.overlayOffset ? anchorWindow.overlayOffset : Qt.point(0, 0)
    // WindowPanel aliases contentItem to a list. Window.window exposes the
    // actual scene root, independently of that component's public aliases.
    readonly property Item anchorScene: anchorItem && anchorItem.Window.window ? anchorItem.Window.window.contentItem : null
    readonly property var entry: hostWidget && hostWidget.inventory
        ? hostWidget.inventory.windows.find(function(window) { return window.address === root.address; }) || null : null
    readonly property var words: hostWidget.words
    readonly property real uiScale: hostWidget.uiScale
    readonly property int hoverDelay: hostWidget.previewHoverDelay
    readonly property bool instant: !hostWidget.popupAnimations
    readonly property bool glass: hostWidget.panelStyle === "glass"
    readonly property bool wallpaper: hostWidget.panelStyle === "wallpaper"
    readonly property point screenOrigin: {
        if (!anchorWindow || !anchorWindow.screen) return Qt.point(0, 0);
        var screen = anchorWindow.screen;
        var bounds = Qt.rect(screen.x + overlayOffset.x + boundsRect.x, screen.y + overlayOffset.y + boundsRect.y, boundsRect.width, boundsRect.height);
        var origin = Placement.beside(bounds, rowRect.y - boundsRect.y, rowRect.height, width, height, screen);
        return Qt.point(origin.x, origin.y);
    }
    readonly property point globalOrigin: Qt.point(
        (anchorWindow && anchorWindow.screen ? anchorWindow.screen.x : 0) + screenOrigin.x,
        (anchorWindow && anchorWindow.screen ? anchorWindow.screen.y : 0) + screenOrigin.y)
    readonly property alias cardItem: card
    readonly property bool visible: ready && available && previewAllowed
    readonly property bool backingWindowVisible: (embedded && root.visible && panelWindow.backingWindowVisible) || popup.backingWindowVisible || (!!instantLoader.item && instantLoader.item.backingWindowVisible)
    readonly property alias contentItem: scene
    readonly property real bridgeWidth: Style.space(8) * uiScale
    readonly property bool available: hostWidget.windowPreviews && (!hostWidget.moveMenuOpen || menuRetained) && !!entry && !!anchorItem && anchorItem.visible
        && !!anchorWindow && anchorWindow.visible && !hostWidget.actionBusy
    readonly property bool hasContent: captureLoader.item ? captureLoader.item.hasContent : false
    readonly property size sourceSize: hasContent ? captureLoader.item.sourceSize : Qt.size(0,0)
    readonly property real maximumCardWidth: Math.min(Style.space(320), anchorWindow && anchorWindow.screen
        ? (anchorWindow.screen.width - Style.space(20) - bridgeWidth*2)/uiScale : Style.space(320))
    readonly property real maximumImageHeight: Math.max(Style.space(40), Math.min(Style.space(300),
        anchorWindow && anchorWindow.screen ? anchorWindow.screen.height/uiScale - Style.space(120) : Style.space(300)))
    property size sessionSourceSize: Qt.size(0,0)
    function rememberSourceSize() {
        if (visible && hasContent && sessionSourceSize.width <= 0 && sourceSize.width > 0 && sourceSize.height > 0)
            sessionSourceSize = sourceSize;
    }
    onSourceSizeChanged: Qt.callLater(rememberSourceSize)
    onHasContentChanged: Qt.callLater(rememberSourceSize)
    onReadyChanged: if (ready) { sessionSourceSize = Qt.size(0,0); Qt.callLater(rememberSourceSize); }
    readonly property var imageSize: Geometry.fit(sessionSourceSize.width, sessionSourceSize.height,
        maximumCardWidth-Style.space(30),maximumImageHeight,Style.space(164),hostWidget.previewFit)

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
    PreviewModifiers {
        id: modifiers; active: root.available
        modifier: Shortcuts.normalize(root.hostWidget.shortcuts).privacy
    }
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
        var bounds = Qt.rect(screen.x + overlayOffset.x + boundsRect.x, screen.y + overlayOffset.y + boundsRect.y, boundsRect.width, boundsRect.height);
        var origin = Placement.beside(bounds, rowRect.y - boundsRect.y, rowRect.height, width, height, screen);
        var local = pointer.mapToItem(scene, position.x, position.y);
        return Qt.point(origin.x + local.x, origin.y + local.y);
    }
    function activate(value, modifiers, position) {
        if (!available || value !== address) return;
        var accepted;
        var action = Shortcuts.mouseAction(hostWidget.shortcuts, modifiers);
        var choose = action === "move";
        if (action !== "focus")
            accepted = action === "bring" ? hostWidget.bringWindow(value) : hostWidget.chooseDestination(value, position);
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
        visible: root.visible && !root.instant && !root.embedded
        implicitWidth: root.width; implicitHeight: root.height
        grabFocus: false; color: "transparent"
        BackgroundEffect.blurRegion: root.glass && visible ? blurRegion : null
        Region { id: blurRegion; item: card; radius: card.radius * root.uiScale }
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
        source: !root.embedded && root.instant && root.available ? Qt.resolvedUrl("InstantPreviewSurface.qml") : ""
        // LazyLoader must receive its component before activation.
        active: source !== ""
    }
    Binding { target: instantLoader.item; property: "preview"; value: root; when: !!instantLoader.item }
    Item {
        id: scene
        // This scene follows its owning panel layer, with a popup fallback for
        // standalone hosts that do not expose a layer scene.
        // Its visual ancestors do not include the owning Scope.
        readonly property var hostWidget: root.hostWidget
        // An XDG preview may receive keys belonging to its parent layer even
        // without a keyboard grab. Keep list shortcuts on the original list.
        focus: true
        Keys.forwardTo: root.shortcutTarget ? [root.shortcutTarget] : []
        parent: root.embedded ? root.panelWindow.panelScene : root.instant && instantLoader.item ? instantLoader.item.contentItem : popup.contentItem
        visible: root.visible
        x: root.embedded ? root.screenOrigin.x : 0
        y: root.embedded ? root.screenOrigin.y : 0
        z: 10000
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
            width: root.imageSize.width + Style.space(30)
            height: implicitHeight
            implicitHeight: layout.implicitHeight + Style.space(12) * 2
            scale: root.uiScale; transformOrigin: Item.TopLeft
            color: root.glass ? Qt.alpha(root.hostWidget.surfaces.panel, root.hostWidget.glassOpacity) : root.hostWidget.surfaces.panel
            radius: Style.space(7)
            border.width: 1; border.color: Qt.alpha(root.hostWidget.accent, 0.65)
            Loader {
                anchors.fill: parent; anchors.margins: 1
                active: root.visible && (root.wallpaper || (root.glass && root.hostWidget.backgroundTexture))
                sourceComponent: WallpaperBackdrop {
                    objectName: "previewWallpaper"
                    palette: root.hostWidget.surfaces
                    source: root.hostWidget.wallpaperSource
                    wallpaper: root.wallpaper
                    blurred: root.hostWidget.backgroundBlur
                    textured: root.hostWidget.backgroundTexture
                    tintOpacity: 1 - root.hostWidget.wallpaperTransparency / 100
                    radius: card.radius - 1
                    displayScale: root.uiScale
                    screenSize: root.anchorWindow && root.anchorWindow.screen
                        ? Qt.size(root.anchorWindow.screen.width, root.anchorWindow.screen.height) : Qt.size(0, 0)
                    screenOrigin: Qt.point(root.screenOrigin.x + card.x + root.uiScale, root.screenOrigin.y + root.uiScale)
                }
            }
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
                    // Reserve two title lines so live title changes cannot move the frame.
                    width: parent.width
                    height: Math.max(Style.space(34), appCaption.implicitHeight + titleMetrics.lineSpacing*2 + heading.spacing)
                    FontMetrics { id: titleMetrics; font: previewTitle.font }
                    WindowIcon {
                        id: icon
                        visible: card.width >= Style.space(140)
                        width: Style.space(26); height: width
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        appId: root.entry ? root.entry.appId || root.entry.app : ""
                        imageScale: root.uiScale
                    }
                    Column {
                        id: heading
                        anchors.left: icon.visible ? icon.right : parent.left; anchors.leftMargin: icon.visible ? Style.space(9) : 0
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(2)
                        ReadableText {
                            id: appCaption; objectName: "windowThumbnailApp"
                            width: parent.width; text: root.entry ? root.entry.app : ""
                            textFormat: Text.PlainText; elide: Text.ElideRight
                            textColor: root.hostWidget.accent; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
                        }
                        ReadableText {
                            id: previewTitle; objectName: "windowThumbnailTitle"
                            width: parent.width; text: root.entry ? root.entry.title || root.words.unnamed : ""
                            textFormat: Text.PlainText; elide: Text.ElideRight
                            wrapMode: Text.Wrap; maximumLineCount: 2
                            textColor: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body
                        }
                    }
                }
                Rectangle {
                    id: display; objectName: "windowThumbnailDisplay"
                    readonly property color readabilityBackground: color
                    width: parent.width; height: root.imageSize.height + Style.space(6)
                    color: root.hostWidget.previewBackdrop ? Qt.darker(Color.popups.background, 1.25) : "transparent"
                    radius: Style.space(3)
                    border.width: root.hostWidget.previewBackdrop ? 1 : 0; border.color: Qt.alpha(Color.popups.text, 0.14)
                    Loader {
                        id: captureLoader; objectName: "windowThumbnailCapture"
                        anchors.fill: parent; anchors.margins: Style.space(3)
                        active: root.visible && root.backingWindowVisible
                        sourceComponent: WindowCapture { address: root.address; active: true }
                    }
                    ReadableText {
                        objectName: "windowThumbnailPlaceholder"
                        anchors.centerIn: parent; width: parent.width - Style.space(24)
                        visible: !root.hasContent
                        text: loading.running ? root.words.previewLoading : root.words.previewUnavailable
                        textFormat: Text.PlainText; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
                        textColor: Qt.alpha(Color.popups.text, 0.6); font.family: Style.font.family; font.pixelSize: Style.font.caption
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
