// Adapted from Omarchy 4.0.4 shell/Ui/SearchableDropdown.qml (MIT). See LICENSE here.
// ScratchPeek: keep scaled popups inside their window; trigger clicks toggle once.
import QtQuick
import QtQuick.Window
import Quickshell
import "../../PopupPlacement.js" as Placement
import "../.." as WindowPeek
import qs.Ui
import QtQuick.Controls as QQC
import qs.Commons

// Searchable single-select dropdown. Same trigger shape as Dropdown, but
// the popup leads with an embedded TextField that filters the option
// list in real time. Use for pickers with enough options that scanning
// is friction.
//
// Filtering is case-insensitive substring against each option's label.
// Options can be string[] or [{ value, label, description? }] — the same
// shape Dropdown accepts. The filter clears whenever the popup closes.
//
// Keyboard: Tab to focus the trigger, Enter/Space opens (search focused
// immediately). Down arrow from the search jumps to the first match;
// Up from the first match returns to the search. Enter selects, Esc
// closes (and clears the filter).
Item {
  id: root

  property real uiScale: 1
  property var placement: ({x:0, y:0, width:0, height:0})
  // Follow a panel expanding or moving while this picker is already open.
  readonly property rect triggerRect: {
    placementWatcher.transform;
    return popup.visible ? trigger.mapToItem(null, 0, 0, trigger.width, trigger.height) : Qt.rect(0, 0, 0, 0);
  }
  onTriggerRectChanged: if (popup.visible) Qt.callLater(updatePlacement)
  TransformWatcher {
    id: placementWatcher
    a: popup.visible ? trigger : null
    b: root.Window.window ? root.Window.window.contentItem : null
  }
  function updatePlacement() {
    var point = trigger.mapToItem(null, 0, 0);
    var window = root.Window.window;
    placement = Placement.fit(point.x, point.y, trigger.width * uiScale, trigger.height * uiScale,
      window ? window.width : 0, window ? window.height : 0, uiScale,
      popup.implicitHeight, Style.spacing.xxs, Style.space(8));
  }
  onUiScaleChanged: if (popup.visible) Qt.callLater(updatePlacement)
  // Quickshell's window initially has a placeholder size before it maps.
  Connections {
    target: root.Window.window
    function onWidthChanged() { if (popup.visible) root.updatePlacement(); }
    function onHeightChanged() { if (popup.visible) root.updatePlacement(); }
  }

  property string label: ""
  property string value: ""
  property var options: []
  property string placeholderText: "Search..."
  property string emptyText: "No matches"
  property string triggerLabel: ""
  // Optional secondary trigger action; other pickers retain normal Ctrl-clicks.
  property bool controlClickEnabled: false
  property string accessibleDescription: ""
  readonly property bool triggerHovered: triggerHover.hovered
  signal controlClicked()

  property color foreground: Color.popups.text
  property color background: Color.popups.background
  property color accent: Color.accent
  property color popupBorder: accent
  readonly property var popupBorderSpec: Border.localOrSurfaceSpec("popups", "border", popupBorder, Color.popups.border, Style.normalBorderWidth)
  property string fontFamily: Style.font.family
  property real labelFontSize: Style.font.caption
  property int rowHeight: Style.spacing.controlHeight
  property int popupRowHeight: Style.spacing.popupRowHeight
  property int popupMinHeight: Style.spacing.searchablePopupMinHeight
  property bool showLabel: true
  readonly property real preferredPopupHeight: popup.implicitHeight

  // Panel-cursor flag. When true, the trigger renders the shared
  // hover-cursor state. Active Qt focus defaults to the same visuals.
  // Emits `hovered(bool)` on pointer enter/leave so the panel can keep
  // its cursor state in sync with the mouse.
  property bool hasCursor: false

  // popupOpen + open()/close()/toggle() let a parent panel know when the
  // dropdown owns keys (search field + result list are active) and
  // suspend its own keyCatcher so typing into the filter doesn't drive
  // the panel cursor.
  readonly property bool popupOpen: popup.opened
  function open() { popup.open() }
  function close() { popup.close() }
  function toggle() { popup.visible ? popup.close() : popup.open() }
  function focusTrigger() { trigger.forceActiveFocus() }

  signal changed(string value)
  signal hovered(bool isHovered)

  function optionValue(o) {
    return (o && typeof o === "object") ? String(o.value) : String(o)
  }
  function optionLabel(o) {
    return (o && typeof o === "object") ? String(o.label) : String(o)
  }
  function optionDescription(o) {
    return (o && typeof o === "object" && o.description) ? String(o.description) : ""
  }
  function currentLabel() {
    for (var i = 0; i < options.length; i++) {
      if (optionValue(options[i]) === value) return optionLabel(options[i])
    }
    return value
  }

  property var filtered: options
  function recomputeFiltered() {
    var q = searchField.text.toLowerCase()
    if (!q) { filtered = options; return }
    var out = []
    for (var i = 0; i < options.length; i++) {
      var lbl = optionLabel(options[i]).toLowerCase()
      var desc = optionDescription(options[i]).toLowerCase()
      if (lbl.indexOf(q) !== -1 || desc.indexOf(q) !== -1) out.push(options[i])
    }
    filtered = out
  }

  onOptionsChanged: recomputeFiltered()

  implicitWidth: Style.spacing.searchableDropdownWidth
  implicitHeight: showLabel && label !== "" ? rowHeight + Style.spacing.huge : rowHeight

  Column {
    anchors.fill: parent
    spacing: Style.spacing.labelGap

    Text {
      textFormat: Text.PlainText
      visible: root.showLabel && root.label !== ""
      text: root.label
      color: Qt.alpha(root.foreground, 0.8)
      font.family: root.fontFamily
      font.pixelSize: root.labelFontSize
      font.bold: true
    }

    BorderSurface {
      id: trigger
      width: parent.width
      height: root.rowHeight
      radius: Style.cornerRadius

      readonly property bool _focused: trigger.activeFocus
      readonly property bool _hot: triggerHover.hovered || root.hasCursor
      readonly property var _borderSpec: Border.controlSpec(trigger._focused ? "focus" : (trigger._hot ? "hover-cursor" : "normal"), root.foreground, root.accent)

      color: Style.controlFill(trigger._focused, trigger._hot, root.foreground, root.accent)
      borderSpec: _borderSpec

      activeFocusOnTab: true
      Accessible.role: Accessible.ComboBox
      Accessible.name: root.label || root.triggerLabel || root.placeholderText
      Accessible.description: root.accessibleDescription

      HoverHandler {
        id: triggerHover
        onHoveredChanged: root.hovered(hovered)
      }

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
            || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
          root.toggle()
          event.accepted = true
        } else if (event.key === Qt.Key_Escape && popup.opened) {
          popup.close(); trigger.forceActiveFocus(); event.accepted = true
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.right: chevron.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: trigger.borderLeft + Style.spacing.controlPaddingX
        anchors.rightMargin: trigger.borderRight + Style.spacing.md
        text: root.currentLabel() || root.triggerLabel || root.placeholderText
        color: (root.currentLabel() || root.triggerLabel) ? root.foreground : Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        id: chevron
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: trigger.borderRight + Style.spacing.controlGap
        text: "󰅀"
        color: Qt.darker(root.foreground, 1.2)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          if (root.controlClickEnabled && (mouse.modifiers & Qt.ControlModifier)) {
            popup.close()
            root.controlClicked()
            return
          }
          trigger.forceActiveFocus()
          root.toggle()
        }
      }

      QQC.Popup {
        id: popup
        WindowPeek.BackMouseArea {
          objectName: "popupBackPointer"
          parent: popup.contentItem
          onClicked: { popup.close(); trigger.forceActiveFocus(); }
        }
        // The trigger is this popup's parent. Do not auto-close on its mouse
        // press, then let onClicked reopen the popup during the same click.
        closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutsideParent
        // Placement.fit already handles transformed window bounds.
        margins: -1
        x: root.placement.x
        y: root.placement.y
        width: root.placement.width
        height: root.placement.height
        onAboutToShow: root.updatePlacement()
        onImplicitHeightChanged: if (visible) Qt.callLater(root.updatePlacement)
        implicitHeight: Math.max(root.popupMinHeight,
                                 Math.min(resultList.contentHeight + Style.space(50),
                                          root.popupRowHeight * 6 + 5 * Style.spacing.labelGap + Style.space(50)))
        padding: Style.spacing.hairline
        leftPadding: Border.left(root.popupBorderSpec) + Style.spacing.hairline
        rightPadding: Border.right(root.popupBorderSpec) + Style.spacing.hairline
        topPadding: Border.top(root.popupBorderSpec) + Style.spacing.hairline
        bottomPadding: Border.bottom(root.popupBorderSpec) + Style.spacing.hairline
        focus: true

        background: BorderSurface {
          color: root.background
          borderSpec: root.popupBorderSpec
          radius: Style.cornerRadius
        }

        onOpened: {
          searchField.text = ""
          root.recomputeFiltered()
          Qt.callLater(function() { searchField.forceActiveFocus() })
        }
        onClosed: searchField.text = ""

        // Keep the secondary-click overlay outside the positioned children.
        contentItem: Item {
          Column {
            anchors.fill: parent
            spacing: 0

            Item {
              id: searchHeader; objectName: "searchHeader"
              width: parent.width
              height: root.popupRowHeight + Style.spacing.controlPaddingX

              TextField {
                id: searchField
                anchors.fill: parent
                anchors.margins: Style.spacing.md
                placeholderText: root.placeholderText
                foreground: root.foreground
                accent: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body

                onTextChanged: {
                  root.recomputeFiltered()
                  if (resultList.count > 0) resultList.currentIndex = 0
                }

                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Escape) {
                    popup.close(); trigger.forceActiveFocus(); event.accepted = true
                  } else if (event.key === Qt.Key_Down) {
                    if (resultList.count > 0) {
                      resultList.currentIndex = 0
                      resultList.forceActiveFocus()
                    }
                    event.accepted = true
                  } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (resultList.count > 0) {
                      resultList.currentIndex = 0
                      resultList.selectCurrent()
                    }
                    event.accepted = true
                  }
                }
              }
            }

            Rectangle {
              width: parent.width
              height: 1
              color: Util.alpha(root.foreground, 0.10)
            }

            Item {
              width: parent.width
              height: Math.max(0, popup.availableHeight - searchHeader.height - 1)

              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                visible: resultList.count === 0
                text: root.emptyText
                color: Qt.darker(root.foreground, 1.6)
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }

              ListView {
                id: resultList; objectName: "resultList"
                anchors.fill: parent
                spacing: Style.spacing.labelGap
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.filtered
                currentIndex: -1
                keyNavigationEnabled: false

                function selectCurrent() {
                  if (currentIndex < 0 || currentIndex >= root.filtered.length) return
                  var v = root.optionValue(root.filtered[currentIndex])
                  root.value = v
                  root.changed(v)
                  popup.close()
                }

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Escape) {
                    popup.close(); trigger.forceActiveFocus(); event.accepted = true
                  } else if (event.key === Qt.Key_Down || event.text === "j") {
                    if (resultList.currentIndex >= resultList.count - 1) {
                      event.accepted = true; return
                    }
                    resultList.currentIndex = resultList.currentIndex + 1
                    event.accepted = true
                  } else if (event.key === Qt.Key_Up || event.text === "k") {
                    if (resultList.currentIndex <= 0) {
                      searchField.forceActiveFocus()
                      event.accepted = true; return
                    }
                    resultList.currentIndex = resultList.currentIndex - 1
                    event.accepted = true
                  } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    resultList.selectCurrent(); event.accepted = true
                  }
                }

                delegate: Rectangle {
                  required property var modelData
                  required property int index
                  width: resultList.width
                  height: Math.max(root.popupRowHeight, rowContent.implicitHeight + Style.spacing.rowPaddingX)
                  color: index === resultList.currentIndex
                    ? Style.hoverFillFor(root.foreground, root.accent)
                    : "transparent"

                  Column {
                    id: rowContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.spacing.controlPaddingX
                    anchors.rightMargin: Style.spacing.controlPaddingX
                    spacing: Style.spacing.xxs

                    Text {
                      textFormat: Text.PlainText
                      text: root.optionLabel(modelData)
                      color: index === resultList.currentIndex ? Style.hoverStateColor(root.foreground, root.accent) : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      elide: Text.ElideRight
                      width: parent.width
                    }
                    Text {
                      textFormat: Text.PlainText
                      visible: text !== ""
                      text: root.optionDescription(modelData)
                      color: Qt.darker(root.foreground, 1.5)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      width: parent.width
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: resultList.currentIndex = parent.index
                    onClicked: resultList.selectCurrent()
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
