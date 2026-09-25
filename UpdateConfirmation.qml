import QtQuick
import qs.Ui as Ui
import qs.Commons

FocusScope {
  id: root
  required property var words
  property bool opened: false
  property bool rtl: false
  property int selectedIndex: 0
  property color foreground: Color.popups.text
  property color accent: Color.accent
  signal canceled()
  signal confirmed()
  visible: opened
  Accessible.role: Accessible.Dialog
  Accessible.name: words.updatesOffQuestion
  Accessible.description: words.updatesOffWarning
  function open() { selectedIndex = 0; opened = true; forceActiveFocus(); }
  function cancel() { if (opened) { opened = false; canceled(); } }
  function confirm() { if (opened) { opened = false; confirmed(); } }
  Keys.onPressed: function(event) {
    if (!opened) return;
    event.accepted = true;
    if (event.isAutoRepeat) return;
    if (event.key === Qt.Key_Escape) cancel();
    else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) selectedIndex = 1 - selectedIndex;
    else if (event.key === Qt.Key_Left) selectedIndex = rtl ? 1 : 0;
    else if (event.key === Qt.Key_Right) selectedIndex = rtl ? 0 : 1;
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      if (selectedIndex === 0) cancel(); else confirm();
    }
  }
  BackMouseArea { enabled: root.opened; onClicked: root.cancel() }
  Rectangle { anchors.fill: parent; color: Qt.alpha(Color.popups.background, 0.86) }
  MouseArea { anchors.fill: parent; onClicked: root.cancel(); onWheel: function(wheel) { wheel.accepted = true; } }
  Ui.BorderSurface {
    anchors.centerIn: parent
    width: Math.min(parent.width, Style.space(388))
    height: content.implicitHeight + Style.space(32)
    color: Color.popups.background
    borderSpec: Border.flat(root.accent, Style.normalBorderWidth)
    radius: Style.cornerRadius
    MouseArea {
      anchors.fill: parent
      onClicked: {}
      onWheel: function(wheel) { wheel.accepted = true; }
    }
    Column {
      id: content
      anchors.centerIn: parent
      width: parent.width - Style.space(32)
      spacing: Style.space(12)
      LayoutMirroring.enabled: root.rtl
      LayoutMirroring.childrenInherit: true
      ReadableText {
        width: parent.width
        text: root.words.updatesOffQuestion
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        textColor: root.foreground
        font.pixelSize: Style.font.body
        font.bold: true
      }
      ReadableText {
        width: parent.width
        text: root.words.updatesOffWarning
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        textColor: root.foreground
        font.pixelSize: Style.font.body
      }
      Grid {
        id: actions
        width: parent.width
        readonly property bool stacked: cancelButton.implicitWidth + confirmButton.implicitWidth + columnSpacing > width
        columns: stacked ? 1 : 2
        columnSpacing: Style.space(10)
        rowSpacing: Style.space(8)
        ReadableButton {
          id: cancelButton
          objectName: "cancelUpdateOff"
          width: actions.stacked ? actions.width : Math.max(implicitWidth,
            Math.min(actions.width * 0.3, actions.width - confirmButton.implicitWidth - actions.columnSpacing))
          text: root.words.cancel
          accent: root.accent
          hasCursor: root.selectedIndex === 0
          onClicked: root.cancel()
        }
        ReadableButton {
          id: confirmButton
          objectName: "confirmUpdateOff"
          width: actions.stacked ? actions.width : actions.width - cancelButton.width - actions.columnSpacing
          text: root.words.turnOffUpdates
          accent: root.accent
          bordered: true
          hasCursor: root.selectedIndex === 1
          onClicked: root.confirm()
        }
      }
    }
  }
}
