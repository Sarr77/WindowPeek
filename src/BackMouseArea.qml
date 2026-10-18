import QtQuick

// Secondary clicks go back; hover, primary clicks and scrolling reach controls.
MouseArea {
    anchors.fill: parent
    z: 100
    acceptedButtons: Qt.RightButton
    onWheel: function(wheel) { wheel.accepted = false; }
}
