import QtQuick
import qs.Commons

Text {
  property color foreground: Color.popups.text
  textFormat: Text.PlainText
  color: Qt.alpha(foreground, 0.65)
  font.pixelSize: Style.font.caption
  Accessible.role: Accessible.StaticText
  Accessible.name: text
}
