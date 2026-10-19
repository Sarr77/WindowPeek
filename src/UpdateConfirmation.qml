import QtQuick
import qs.Commons
import qs.Commons as Commons
import "UpdateWords.js" as UpdateCopy

FocusScope {
  id: root
  required property var words
  property var hostWidget: null
  property real dismissMargin: 0
  property bool opened: false
  property bool notificationMode: false
  property bool installMode: false
  property string installCommit: ""
  property string installVersion: ""
  property string installVerification: "unknown"
  property string installChangesUrl: ""
  property bool rtl: false
  property bool keyboardInput: false
  property color foreground: Commons.Color.popups.text
  property color accent: Commons.Color.accent
  signal canceled(int focusReason)
  signal confirmed(int focusReason)
  signal updatesRequested(int focusReason)
  signal installRequested(string commit, string version, string verification)
  signal skipRequested(string version, string verification)
  readonly property bool popupOpen: opened
  readonly property Item popupInputItem: card
  readonly property var installWords: UpdateCopy.words(hostWidget ? hostWidget.language : "en")
  readonly property string question: installMode ? installWords.ready.replace("{version}", installVersion)
    : notificationMode ? words.notificationsOffQuestion : words.updatesOffQuestion
  readonly property string explanation: installMode ? installWords.askInstall
    : notificationMode ? words.notificationsOffWarning : words.updatesOffWarning
  visible: opened
  Accessible.role: Accessible.Dialog
  Accessible.name: question
  Accessible.description: explanation
  function open(notifications) { installMode = false; notificationMode = notifications === true; keyboardInput = false; opened = true; cancelButton.forceActiveFocus(Qt.OtherFocusReason); }
  function openInstall(commit, version, verification, changesUrl) {
    installCommit = commit; installVersion = version; installVerification = verification;
    installChangesUrl = changesUrl; installMode = true;
    notificationMode = false; keyboardInput = false; opened = true;
    cancelButton.forceActiveFocus(Qt.OtherFocusReason);
  }
  function close() { cancel(); }
  function primary(reason) {
    if (installMode || !notificationMode) { cancel(reason); return; }
    if (opened) { opened = false; updatesRequested(reason === undefined ? Qt.MouseFocusReason : reason); }
  }
  function cancel(reason) { if (opened) { opened = false; canceled(reason === undefined ? Qt.MouseFocusReason : reason); } }
  function confirm(reason) {
    if (!opened) return;
    var installing = installMode;
    opened = false;
    if (installing) installRequested(installCommit, installVersion, installVerification);
    else confirmed(reason === undefined ? Qt.MouseFocusReason : reason);
  }
  function skip() { if (opened && installMode) { opened = false; skipRequested(installVersion, installVerification); } }
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
    fallbackBackground: root.hostWidget ? root.hostWidget.surfaces.pickerBackground : Commons.Color.popups.background
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
      ReadableText {
        visible: root.installMode
        width: parent.width
        text: root.installWords.commit + ": " + root.installCommit.slice(0, 12)
        textFormat: Text.PlainText
        textColor: root.foreground
        font.family: Style.font.family; font.pixelSize: Style.font.caption
      }
      Row {
        visible: root.installMode; spacing: Style.space(8)
        Rectangle {
          objectName: "installVerificationDot"
          width: Style.space(8); height: width; radius: width / 2
          anchors.verticalCenter: parent.verticalCenter
          color: root.installVerification === "verified" ? "#92D992" : "#EDB65C"
        }
        ReadableText {
          text: root.installVerification === "verified" ? root.installWords.verified
            : root.installVerification === "unverified" ? root.installWords.unverified : root.installWords.unknown
          textColor: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
      }
      Row {
        visible: root.installMode; spacing: Style.space(18)
        ActionButton {
          text: root.installWords.changes; textOnly: true; accent: root.accent
          fontSize: Style.font.caption
          onClicked: if (root.installChangesUrl) BrowserLinks.open(root.installChangesUrl)
        }
        ActionButton {
          id: skipButton; objectName: "skipUpdateVersion"
          text: root.installWords.skip; textOnly: true; accent: root.accent
          fontSize: Style.font.caption
          onClicked: root.skip()
        }
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
          KeyNavigation.priority: KeyNavigation.BeforeItem
          KeyNavigation.backtab: confirmButton
          fontSize: Style.font.title
          width: actions.stacked ? actions.width : root.notificationMode ? actions.width - actions.confirmWidth - actions.columnSpacing : Math.max(implicitWidth,
            Math.min(actions.width * 0.3, actions.width - confirmButton.implicitWidth - actions.columnSpacing))
          text: root.installMode ? root.installWords.later
            : root.notificationMode ? root.words.openUpdates : root.words.cancel
          accent: root.accent
          KeyNavigation.right: root.rtl ? null : confirmButton
          KeyNavigation.left: root.rtl ? confirmButton : null
          TapHandler { onPressedChanged: if (pressed) root.keyboardInput = false }
          onClicked: root.primary(root.keyboardInput || keyboardFocusVisible ? Qt.TabFocusReason : Qt.MouseFocusReason)
        }
        ActionButton {
          id: confirmButton
          objectName: "confirmUpdateOff"
          KeyNavigation.priority: KeyNavigation.BeforeItem
          KeyNavigation.tab: cancelButton
          fontSize: Style.font.title
          width: actions.stacked ? (root.notificationMode ? Math.min(actions.width, actions.confirmWidth) : actions.width)
            : actions.width - cancelButton.width - actions.columnSpacing
          text: root.installMode ? root.installWords.install
            : root.notificationMode ? root.words.turnOffNotifications : root.words.turnOffUpdates
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
