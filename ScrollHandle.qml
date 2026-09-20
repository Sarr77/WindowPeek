import QtQuick
import QtQuick.Controls as QQC
import qs.Commons

QQC.ScrollBar {
  id: root
  property color accent: Color.accent
  property real uiScale: 1
  implicitWidth: Style.space(12) * uiScale
  padding: Style.space(4) * uiScale
  hoverEnabled: true
  policy: QQC.ScrollBar.AsNeeded
  visible: size < 1 && policy !== QQC.ScrollBar.AlwaysOff
  minimumSize: 0.06
  contentItem: Rectangle {
    implicitWidth: Style.space(4) * root.uiScale
    radius: width / 2
    // Keep the current scroll position visible after pointer or wheel input ends.
    color: Qt.alpha(root.accent, root.pressed ? 0.95 : 0.7)
  }
  background: Rectangle {
    radius: width / 2
    color: Qt.alpha(root.accent, root.hovered || root.pressed ? 0.06 : 0)
    Behavior on color { ColorAnimation { duration: 120 } }
  }
}
