import QtQuick
import qs.Ui as Ui
import qs.Commons
import "I18n.js" as I18n
import "Settings.js" as Settings

ReadableButton {
  id: root
  required property var words
  property bool hintsEnabled: true
  property bool automatic: true
  property int remaining: Settings.hintLimit
  property real hintWidth: 400
  property Item hintAnchor: null
  text: "?"
  width: Style.space(24)
  height: width
  horizontalPadding: 0
  verticalPadding: 0
  radius: width / 2
  fontSize: Style.font.caption
  selected: hintsEnabled
  bordered: true
  // Always explain this switch, even when every other panel hint is disabled.
  readonly property string helpText: hintsEnabled && automatic
    ? I18n.format(remaining === 1 ? words.hintsAutomaticOne : words.hintsAutomatic, {remaining: remaining})
    : (hintsEnabled ? words.hintsOn : words.hintsOff)
  property bool pointerHovered: false
  Connections { target: root; function onHovered(value) { root.pointerHovered = value; } }
  PanelHint {
    hostWidget: null
    alwaysAvailable: true
    requested: root.pointerHovered
    belowAnchor: !!root.hintAnchor
    anchorItem: root.hintAnchor || root
    text: root.helpText
    maximumWidth: root.hintWidth
  }
  Accessible.role: Accessible.CheckBox
  Accessible.name: words.panelHints
  Accessible.description: helpText
  Accessible.checkable: true
  Accessible.checked: hintsEnabled
  Accessible.onToggleAction: clicked()
}
