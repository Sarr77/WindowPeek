import QtQuick
Item {
 property string address: ""
 property bool active: false
 readonly property bool hasContent: true
 readonly property size sourceSize: Qt.size(320,200)
 Rectangle { anchors.fill: parent; color: "#324555" }
}
