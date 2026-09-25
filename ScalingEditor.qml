import QtQuick
import qs.Ui as Ui
import qs.Commons
import "I18n.js" as I18n

Column {
  id: root
  objectName: "scalingEditor"
  required property var hostWidget
  readonly property var words: hostWidget ? hostWidget.words : I18n.words("en")
  readonly property color accent: hostWidget ? hostWidget.accent : Color.accent
  property int panelPercent: 100
  property int barPercent: 100
  property bool saveFailed: false
  property bool saving: false
  enabled: !saving
  signal finished(var focusReason)
  signal ensureVisible(var item)
  spacing: Style.space(14)

  function draft() { return {uiScale: panelPercent / 100, barScale: barPercent / 100}; }
  function begin() {
    panelPercent = Math.round(hostWidget.savedAppearance.uiScale * 100);
    barPercent = Math.round(hostWidget.savedAppearance.barScale * 100);
    panelControl.resetInput(); barControl.resetInput();
    saveFailed = false;
    publishPreview();
    root.forceActiveFocus();
  }
  function publishPreview() { hostWidget.previewAppearance(draft()); }
  function cancel(focusReason) { hostWidget.cancelAppearance(); finished(focusReason); }
  function apply(focusReason) {
    if (!panelControl.valid || !barControl.valid) return;
    if (saving) return;
    saving = true;
    hostWidget.saveAppearance(draft(), function(ok) {
      saving = false;
      if (ok) finished(focusReason); else saveFailed = true;
    });
  }
  Keys.onEscapePressed: function(event) { root.cancel(Qt.TabFocusReason); event.accepted = true; }

  ReadableText {
    width: parent.width
    text: "WindowPeek · " + root.words.scaling
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    horizontalAlignment: Text.AlignLeft
    textColor: Color.popups.text
    font.pixelSize: Style.font.subtitle
    font.bold: true
  }
  ReadableText {
    width: parent.width
    text: root.words.scaleHelp
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    horizontalAlignment: Text.AlignLeft
    textColor: Color.popups.text
    opacity: 0.75
    font.pixelSize: Style.font.caption
  }
  ScaleControl {
    hostWidget: root.hostWidget
    id: panelControl
    objectName: "panelScaleControl"
    width: parent.width
    label: root.words.panelScale
    invalidText: root.words.invalidScale
    words: root.words
    percent: root.panelPercent
    accent: root.accent
    onChanged: function(percent) { root.panelPercent = percent; root.publishPreview(); }
    onAccepted: root.apply()
    onEnsureVisible: root.ensureVisible(panelControl)
  }
  ScaleControl {
    hostWidget: root.hostWidget
    id: barControl
    objectName: "barScaleControl"
    width: parent.width
    label: root.words.barScale
    invalidText: root.words.invalidScale
    words: root.words
    percent: root.barPercent
    accent: root.accent
    onChanged: function(percent) { root.barPercent = percent; root.publishPreview(); }
    onAccepted: root.apply()
    onEnsureVisible: root.ensureVisible(barControl)
  }
  ReadableText {
    width: parent.width
    visible: root.hostWidget && Math.round(root.hostWidget.effectiveBarScale * 100) < root.barPercent
    text: I18n.format(root.words.barScaleLimit, {percent: root.hostWidget ? Math.round(root.hostWidget.effectiveBarScale * 100) : 100})
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    horizontalAlignment: Text.AlignLeft
    textColor: Color.popups.text
    font.pixelSize: Style.font.caption
  }
  ReadableText { text: root.words.preview; textColor: Color.popups.text; font.pixelSize: Style.font.caption }
  // The surrounding panel already supplies the selected scale.
  AppearancePreview { width: parent.width; hostWidget: root.hostWidget }
  ReadableText {
    visible: root.saveFailed
    width: parent.width
    text: root.words.saveStyleError
    textFormat: Text.PlainText
    textColor: Color.urgent
    wrapMode: Text.Wrap
    font.pixelSize: Style.font.body
  }
  Row {
    width: parent.width; spacing: Style.space(10)
    LabelButton { id: cancelButton; width: (parent.width-parent.spacing)/2; label: root.words.cancel; focusable: true; onClicked: root.cancel(activationFocusReason); onActiveFocusChanged: if (activeFocus) root.ensureVisible(cancelButton) }
    LabelButton { id: applyButton; width: (parent.width-parent.spacing)/2; label: root.words.apply; focusable: true; bordered: true; accent: root.accent; enabled: panelControl.valid && barControl.valid; onClicked: root.apply(activationFocusReason); onActiveFocusChanged: if (activeFocus) root.ensureVisible(applyButton) }
  }
}
