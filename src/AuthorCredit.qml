import QtQuick
import qs.Commons
import qs.Commons as Commons

ReadableText {
  property color foreground: Commons.Color.popups.text
  textFormat: Text.PlainText
  textColor: Qt.alpha(foreground, 0.65)
  font.pixelSize: Style.font.caption
  Accessible.role: Accessible.StaticText
  Accessible.name: text
}
