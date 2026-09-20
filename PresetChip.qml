import QtQuick
import qs.Ui as Ui
import qs.Commons

Ui.Button {
  id: root
  required property string label
  required property color swatch
  required property real maximumWidth
  readonly property string hexText: String(swatch).toUpperCase()
  focusable: true
  bordered: true
  Accessible.name: label + " " + hexText
  width: Math.min(maximumWidth, metrics.width + hexMetrics.width + Style.space(48))
  implicitHeight: Style.space(32)
  TextMetrics { id: metrics; text: root.label; font.pixelSize: Style.font.caption; font.family: Style.font.family }
  TextMetrics { id: hexMetrics; text: "· " + root.hexText; font: hexLabel.font }
  Row {
    anchors.centerIn: parent
    width: parent.width - Style.space(20)
    spacing: Style.space(6)
    Rectangle {
      width: Style.space(12); height: width; radius: width/2
      anchors.verticalCenter: parent.verticalCenter
      color: root.swatch
      border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.2)
    }
    Text {
      width: Math.max(0, parent.width - Style.space(24) - hexLabel.width)
      text: root.label; textFormat: Text.PlainText
      color: root.foreground
      font.pixelSize: Style.font.caption
      font.family: Style.font.family
      elide: Text.ElideRight
    }
    Text {
      id: hexLabel
      objectName: "presetHex"
      text: "· " + root.hexText
      color: root.foreground
      font.pixelSize: Style.font.caption
      font.family: Style.font.family
    }
  }
}
