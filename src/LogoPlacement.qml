import QtQuick
import qs.Commons
import "LogoCatalog.js" as Catalog
import "LogoWords.js" as Copy

// Geometry stays inside a fixed decoration viewport. Dragging never resizes the
// panel or saves once per mouse event; commit once on release/wheel settle.
Item {
    id: root
    required property var hostWidget
    required property Item artwork
    property string target: "settings"
    property bool editing: false
    property real naturalAspect: 1215 / 285
    property real baselineWidth: Math.min(width * 0.72, Style.space(324))
    property real bottomMargin: Style.space(48)
    property real edgeMargin: Style.space(8)
    readonly property var copy: Copy.words(hostWidget.language)
    readonly property var saved: Catalog.layout(hostWidget.effectiveSettings[target + "LogoLayout"])
    property var draft: null
    property int revision: 0
    readonly property var value: draft || saved
    readonly property real baseHeight: baselineWidth / Math.max(0.05, naturalAspect)
    readonly property real baseFit: Math.min(1, Math.max(1,width - edgeMargin * 2) / Math.max(1,baselineWidth), Math.max(1,height - edgeMargin * 2) / Math.max(1,baseHeight))
    readonly property real defaultWidth: baselineWidth * baseFit
    readonly property real defaultHeight: baseHeight * baseFit
    readonly property real defaultCenterY: Math.max(edgeMargin, Math.min(height - defaultHeight - edgeMargin,
        height - defaultHeight - bottomMargin)) + defaultHeight / 2
    readonly property real rawWidth: baselineWidth * value.zoom * value.width / 10000
    readonly property real rawHeight: baseHeight * value.zoom * value.height / 10000
    // Fit the chosen size once, independently of position. Translation uses the
    // displayed bounds, never the unscaled default image's footprint.
    readonly property real fit: Math.min(1, Math.max(1,width - edgeMargin * 2) / Math.max(1,rawWidth),
        Math.max(1,height - edgeMargin * 2) / Math.max(1,rawHeight))
    readonly property real placedWidth: rawWidth * fit
    readonly property real placedHeight: rawHeight * fit
    readonly property real centerX: Math.max(edgeMargin + placedWidth / 2, Math.min(width - edgeMargin - placedWidth / 2, width / 2 + value.x * width / 100))
    readonly property real centerY: Math.max(edgeMargin + placedHeight / 2, Math.min(height - edgeMargin - placedHeight / 2, defaultCenterY + value.y * height / 100))
    readonly property rect bounds: Qt.rect(centerX - placedWidth / 2, centerY - placedHeight / 2, placedWidth, placedHeight)
    function fittedLayout() {
        var next = Catalog.layout(value);
        var zoom = next.zoom * fit;
        if (zoom < Catalog.layoutScaleMin) {
            next.width *= zoom / Catalog.layoutScaleMin; next.height *= zoom / Catalog.layoutScaleMin; zoom = Catalog.layoutScaleMin;
            if (next.width < Catalog.layoutScaleMin || next.height < Catalog.layoutScaleMin) return null;
        }
        next.zoom = zoom;
        return next;
    }
    function setDraft(key, number, base, anchorCenter) {
        var next = Catalog.layout(base || value);
        if (key === "zoom" || key === "width" || key === "height") {
            var maxWidth = Math.max(1, width - edgeMargin*2);
            var maxHeight = Math.max(1, height - edgeMargin*2);
            // Saturate only the edited dimension. Re-fitting both dimensions
            // here would shrink the other axis when a handle reached an edge.
            var maximum = key === "width" ? maxWidth * 10000 / Math.max(1,baselineWidth*next.zoom)
                : key === "height" ? maxHeight * 10000 / Math.max(1,baseHeight*next.zoom)
                : Math.min(maxWidth * 10000 / Math.max(1,baselineWidth*next.width),
                    maxHeight * 10000 / Math.max(1,baseHeight*next.height));
            if (maximum < Catalog.layoutScaleMin) return;
            // A geometric minimum keeps the controls reachable. Independent
            // percentage floors can instead lock a large, already-fitted image.
            var minWidth = Math.min(Style.space(16), maxWidth, baselineWidth*next.zoom*next.width/10000);
            var minHeight = Math.min(Style.space(16), maxHeight, baseHeight*next.zoom*next.height/10000);
            var minimum = key === "width" ? minWidth*10000/Math.max(1,baselineWidth*next.zoom)
                : key === "height" ? minHeight*10000/Math.max(1,baseHeight*next.zoom)
                : Math.max(minWidth*10000/Math.max(1,baselineWidth*next.width), minHeight*10000/Math.max(1,baseHeight*next.height));
            number = Math.max(Math.min(minimum, maximum), Math.min(number, maximum));
            next[key] = number; next = Catalog.layout(next);
            var halfWidth = baselineWidth * next.zoom * next.width / 20000;
            var halfHeight = baseHeight * next.zoom * next.height / 20000;
            // Grow about the gesture's original centre. If an edge would leave
            // the viewport, move only as far as needed to fit the new size.
            // A fixed gesture anchor also makes reversing the drag reversible.
            var cx = Math.max(edgeMargin+halfWidth, Math.min(width-edgeMargin-halfWidth, anchorCenter ? anchorCenter.x : centerX));
            var cy = Math.max(edgeMargin+halfHeight, Math.min(height-edgeMargin-halfHeight, anchorCenter ? anchorCenter.y : centerY));
            if (Math.abs(cx - (width/2 + next.x*width/100)) > 0.001)
                next.x = (cx-width/2) * 100 / Math.max(1,width);
            if (Math.abs(cy - (defaultCenterY + next.y*height/100)) > 0.001)
                next.y = (cy-defaultCenterY) * 100 / Math.max(1,height);
        }
        next[key] = number; draft = Catalog.layout(next);
    }
    onDraftChanged: revision++
    function commit() {
        settle.stop(); if (!draft) return;
        var savingRevision = revision;
        var values = {}; values[target + "LogoLayout"] = draft;
        hostWidget.persistSettings(values, function(ok) {
            // A completed wheel save must not discard a newer drag in progress.
            if (root.revision === savingRevision) root.draft = null;
        });
    }
    function reset() { draft = Catalog.layout({}); commit(); }
    function centerAxis(horizontal) {
        setDraft(horizontal ? "x" : "y", horizontal ? 0
            : (height / 2 - defaultCenterY) * 100 / Math.max(1, height));
        commit();
    }
    function centerArtwork() {
        setDraft("x", 0);
        setDraft("y", (height / 2 - defaultCenterY) * 100 / Math.max(1, height));
        commit();
    }
    onEditingChanged: if (!editing) commit()
    onVisibleChanged: if (!visible) commit()
    Timer { id: settle; interval: 250; onTriggered: root.commit() }
    Binding { target: root.artwork; property: "parent"; value: placement }
    Binding { target: root.artwork; property: "width"; value: root.baselineWidth }
    Binding { target: root.artwork; property: "height"; value: root.baseHeight }
    Item {
        id: placement; objectName: "logoPlacementBounds"
        x: root.bounds.x; y: root.bounds.y; width: root.bounds.width; height: root.bounds.height
    }
    // The artwork is rendered at its natural size, with a presentation-only transform.
    Scale {
        id: artworkScale
        xScale: root.placedWidth / Math.max(1, root.baselineWidth)
        yScale: root.placedHeight / Math.max(1, root.baseHeight)
    }
    Component.onCompleted: root.artwork.transform = [artworkScale]
    Rectangle {
        x: root.bounds.x; y: root.bounds.y; width: root.bounds.width; height: root.bounds.height
        visible: root.editing; color: "transparent"; radius: Style.space(4)
        border.width: 1; border.color: root.hostWidget.accent
        WheelHandler {
            target: null; acceptedModifiers: Qt.ControlModifier
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(wheel) {
                var delta = wheel.angleDelta.y || wheel.pixelDelta.y;
                var base = root.fittedLayout();
                if (base) { root.setDraft("zoom", base.zoom * Math.pow(1.08, delta / 120), base); settle.restart(); }
                wheel.accepted = true;
            }
        }
        MouseArea {
            id: drag; objectName: "logoMoveHandle"; anchors.fill: parent
            cursorShape: Qt.SizeAllCursor; acceptedButtons: Qt.LeftButton
            property point origin
            property var start
            property point startCenter
            property size startSize
            property bool moving: false
            property bool centering: false
            onPressed: function(mouse) {
                settle.stop(); moving = false; centering = false;
                origin = mapToItem(root, mouse.x, mouse.y); start = Catalog.layout(root.value);
                startCenter = Qt.point(root.centerX,root.centerY); startSize = Qt.size(root.placedWidth,root.placedHeight);
            }
            onPositionChanged: function(mouse) {
                if (!pressed || centering) return;
                var p = mapToItem(root, mouse.x, mouse.y);
                if (!moving && Math.hypot(p.x-origin.x, p.y-origin.y) < Style.space(4)) return;
                moving = true;
                var next = Catalog.layout(start);
                var cx = Math.max(root.edgeMargin + startSize.width/2, Math.min(root.width-root.edgeMargin-startSize.width/2, startCenter.x+p.x-origin.x));
                var cy = Math.max(root.edgeMargin + startSize.height/2, Math.min(root.height-root.edgeMargin-startSize.height/2, startCenter.y+p.y-origin.y));
                next.x = (cx-root.width/2) * 100 / Math.max(1,root.width);
                next.y = (cy-root.defaultCenterY) * 100 / Math.max(1,root.height);
                root.draft = Catalog.layout(next);
            }
            onDoubleClicked: function(mouse) {
                centering = true; root.centerArtwork(); mouse.accepted = true;
            }
            onReleased: { root.commit(); moving = false; centering = false; }
            onCanceled: { root.draft = null; moving = false; centering = false; }
        }
        Repeater {
            model: ["left", "right", "top", "bottom"]
            Rectangle {
                required property string modelData
                readonly property bool horizontal: modelData === "left" || modelData === "right"
                readonly property string dimension: horizontal ? "width" : "height"
                readonly property int direction: modelData === "left" || modelData === "top" ? -1 : 1
                width: Math.min(Style.space(horizontal ? 10 : 32), parent.width / 3)
                height: Math.min(Style.space(horizontal ? 32 : 10), parent.height / 3)
                x: horizontal ? (direction > 0 ? parent.width : 0) - width / 2 : (parent.width - width) / 2
                y: horizontal ? (parent.height - height) / 2 : (direction > 0 ? parent.height : 0) - height / 2
                radius: Style.space(3); color: root.hostWidget.accent
                MouseArea {
                    id: resizeHandle
                    objectName: parent.modelData === "left" ? "logoLeftHandle" : parent.modelData === "top" ? "logoTopHandle"
                        : parent.horizontal ? "logoWidthHandle" : "logoHeightHandle"
                    // Give each edge its own middle-third target; its outer
                    // margin remains generous even when the artwork is short.
                    readonly property real across: Math.min(Style.space(9), (parent.horizontal ? root.placedWidth : root.placedHeight) / 3)
                    width: parent.horizontal ? Style.space(9) + across : Math.min(Style.space(40), root.placedWidth / 3)
                    height: parent.horizontal ? Math.min(Style.space(40), root.placedHeight / 3) : Style.space(9) + across
                    x: parent.horizontal ? parent.width/2 - (parent.direction < 0 ? Style.space(9) : across) : (parent.width-width)/2
                    y: parent.horizontal ? (parent.height-height)/2 : parent.height/2 - (parent.direction < 0 ? Style.space(9) : across)
                    cursorShape: parent.horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    Accessible.name: parent.horizontal ? root.copy.centerHorizontal : root.copy.centerVertical
                    property point origin
                    property point startCenter
                    property real start
                    property var startLayout
                    property bool stretching: false
                    property bool centering: false
                    onPressed: function(mouse) {
                        settle.stop(); centering = false;
                        origin = mapToItem(root,mouse.x,mouse.y);
                        startCenter = Qt.point(root.centerX,root.centerY);
                        startLayout = root.fittedLayout();
                        start = startLayout ? startLayout[parent.dimension] : 0; stretching = false;
                    }
                    onPositionChanged: function(mouse) {
                        if (!pressed || !startLayout || centering) return;
                        var point = mapToItem(root,mouse.x,mouse.y);
                        if (!stretching && Math.hypot(point.x-origin.x, point.y-origin.y) < Style.space(4)) return;
                        stretching = true;
                        // Grow symmetrically until a boundary requires translation.
                        var delta = 2 * parent.direction * (parent.horizontal ? point.x - origin.x : point.y - origin.y);
                        var size = parent.horizontal ? root.baselineWidth : root.baseHeight;
                        root.setDraft(parent.dimension, start + delta * 10000 / Math.max(1,size * startLayout.zoom), startLayout, startCenter);
                    }
                    onDoubleClicked: function(mouse) {
                        centering = true; root.centerAxis(parent.horizontal); mouse.accepted = true;
                    }
                    onReleased: { root.commit(); stretching = false; centering = false; }
                    onCanceled: { stretching = false; centering = false; root.draft = null; }
                    PanelHint {
                        hostWidget: root.hostWidget
                        requested: root.editing && resizeHandle.containsMouse && !resizeHandle.pressed
                        text: resizeHandle.parent.horizontal ? root.copy.widthHandle : root.copy.heightHandle
                    }
                }
            }
        }
        Repeater {
            model: ["topLeft", "topRight", "bottomLeft", "bottomRight"]
            Rectangle {
                required property string modelData
                readonly property int directionX: modelData === "topLeft" || modelData === "bottomLeft" ? -1 : 1
                readonly property int directionY: modelData === "topLeft" || modelData === "topRight" ? -1 : 1
                width: Math.min(Style.space(10), root.placedWidth / 3, root.placedHeight / 3); height: width
                x: (directionX > 0 ? parent.width : 0) - width / 2
                y: (directionY > 0 ? parent.height : 0) - height / 2
                radius: width / 2; color: root.hostWidget.accent
                MouseArea {
                    id: cornerHandle
                    objectName: parent.modelData === "topLeft" ? "logoScaleHandle"
                        : parent.modelData === "topRight" ? "logoScaleTopRightHandle"
                        : parent.modelData === "bottomLeft" ? "logoScaleBottomLeftHandle" : "logoScaleBottomRightHandle"
                    readonly property real insideX: Math.min(Style.space(9), root.placedWidth / 3)
                    readonly property real insideY: Math.min(Style.space(9), root.placedHeight / 3)
                    width: Style.space(9) + insideX; height: Style.space(9) + insideY
                    x: parent.width/2 - (parent.directionX < 0 ? Style.space(9) : insideX)
                    y: parent.height/2 - (parent.directionY < 0 ? Style.space(9) : insideY)
                    cursorShape: parent.directionX === parent.directionY ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                    acceptedButtons: Qt.LeftButton; hoverEnabled: true
                    Accessible.name: root.copy.scaleHandle
                    property point origin
                    property point diagonal
                    property point startCenter
                    property real startZoom
                    property var startLayout
                    property bool resizing: false
                    onPressed: function(mouse) {
                        settle.stop(); resizing = false;
                        origin = mapToItem(root, mouse.x, mouse.y);
                        startCenter = Qt.point(root.centerX,root.centerY);
                        diagonal = Qt.point(parent.directionX * root.placedWidth / 2, parent.directionY * root.placedHeight / 2);
                        // Start from the displayed size, including any viewport fit.
                        // Moving inward then shrinks immediately even at the limit.
                        startLayout = root.fittedLayout();
                        startZoom = startLayout ? startLayout.zoom : 0;
                    }
                    onPositionChanged: function(mouse) {
                        if (!pressed || !startLayout) return;
                        var point = mapToItem(root, mouse.x, mouse.y);
                        var dx = point.x-origin.x, dy = point.y-origin.y;
                        if (!resizing && Math.hypot(dx,dy) < Style.space(4)) return;
                        resizing = true;
                        // Project onto the original centre-to-corner diagonal. One
                        // scale changes both dimensions; crossing the centre cannot flip it.
                        var factor = 1 + (dx*diagonal.x + dy*diagonal.y)
                            / Math.max(1, diagonal.x*diagonal.x + diagonal.y*diagonal.y);
                        root.setDraft("zoom", startZoom * factor, startLayout, startCenter);
                    }
                    onReleased: { root.commit(); resizing = false; }
                    onCanceled: { resizing = false; root.draft = null; }
                    PanelHint {
                        hostWidget: root.hostWidget
                        requested: root.editing && cornerHandle.containsMouse && !cornerHandle.pressed
                        text: root.copy.scaleHandle
                    }
                }
            }
        }
        LabelButton {
            objectName: "resetLogoPlacement"; anchors.right: parent.right
            anchors.rightMargin: Style.space(16)
            y: parent.height > height * 2 ? Style.space(12) : -height - Style.space(8)
            label: "↺"; focusable: true; bordered: true; accent: root.hostWidget.accent
            Accessible.name: root.copy.restore
            onClicked: root.reset()
        }
    }
}
