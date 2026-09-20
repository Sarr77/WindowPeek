import QtQuick
import qs.Ui as Ui
import qs.Commons

Item {
  id: root
  required property string text
  property bool checked: true
  property bool hasCursor: false
  property color foreground: Color.popups.text
  property color accent: Color.accent
  readonly property bool hot: pointer.containsMouse || hasCursor || activeFocus
  readonly property bool pointerHovered: pointer.containsMouse
  signal hovered(bool value)
  signal clicked()
  implicitWidth: track.width + Style.space(6) + label.implicitWidth
  implicitHeight: Style.space(24)
  activeFocusOnTab: true
  function activate() { if (enabled) clicked(); }
  Keys.onReturnPressed: activate()
  Keys.onEnterPressed: activate()
  Keys.onSpacePressed: activate()
  Accessible.role: Accessible.CheckBox
  Accessible.name: text
  Accessible.checkable: true
  Accessible.checked: checked
  Accessible.onToggleAction: activate()

  Ui.ToggleSwitch {
    id: track
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    checked: root.checked
    trackHeight: Style.space(10)
    interactive: false
    cursorRing: false
    foreground: root.foreground
    accent: root.accent
    opacity: root.hot ? 1 : 0.4
  }
  Text {
    id: label
    anchors.left: track.right
    anchors.leftMargin: Style.space(6)
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text: root.text
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: root.hot ? root.accent : Qt.alpha(root.foreground, 0.4)
    font.pixelSize: Math.max(9, Style.font.caption - 1)
  }
  MouseArea {
    id: pointer
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onContainsMouseChanged: root.hovered(containsMouse)
    onClicked: root.activate()
  }
}
