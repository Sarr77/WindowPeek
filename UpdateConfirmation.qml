import QtQuick
import qs.Commons

FocusScope {
  id: root
  required property var words
  property var hostWidget: null
  property real dismissMargin: 0
  property bool opened: false
  property bool notificationMode: false
  property bool rtl: false
  property bool keyboardInput: false
  property color foreground: Color.popups.text
  property color accent: Color.accent
  signal canceled(int focusReason)
  signal confirmed(int focusReason)
  signal updatesRequested(int focusReason)
  readonly property bool popupOpen: opened
  readonly property Item popupInputItem: card
  readonly property string question: notificationMode ? words.notificationsOffQuestion : words.updatesOffQuestion
  readonly property string explanation: notificationMode ? words.notificationsOffWarning : words.updatesOffWarning
  visible: opened
  Accessible.role: Accessible.Dialog
  Accessible.name: question
  Accessible.description: explanation
  function open(notifications) { notificationMode = notifications === true; keyboardInput = false; opened = true; cancelButton.forceActiveFocus(Qt.OtherFocusReason); }
  function close() { cancel(); }
  function primary(reason) {
    if (!notificationMode) { cancel(reason); return; }
    if (opened) { opened = false; updatesRequested(reason === undefined ? Qt.MouseFocusReason : reason); }
  }
  function cancel(reason) { if (opened) { opened = false; canceled(reason === undefined ? Qt.MouseFocusReason : reason); } }
  function confirm(reason) { if (opened) { opened = false; confirmed(reason === undefined ? Qt.MouseFocusReason : reason); } }
  Keys.onShortcutOverride: function(event) { keyboardInput = true; event.accepted = false; }
  Keys.onEscapePressed: function(event) { cancel(Qt.TabFocusReason); event.accepted = true; }
  BackMouseArea { enabled: root.opened; onClicked: root.cancel() }
  MouseArea { anchors.fill: parent; anchors.margins: -root.dismissMargin; hoverEnabled: true; onClicked: root.cancel(); onWheel: function(wheel) { wheel.accepted = true; } }
  DropdownSurface {
    id: card; objectName: "updateOffCard"
    anchors.centerIn: parent
    width: Math.min(parent.width, Style.space(388))
    height: content.implicitHeight + Style.space(32)
    hostWidget: root.hostWidget; uiScale: root.hostWidget ? root.hostWidget.uiScale : 1
    fallbackBackground: root.hostWidget ? root.hostWidget.surfaces.pickerBackground : Color.popups.background
    borderSpec: Border.flat(root.accent, Style.normalBorderWidth)
    radius: Style.space(8)
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
        text: root.question
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        textColor: root.foreground
        font.family: Style.font.family; font.pixelSize: Style.font.title
        font.bold: true
      }
      ReadableText {
        width: parent.width
        text: root.explanation
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        textColor: root.foreground
        font.family: Style.font.family; font.pixelSize: Style.font.title
      }
      Grid {
        id: actions
        width: parent.width
        readonly property real confirmWidth: root.notificationMode ? Math.max(Style.space(96), confirmButton.implicitWidth) : confirmButton.implicitWidth
        readonly property bool stacked: cancelButton.implicitWidth + confirmWidth + columnSpacing > width
        columns: stacked ? 1 : 2
        horizontalItemAlignment: root.rtl ? Grid.AlignLeft : Grid.AlignRight
        columnSpacing: Style.space(10)
        rowSpacing: Style.space(8)
        ActionButton {
          id: cancelButton
          objectName: "cancelUpdateOff"
          fontSize: Style.font.title
          width: actions.stacked ? actions.width : root.notificationMode ? actions.width - actions.confirmWidth - actions.columnSpacing : Math.max(implicitWidth,
            Math.min(actions.width * 0.3, actions.width - confirmButton.implicitWidth - actions.columnSpacing))
          text: root.notificationMode ? root.words.openUpdates : root.words.cancel
          accent: root.accent
          KeyNavigation.right: root.rtl ? null : confirmButton
          KeyNavigation.left: root.rtl ? confirmButton : null
          TapHandler { onPressedChanged: if (pressed) root.keyboardInput = false }
          onClicked: root.primary(root.keyboardInput || keyboardFocusVisible ? Qt.TabFocusReason : Qt.MouseFocusReason)
        }
        ActionButton {
          id: confirmButton
          objectName: "confirmUpdateOff"
          fontSize: Style.font.title
          width: actions.stacked ? (root.notificationMode ? Math.min(actions.width, actions.confirmWidth) : actions.width)
            : actions.width - cancelButton.width - actions.columnSpacing
          text: root.notificationMode ? root.words.turnOffNotifications : root.words.turnOffUpdates
          accent: root.accent
          KeyNavigation.left: root.rtl ? null : cancelButton
          KeyNavigation.right: root.rtl ? cancelButton : null
          TapHandler { onPressedChanged: if (pressed) root.keyboardInput = false }
          onClicked: root.confirm(root.keyboardInput || keyboardFocusVisible ? Qt.TabFocusReason : Qt.MouseFocusReason)
        }
      }
    }
  }
}
