import QtQuick

// Retain the former card area across a resize, until the pointer reaches the
// new card or leaves the old area. This item never requests keyboard focus.
Item {
    id: root
    required property Item card
    property rect bounds: Qt.rect(0, 0, 0, 0)
    readonly property bool active: bounds.width > 0
    readonly property bool containsPointer: pointer.hovered
    readonly property point pointerPosition: pointer.point.position
    signal clicked()
    x: bounds.x; y: bounds.y; width: bounds.width; height: bounds.height
    z: 100
    visible: active
    function retain() {
        // Showing the area can synchronously update hover before its first frame.
        settleTimer.restart();
        bounds = Qt.rect(card.x, card.y, card.width, card.height);
    }
    function release() {
        bounds = Qt.rect(0, 0, 0, 0);
        settleTimer.stop();
    }
    function settle() {
        if (!active) return;
        var px = x + pointer.point.position.x, py = y + pointer.point.position.y;
        if (!containsPointer || (px >= card.x && px < card.x + card.width
                && py >= card.y && py < card.y + card.height)) release();
    }
    Timer { id: settleTimer; interval: 240; onTriggered: root.settle() }
    HoverHandler {
        id: pointer
        blocking: false
        onHoveredChanged: if (!hovered && !settleTimer.running) root.release()
        onPointChanged: if (hovered && !settleTimer.running) root.settle()
    }
    MouseArea {
        anchors.fill: parent
        onPressed: function(mouse) {
            var px = root.x + mouse.x, py = root.y + mouse.y;
            if (px >= root.card.x && px < root.card.x + root.card.width
                    && py >= root.card.y && py < root.card.y + root.card.height) mouse.accepted = false;
        }
        onWheel: function(wheel) { wheel.accepted = false; }
        onClicked: root.clicked()
    }
}
