import QtQuick

// Scale mouse-wheel travel while retaining Flickable's animation and bounds.
// Pixel-based touchpad gestures continue through Qt's native event handler.
MouseArea {
    id: root
    required property Flickable view
    property real speed: 102
    property real savedDeceleration: 0
    property bool adjusted: false
    parent: view
    anchors.fill: parent
    z: 1
    acceptedButtons: Qt.NoButton
    scrollGestureEnabled: false
    enabled: view.visible && view.enabled && view.interactive
    function restoreDeceleration() {
        if (adjusted && view) { adjusted = false; view.flickDeceleration = savedDeceleration; }
    }
    Connections {
        target: root.view
        function onFlickingVerticallyChanged() { if (!root.view.flickingVertically) root.restoreDeceleration(); }
        function onDraggingChanged() { if (root.view.dragging) root.restoreDeceleration(); }
    }
    Component.onDestruction: restoreDeceleration()
    onWheel: function(event) {
        if (event.pixelDelta.x || event.pixelDelta.y || !event.angleDelta.y) {
            event.accepted = false;
            return;
        }
        event.accepted = true;
        if (view.contentHeight <= view.height) return;
        var direction = event.angleDelta.y > 0 ? 1 : -1;
        if ((direction > 0 && view.atYBeginning) || (direction < 0 && view.atYEnd)) return;
        var lines = Qt.styleHints.wheelScrollLines || 3;
        var distance = Math.abs(event.angleDelta.y) / 120 * lines * 24 * speed / 100;
        // Qt uses a faster deceleration for wheels than for touch drags.
        // Apply it only to this wheel flick, then restore the drag setting.
        var deceleration = 15000;
        var velocity = view.flickingVertically ? -view.verticalVelocity : 0;
        var carried = velocity * direction > 0 ? velocity * velocity : 0;
        if (!adjusted) { savedDeceleration = view.flickDeceleration; adjusted = true; }
        view.flickDeceleration = deceleration;
        view.flick(0, direction * Math.min(view.maximumFlickVelocity,
            Math.sqrt(carried + 2 * deceleration * distance)));
        if (!view.flickingVertically) restoreDeceleration();
    }
}
