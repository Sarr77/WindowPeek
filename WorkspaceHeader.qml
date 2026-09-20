import QtQuick
import qs.Commons
import "I18n.js" as I18n

Item {
    id: root
    objectName: "workspaceHeader"
    required property var row
    required property var hostWidget
    property bool compact: false
    readonly property var words: hostWidget ? hostWidget.words : I18n.words("en")
    readonly property string workspaceName: row ? row.workspaceName : ""
    readonly property bool hidden: {
        if (!row || row.workspaceId === 0 || !hostWidget || !hostWidget.snapshot
                || !Array.isArray(hostWidget.snapshot.monitors)) return false;
        var monitors = hostWidget.snapshot.monitors.filter(function(monitor) { return !monitor.disabled; });
        return monitors.length > 0 && monitors.every(function(monitor) {
            return monitor.activeWorkspace && Number.isInteger(monitor.activeWorkspace.id)
                && monitor.activeWorkspace.id !== root.row.workspaceId
                && (!monitor.specialWorkspace || monitor.specialWorkspace.id !== root.row.workspaceId);
        });
    }
    readonly property real lineHeight: Style.space(compact ? 25 : 29)
    implicitHeight: lineHeight + (row && !row.first ? Style.space(compact ? 8 : 12) : 0)
    height: implicitHeight

    TextMetrics { id: nameMetrics; text: nameLabel.text; font: nameLabel.font }
    TextMetrics { id: hiddenMetrics; text: hiddenLabel.text; font: hiddenLabel.font }
    TextMetrics { id: monitorMetrics; text: monitor.text; font: monitor.font }

    Item {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: root.lineHeight
        Row {
            anchors.left: parent.left; anchors.right: monitor.left; anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: hiddenLabel.visible ? Style.space(8) : 0
            Text {
                id: nameLabel
                objectName: "workspaceName"
                width: Math.max(0, Math.min(nameMetrics.advanceWidth, parent.width - hiddenLabel.width - parent.spacing))
                text: I18n.workspaceTitle(root.workspaceName, root.words)
                textFormat: Text.PlainText; elide: Text.ElideRight
                color: Qt.alpha(Color.popups.text, 0.8)
                font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true
            }
            Text {
                id: hiddenLabel; objectName: "hiddenWorkspace"
                visible: root.hidden
                width: visible ? Math.min(hiddenMetrics.advanceWidth, parent.width * 0.4) : 0
                text: "· " + root.words.hiddenWorkspace
                textFormat: Text.PlainText; elide: Text.ElideRight
                color: Qt.alpha(Color.popups.text, 0.55)
                font.family: Style.font.family; font.pixelSize: Style.font.caption
            }
        }
        Text {
            id: monitor; objectName: "workspaceMonitor"
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: Math.min(monitorMetrics.advanceWidth, parent.width * 0.35)
            text: root.row && root.row.monitorName ? root.row.monitorName : root.words.unknownMonitor
            textFormat: Text.PlainText; elide: Text.ElideRight
            color: Qt.alpha(Color.popups.text, 0.45)
            font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
    }
}
