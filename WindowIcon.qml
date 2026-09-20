import QtQuick
import Quickshell
import qs.Commons

Item {
    id: root
    property string appId: ""
    property real imageScale: 1
    readonly property var entry: {
        // Desktop entries are indexed asynchronously, including on first launch.
        DesktopEntries.applications.values;
        return DesktopEntries.heuristicLookup(appId);
    }
    readonly property int status: icon.status
    implicitWidth: Style.space(24)
    implicitHeight: implicitWidth
    Image {
        id: icon
        anchors.fill: parent
        source: root.entry && root.entry.icon ? Quickshell.iconPath(root.entry.icon, true) : ""
        sourceSize: Qt.size(Math.ceil(root.width * root.imageScale), Math.ceil(root.height * root.imageScale))
        fillMode: Image.PreserveAspectFit
    }
    Item {
        anchors.fill: parent; anchors.margins: parent.width * 0.15
        visible: !icon.source || icon.status !== Image.Ready
        Rectangle {
            x: parent.width * 0.23; y: 0; width: parent.width * 0.77; height: parent.height * 0.77
            radius: 2; color: Color.popups.background
            border.color: Qt.alpha(Color.popups.text, 0.3)
        }
        Rectangle {
            y: parent.height * 0.23; width: parent.width * 0.77; height: parent.height * 0.77
            radius: 2; color: Color.popups.background
            border.color: Qt.alpha(Color.popups.text, 0.65)
            Rectangle { x: 1; y: parent.height * 0.3; width: parent.width - 2; height: 1; color: parent.border.color }
        }
    }
}
