// Adapted from Omarchy 4.0.4 Ui/KeyboardPanel.qml; MIT, see LICENSE.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Ui as Ui
import qs.Commons

PanelWindow {
  id: root

  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  property int margin: Style.gapsOut
  property int padding: Style.spacing.popupPadding
  property int contentWidth: Style.space(280)
  property int contentHeight: Style.space(200)
  property var borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
  property bool centerOnBar: false
  property bool hoverOpen: false
  property bool transientOpen: false
  readonly property bool interactive: open || transientOpen
  property bool keyboardSuppressed: false
  readonly property bool keyboardActive: interactive && !keyboardSuppressed
  property real cornerRadius: Style.space(8)
  property alias cardItem: card
  property bool pinOrigin: false
  property point retainedOrigin: Qt.point(0, 0)
  property bool open: false
  property int gap: Style.gapsOut  // distance between bar edge and panel
  property bool popoutSwitching: false
  property bool popoutSwitchClosing: false
  property bool focusPrimed: false
  property bool animationsEnabled: true
  signal backgroundClicked()
  signal backRequested()
  signal transientCloseRequested()

  property Item focusTarget: null

  default property alias contentItem: contentHolder.children

  readonly property var coordinatorKey: owner || root
  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  readonly property string barPos: bar ? bar.position : "top"

  function close() {
    if (transientOpen) { transientCloseRequested(); return }
    if (owner && "close" in owner) owner.close()
    else root.open = false
  }

  function beginFocusPrime() {
    if (keyboardActive && backingWindowVisible) focusPrimeTimer.restart()
  }

  screen: anchorWindow ? anchorWindow.screen : null
  visible: open || hoverOpen || card.opacity > 0 || popoutSwitching
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore

  // Keep Omarchy's layer role: its compositor rule disables a second animation.
  WlrLayershell.namespace: "omarchy-keyboard-panel"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: keyboardActive
    ? (focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
    : WlrKeyboardFocus.None

  onBackingWindowVisibleChanged: beginFocusPrime()

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  readonly property real _barStripSize: {
    if (!bar) return 0
    var actual = (root.barPos === "top" || root.barPos === "bottom") ? root.barH : root.barW
    return Math.max(bar.barSize, actual) + root.gap
  }
  // The gap belongs to this surface, but the bar itself remains clickable.
  // Cover the full adjoining card edge, including diagonal pointer crossings.
  readonly property rect barBridgeBounds: {
    if (!anchorWindow || !anchorItem || !bar) return Qt.rect(0, 0, 0, 0)
    if (barPos === "bottom")
      return Qt.rect(card.x, card.y + card.height, card.width,
        Math.max(0, screenH - barH - card.y - card.height))
    if (barPos === "left")
      return Qt.rect(barW, card.y, Math.max(0, card.x - barW), card.height)
    if (barPos === "right")
      return Qt.rect(card.x + card.width, card.y,
        Math.max(0, screenW - barW - card.x - card.width), card.height)
    return Qt.rect(card.x, barH, card.width, Math.max(0, card.y - barH))
  }
  readonly property bool barBridgeHovered: barBridge.containsMouse
  readonly property rect hoverInputBounds: {
    if (!barBridge.enabled) return Qt.rect(card.x, card.y, card.width, card.height)
    var x = Math.min(card.x, barBridge.x), y = Math.min(card.y, barBridge.y)
    return Qt.rect(x, y, Math.max(card.x + card.width, barBridge.x + barBridge.width) - x,
      Math.max(card.y + card.height, barBridge.y + barBridge.height) - y)
  }
  mask: Region {
    x: root.interactive ? 0 : Math.floor(root.hoverInputBounds.x)
    y: root.interactive ? 0 : Math.floor(root.hoverInputBounds.y)
    width: root.interactive ? root.screenW : Math.ceil(root.hoverInputBounds.x + root.hoverInputBounds.width) - x
    height: root.interactive ? root.screenH : Math.ceil(root.hoverInputBounds.y + root.hoverInputBounds.height) - y
  }
  MouseArea {
    id: barBridge
    objectName: "windowPeekBarBridge"
    x: root.barBridgeBounds.x; y: root.barBridgeBounds.y
    width: root.barBridgeBounds.width; height: root.barBridgeBounds.height
    enabled: root.hoverOpen && !root.open && width > 0 && height > 0
    visible: enabled
    hoverEnabled: true
    acceptedButtons: Qt.AllButtons
    // Intentionally no click action: crossing or clicking the gap only retains hover.
  }

  TransformWatcher {
    id: anchorWatcher
    a: anchorWindow ? anchorWindow.contentItem : null
    b: anchorItem
  }

  readonly property point anchorScreenPos: {
    anchorWatcher.transform  // reactive dependency
    if (!anchorItem || !anchorWindow) return Qt.point(0, 0)
    return anchorItem.mapToItem(anchorWindow.contentItem, 0, 0)
  }
  readonly property real anchorW: anchorItem ? anchorItem.width : 0
  readonly property real anchorH: anchorItem ? anchorItem.height : 0
  readonly property real screenW: screen ? screen.width : 0
  readonly property real screenH: screen ? screen.height : 0
  readonly property real availableCardWidth: screenW > 0
    ? Math.max(120, screenW - ((barPos === "left" || barPos === "right") ? barW + gap + margin : margin * 2))
    : 0
  readonly property real availableCardHeight: screenH > 0
    ? Math.max(120, screenH - ((barPos === "top" || barPos === "bottom") ? barH + gap + margin : margin * 2))
    : 0
  readonly property real verticalContentInset: padding * 2 + Border.top(borderSpec) + Border.bottom(borderSpec)

  function fittedContentWidth(width, cap) {
    var desired = Math.max(1, Number(width) || 1)
    var maxWidth = root.availableCardWidth > 0 ? root.availableCardWidth : desired
    if (cap !== undefined && Number(cap) > 0) maxWidth = Math.min(maxWidth, Number(cap))
    return Math.round(Math.min(desired, maxWidth))
  }

  function fittedContentHeight(implicitHeight, cap) {
    var desired = Math.max(root.verticalContentInset, (Number(implicitHeight) || 0) + root.verticalContentInset)
    var maxHeight = root.availableCardHeight > 0 ? root.availableCardHeight : desired
    if (cap !== undefined && Number(cap) > 0) maxHeight = Math.min(maxHeight, Number(cap))
    return Math.round(Math.min(desired, maxHeight))
  }

  function cappedContentHeight(height) {
    var desired = Math.max(root.padding * 2, Number(height) || root.padding * 2)
    var maxHeight = root.availableCardHeight > 0 ? root.availableCardHeight : desired
    return Math.round(Math.min(desired, maxHeight))
  }

  readonly property real barW: anchorWindow ? anchorWindow.width : screenW
  readonly property real barH: anchorWindow ? anchorWindow.height : 0
  readonly property point cardOrigin: {
    if (!anchorItem || !bar) return Qt.point(margin, margin)
    var x = 0, y = 0
    if (centerOnBar && (barPos === "top" || barPos === "bottom")) {
      x = screenW / 2 - contentWidth / 2
      y = barPos === "bottom" ? screenH - barH - contentHeight - gap : barH + gap
    } else if (centerOnBar) {
      x = barPos === "left" ? barW + gap : screenW - barW - contentWidth - gap
      y = screenH / 2 - contentHeight / 2
    } else if (barPos === "bottom") {
      x = anchorScreenPos.x + anchorW / 2 - contentWidth / 2
      y = screenH - barH - contentHeight - gap
    } else if (barPos === "left") {
      x = barW + gap
      y = anchorScreenPos.y + anchorH / 2 - contentHeight / 2
    } else if (barPos === "right") {
      x = screenW - barW - contentWidth - gap
      y = anchorScreenPos.y + anchorH / 2 - contentHeight / 2
    } else { // "top" (default)
      x = anchorScreenPos.x + anchorW / 2 - contentWidth / 2
      y = barH + gap
    }
    if (pinOrigin) {
      x = retainedOrigin.x
      y = retainedOrigin.y
    }
    var minX = barPos === "left" ? barW + gap : margin
    var minY = barPos === "top" ? barH + gap : margin
    var maxX = screenW - contentWidth - (barPos === "right" ? barW + gap : margin)
    var maxY = screenH - contentHeight - (barPos === "bottom" ? barH + gap : margin)
    x = Math.max(minX, Math.min(x, maxX))
    y = Math.max(minY, Math.min(y, maxY))
    return Qt.point(Math.round(x), Math.round(y))
  }

  onKeyboardActiveChanged: {
    if (keyboardActive) {
      focusPrimed = false
      beginFocusPrime()
      if (focusTarget) Qt.callLater(function() {
        if (root.keyboardActive && root.focusTarget) root.focusTarget.forceActiveFocus()
      })
    } else {
      focusPrimeTimer.stop()
      focusPrimed = false
    }
  }

  onInteractiveChanged: {
    if (!bar) return
    if (interactive) {
      popoutSwitchClosing = false
      popoutSwitching = bar.activePopout && bar.activePopout !== coordinatorKey
      bar.requestPopout(coordinatorKey)
      if (popoutSwitching) popoutSwitchTimer.restart()
    } else {
      popoutSwitchClosing = !!(owner && owner.popoutSwitchClosing)
      popoutSwitching = false
      if (bar.activePopout === coordinatorKey) bar.releasePopout(coordinatorKey)
      if (popoutSwitchClosing) closeSwitchTimer.restart()
    }
  }

  Timer {
    id: focusPrimeTimer
    interval: 75
    onTriggered: if (root.keyboardActive) root.focusPrimed = true
  }

  Timer {
    id: popoutSwitchTimer
    interval: 150
    onTriggered: root.popoutSwitching = false
  }

  Timer {
    id: closeSwitchTimer
    interval: 1
    onTriggered: root.popoutSwitchClosing = false
  }

  MouseArea {
    id: dismissArea
    anchors.fill: parent
    enabled: root.interactive
    acceptedButtons: Qt.AllButtons
    hoverEnabled: true
    property bool hoveringBar: false
    cursorShape: hoveringBar ? Qt.PointingHandCursor : Qt.ArrowCursor

    function inBarRegion(px, py) {
      if (root.barPos === "bottom") return py >= root.screenH - root._barStripSize
      if (root.barPos === "left") return px <= root._barStripSize
      if (root.barPos === "right") return px >= root.screenW - root._barStripSize
      return py <= root._barStripSize
    }

    function barPoint(px, py) {
      if (root.barPos === "bottom") return Qt.point(px, py - (root.screenH - root.barH))
      if (root.barPos === "right") return Qt.point(px - (root.screenW - root.barW), py)
      return Qt.point(px, py)
    }

    function pressTargetAt(px, py) {
      if (!root.anchorWindow || !root.anchorWindow.contentItem || !root.bar || !root.bar.clickTargets) return null
      var p = barPoint(px, py)
      var targets = root.bar.clickTargets
      for (var i = targets.length - 1; i >= 0; i--) {
        var target = targets[i]
        if (!target || !target.triggerPress || target.visible === false || target.opacity === 0 || !target.mapToItem) continue
        if (root.bar.targetBelongsToWindow && !root.bar.targetBelongsToWindow(target, root.anchorWindow)) continue
        var pos = root.anchorWindow.itemPosition(target)
        if (p.x >= pos.x && p.x <= pos.x + target.width && p.y >= pos.y && p.y <= pos.y + target.height) return target
      }
      return null
    }

    function forwardBarClick(px, py, button) {
      if (button !== Qt.LeftButton && button !== Qt.RightButton && button !== Qt.MiddleButton) return false
      var target = pressTargetAt(px, py)
      if (!target) return false
      target.triggerPress(button)
      return true
    }

    onPositionChanged: function(mouse) { hoveringBar = inBarRegion(mouse.x, mouse.y) }
    onExited: hoveringBar = false
    onClicked: function(mouse) {
      if (root.focusPrimed && inBarRegion(mouse.x, mouse.y) && forwardBarClick(mouse.x, mouse.y, mouse.button)) return
      root.close()
    }
  }

  Variants {
    model: root.interactive ? Quickshell.screens : []

    delegate: Component {
      PanelWindow {
        required property var modelData

        screen: modelData
        visible: root.interactive && !!root.screen && modelData.name !== root.screen.name
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "omarchy-keyboard-panel-dismiss"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
          top: true
          bottom: true
          left: true
          right: true
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.AllButtons
          onPressed: root.close()
        }
      }
    }
  }

  Ui.BorderSurface {
    id: card
    x: root.cardOrigin.x
    y: root.cardOrigin.y
    width: root.contentWidth
    height: root.contentHeight
    color: Color.popups.background
    borderSpec: root.borderSpec
    padding: root.padding
    radius: root.cornerRadius
    opacity: cardMotion.value
    PopupMotion {
      id: cardMotion
      targetValue: root.open || root.hoverOpen || root.popoutSwitching ? 1 : 0
      animated: root.animationsEnabled && !root.popoutSwitching && !root.popoutSwitchClosing
    }

    MouseArea {
      objectName: "windowPanelBackground"
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton && mouse.modifiers === Qt.NoModifier) root.backgroundClicked()
        else if (mouse.button === Qt.RightButton) root.backRequested()
      }
    }

    Item {
      id: contentHolder
      anchors.fill: parent
      anchors.topMargin: card.contentTopInset
      anchors.rightMargin: card.contentRightInset
      anchors.bottomMargin: card.contentBottomInset
      anchors.leftMargin: card.contentLeftInset
      opacity: contentMotion.value
      PopupMotion {
        id: contentMotion
        targetValue: root.popoutSwitching ? (root.open ? 1 : 0) : 1
        animated: root.animationsEnabled && root.popoutSwitching
      }
    }
  }
}
