import QtQuick
import qs.Ui as Ui

Ui.Button {
  id: root
  property var hostWidget: null
  property bool hintsAllowed: true
  property string hintText: ""
  property real hintWidth: 400
  property bool pointerHovered: false
  Connections { target: root; function onHovered(value) { root.pointerHovered = value; } }
  PanelHint {
    hostWidget: root.hostWidget
    requested: root.pointerHovered && root.hintsAllowed && root.enabled && root.hintText !== ""
    text: root.hintText
    maximumWidth: root.hintWidth
  }
}
