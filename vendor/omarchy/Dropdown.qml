// Adapted from Omarchy 4.0.4 shell/Ui/Dropdown.qml (MIT). See LICENSE here.
// ScratchPeek: keep scaled popup menus inside their window.
import QtQuick
import QtQuick.Window
import "../../PopupPlacement.js" as Placement
import "../.." as WindowPeek
import qs.Ui
import QtQuick.Controls
import qs.Commons

// Themed single-select dropdown. Trigger row paints with the kit's focus
// chrome; the popup uses the popup background and the widget's accent border.
//
// `options` accepts either a plain string[] or an array of
// { value, label } objects (label is what we render; value is what we
// emit). Mixing is fine — each row is interpreted independently.
//
// Keyboard: Tab to focus the trigger, Enter/Space opens, Esc closes,
// j/k or Up/Down walks options inside the open popup, Enter selects.
// A sibling SearchableDropdown reuses the same visuals but adds an
// embedded filter input — keep the two separate so each stays simple.
Item {
  id: root

  property real uiScale: 1
  property var placement: ({x:0, y:0, width:0, height:0})
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

  property color foreground: Color.popups.text
  property var hostWidget: null
  property var palette: hostWidget ? hostWidget.surfaces : null
  property color background: palette ? palette.pickerBackground : Color.popups.background
  property color accent: Color.accent
  property color popupBorder: accent
  readonly property var popupBorderSpec: Border.localOrSurfaceSpec("popups", "border", popupBorder, Color.popups.border, Style.normalBorderWidth)
  property string fontFamily: Style.font.family
  property real labelFontSize: Style.font.caption
  property int rowHeight: Style.spacing.controlHeight
  property int popupRowHeight: Style.spacing.popupRowHeight
  property bool showLabel: true

  // Panel-cursor flag. When true, the trigger renders the shared
  // hover-cursor state. Active Qt focus defaults to the same visuals.
  // Emits `hovered(bool)` on pointer enter/leave so the panel can keep
  // its cursor state in sync with the mouse.
  property bool hasCursor: false

  // popupOpen + open()/close()/toggle() let a parent panel know when the
  // dropdown owns keys (its embedded ListView is active) and suspend its
  // own keyCatcher so j/k inside the popup don't double-drive the panel
  // cursor.
  readonly property bool popupOpen: popup.opened
  function open() { popup.open() }
  function close() { popup.close() }
  function toggle() { popup.visible ? popup.close() : popup.open() }

  signal changed(string value)
  signal hovered(bool isHovered)

  function optionValue(o) {
    return (o && typeof o === "object") ? String(o.value) : String(o)
  }
  function optionLabel(o) {
    return (o && typeof o === "object") ? String(o.label) : String(o)
  }
  function currentLabel() {
    for (var i = 0; i < options.length; i++) {
      if (optionValue(options[i]) === value) return optionLabel(options[i])
    }
    return value
  }

  implicitWidth: Style.spacing.dropdownWidth
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
          popup.close(); event.accepted = true
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.right: chevron.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: trigger.borderLeft + Style.spacing.controlPaddingX
        anchors.rightMargin: trigger.borderRight + Style.spacing.md
        text: root.currentLabel()
        color: root.foreground
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
        onClicked: {
          trigger.forceActiveFocus()
          root.toggle()
        }
      }

      Popup {
        id: popup
        // Let the trigger own the whole click, including a click that closes us.
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        WindowPeek.BackMouseArea {
          objectName: "popupBackPointer"
          parent: popup.contentItem
          onClicked: { popup.close(); trigger.forceActiveFocus(); }
        }
        // Placement.fit already handles transformed window bounds.
        margins: -1
        x: root.placement.x
        y: root.placement.y
        width: root.placement.width
        height: root.placement.height
        onAboutToShow: root.updatePlacement()
        onImplicitHeightChanged: if (visible) Qt.callLater(root.updatePlacement)
        implicitHeight: Math.min(root.options.length * root.popupRowHeight + Math.max(0, root.options.length - 1) * Style.spacing.labelGap,
                                 root.popupRowHeight * 8 + 7 * Style.spacing.labelGap)
                        + topPadding + bottomPadding
        padding: Style.spacing.hairline
        leftPadding: Border.left(root.popupBorderSpec) + Style.spacing.hairline
        rightPadding: Border.right(root.popupBorderSpec) + Style.spacing.hairline
        topPadding: Border.top(root.popupBorderSpec) + Style.spacing.hairline
        bottomPadding: Border.bottom(root.popupBorderSpec) + Style.spacing.hairline
        focus: true

        background: WindowPeek.DropdownSurface {
          hostWidget: root.hostWidget; uiScale: root.uiScale
          fallbackBackground: root.background
          borderSpec: root.popupBorderSpec
          radius: Style.cornerRadius
        }

        onOpened: {
          optionList.currentIndex = Math.max(0, optionList.indexOfValue(root.value))
          optionList.forceActiveFocus()
        }

        contentItem: ListView {
          id: optionList; objectName: "optionList"
          spacing: Style.spacing.labelGap

          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { popup.close(); event.accepted = true }
            else if (event.key === Qt.Key_Down || event.text === "j") {
              optionList.currentIndex = Math.min(root.options.length - 1, optionList.currentIndex + 1)
              event.accepted = true
            } else if (event.key === Qt.Key_Up || event.text === "k") {
              optionList.currentIndex = Math.max(0, optionList.currentIndex - 1)
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              optionList.selectCurrent(); event.accepted = true
            }
          }
          implicitHeight: contentHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          model: root.options
          currentIndex: -1

          function indexOfValue(v) {
            for (var i = 0; i < root.options.length; i++)
              if (root.optionValue(root.options[i]) === v) return i
            return -1
          }

          function selectCurrent() {
            if (currentIndex < 0 || currentIndex >= root.options.length) return
            var v = root.optionValue(root.options[currentIndex])
            root.value = v
            root.changed(v)
            popup.close()
          }

          delegate: Rectangle {
            required property var modelData
            required property int index
            width: optionList.width
            height: root.popupRowHeight
            color: index === optionList.currentIndex
              ? Style.hoverFillFor(root.foreground, root.accent)
              : "transparent"

            Text {
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.spacing.controlPaddingX
              anchors.rightMargin: Style.spacing.controlPaddingX
              text: root.optionLabel(modelData)
              color: index === optionList.currentIndex ? Style.hoverStateColor(root.foreground, root.accent) : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onPositionChanged: optionList.currentIndex = parent.index
              onClicked: optionList.selectCurrent()
            }
          }
        }
      }
    }
  }
}
