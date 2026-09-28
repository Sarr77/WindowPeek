import QtQuick
import qs.Ui as Ui
import qs.Commons

ReadableButton {
  id: root
  required property string label
  required property color swatch
  required property real maximumWidth
  property string scopeLabel: ""
  readonly property string hexText: String(swatch).toUpperCase()
  focusable: true
  bordered: true
  Accessible.name: label + " " + hexText + (scopeLabel ? " · " + scopeLabel : "")
  width: Math.min(maximumWidth, Math.max(metrics.width + hexMetrics.width + Style.space(48), scopeMetrics.width + Style.space(20)))
  implicitHeight: Style.space(scopeLabel ? 50 : 32)
  TextMetrics { id: metrics; text: root.label; font.pixelSize: Style.font.caption; font.family: Style.font.family }
  TextMetrics { id: scopeMetrics; text: root.scopeLabel; font: scopeText.font }
  TextMetrics { id: hexMetrics; text: "· " + root.hexText; font: hexLabel.font }
  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.scopeLabel ? Style.space(8) : (parent.height-height)/2
    width: parent.width - Style.space(20)
    spacing: Style.space(6)
    Rectangle {
      width: Style.space(12); height: width; radius: width/2
      anchors.verticalCenter: parent.verticalCenter
      color: root.swatch
      border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.2)
    }
    ReadableText {
      width: Math.max(0, parent.width - Style.space(24) - hexLabel.width)
      text: root.label; textFormat: Text.PlainText
      textColor: root.foreground
      font.pixelSize: Style.font.caption
      font.family: Style.font.family
      elide: Text.ElideRight
    }
    ReadableText {
      id: hexLabel
      objectName: "presetHex"
      text: "· " + root.hexText
      textColor: root.foreground
      font.pixelSize: Style.font.caption
      font.family: Style.font.family
    }
  }
  ReadableText {
    id: scopeText; anchors.left: parent.left; anchors.right: parent.right
    anchors.margins: Style.space(10); anchors.bottom: parent.bottom; anchors.bottomMargin: Style.space(7)
    visible: root.scopeLabel !== ""; text: root.scopeLabel; textFormat: Text.PlainText
    textColor: root.foreground; font.pixelSize: Style.font.caption; font.family: Style.font.family
    elide: Text.ElideRight
  }
}
