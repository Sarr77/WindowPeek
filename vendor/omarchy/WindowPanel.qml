// Adapted from Omarchy 4.0.4 Ui/KeyboardPanel.qml; MIT, see LICENSE.
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import qs.Ui as Ui
import qs.Commons
import "../.." as WindowPeek

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
  property bool shortcutKeyboard: false
  property bool retainSearchFocus: false
  property bool pointerPreviewVisible: false
  property bool pointerOnPreview: false
  property bool transientOpen: false
  readonly property bool interactive: open || transientOpen
  property bool keyboardSuppressed: false
  readonly property bool keyboardActive: (interactive || (hoverOpen && shortcutKeyboard)) && !keyboardSuppressed
  readonly property bool searchKeyboardActive: keyboardActive && ((shortcutKeyboard && retainSearchFocus)
    || (protectionRequested && !protectionStrict)) && backingWindowVisible
  readonly property bool nativeActive: contentHolder.Window.active
  property real cornerRadius: Style.space(8)
  property alias cardItem: card
  property bool pinOrigin: false
  property point retainedOrigin: Qt.point(0, 0)
  property bool open: false
  property int gap: Style.gapsOut  // distance between bar edge and panel
  property bool popoutSwitching: false
  property bool popoutSwitchClosing: false
  property bool focusPrimed: false
  property bool pointerReady: false
  property bool protectionRequested: false
  property bool protectionHold: false
  property bool protectionStrict: false
  readonly property bool protectionPaused: protector.yielded
  readonly property string protectionLastYieldReason: protector.lastYieldReason
  readonly property double protectionLastYieldAt: protector.lastYieldAt
  // Closing releases the focus hold immediately, but the fading card must
  // remain on the same surface. Reparenting it while opaque produces a flash.
  property bool nativeClosing: false
  function prepareClose() { nativeClosing = usingNative && card.opacity > 0 }
  onOpenChanged: if (open) nativeClosing = false
  onHoverOpenChanged: if (hoverOpen) nativeClosing = false
  readonly property bool nativePresented: protectionRequested || nativeClosing || usingNative || transferringSurface
  property bool usingNative: false
  property bool transferringSurface: false
  property int surfaceTransferSerial: 0
  property var surfaceSnapshot: null
  property bool snapshotOnNative: false
  property bool awaitingSurfaceFrame: false
  readonly property bool wantsNative: (protectionRequested || nativeClosing) && protector.ready && native.backingWindowVisible
  onWantsNativeChanged: Qt.callLater(transferSurface)
  function transferSurface() {
    if (!layerScene || transferringSurface || wantsNative === usingNative) return
    var destination = wantsNative
    // Closing already faded to zero; unavailable backends cannot provide a frame.
    if (card.opacity <= 0 || (usingNative && !native.backingWindowVisible)) {
      moveSurface(destination)
      return
    }
    transferringSurface = true
    var serial = ++surfaceTransferSerial
    surfaceDeadline.restart()
    snapshotOnNative = usingNative
    if (!card.grabToImage(function(result) {
      if (serial !== root.surfaceTransferSerial) return
      if (root.wantsNative !== destination || !root.visible) {
        root.finishSurfaceTransfer()
        return
      }
      root.surfaceSnapshot = result
      root.moveSurface(destination)
      root.awaitingSurfaceFrame = true
      card.Window.window.update()
    })) {
      moveSurface(destination)
      finishSurfaceTransfer()
    }
  }
  function moveSurface(toNative) {
    usingNative = toNative
    card.parent = toNative ? native.contentItem : layerScene
    if (!toNative && keyboardActive) { focusPrimed = false; beginFocusPrime() }
    focusContent()
  }
  function finishSurfaceTransfer() {
    surfaceDeadline.stop()
    surfaceTransferSerial++
    awaitingSurfaceFrame = false
    surfaceSnapshot = null
    transferringSurface = false
    Qt.callLater(transferSurface)
  }
  Timer {
    id: surfaceDeadline
    interval: 500
    onTriggered: { root.moveSurface(root.wantsNative); root.finishSurfaceTransfer() }
  }
  Connections {
    target: card.Window.window
    function onFrameSwapped() {
      if (root.awaitingSurfaceFrame) Qt.callLater(root.finishSurfaceTransfer)
    }
  }
  Image {
    parent: root.layerScene
    x: root.cardOrigin.x; y: root.cardOrigin.y
    width: root.contentWidth; height: root.contentHeight
    visible: root.surfaceSnapshot !== null && !root.snapshotOnNative
    source: visible ? root.surfaceSnapshot.url : ""
    z: 1000008
  }
  Image {
    parent: native.contentItem
    x: root.cardOrigin.x; y: root.cardOrigin.y
    width: root.contentWidth; height: root.contentHeight
    visible: root.surfaceSnapshot !== null && root.snapshotOnNative
    source: visible ? root.surfaceSnapshot.url : ""
    z: 1000008
  }
  readonly property var contentWindow: usingNative ? native : root
  readonly property bool contentMapped: backingWindowVisible || native.backingWindowVisible
  property Item layerScene: null
  readonly property Item panelScene: usingNative ? native.contentItem : layerScene
  readonly property point nativeSurfaceOrigin: Qt.point(screen ? screen.x : 0, screen ? screen.y : 0)
  readonly property point nativeGlobalOrigin: Qt.point((screen ? screen.x : 0) + cardOrigin.x,
    (screen ? screen.y : 0) + cardOrigin.y)
  onPointerOnPreviewChanged: if (pointerOnPreview && protectionRequested) Qt.callLater(protector.refreshPointer)
  signal protectionFailed(string reason)
  function hitCard(x, y) {
    var origin = usingNative ? nativeGlobalOrigin : card.mapToGlobal(0, 0)
    return x >= origin.x && y >= origin.y && x < origin.x + card.width && y < origin.y + card.height
  }
  Component.onCompleted: layerScene = card.parent
  readonly property bool primeInput: interactive && keyboardActive && !pointerReady
  property bool animationsEnabled: true
  property bool glassEnabled: false
  property color panelColor: Color.popups.background
  property real glassOpacity: 0.92
  property Component backgroundComponent: null
  readonly property bool backgroundReady: !backgroundComponent
    || (!!backgroundLoader.item && backgroundLoader.item.readyToShow)
  // Gate only the start of an opening. A later wallpaper refresh must not hide
  // a panel that is already in use, or interrupt its closing animation.
  property bool backgroundPresented: false
  function latchBackground() { if (visible && backgroundReady) backgroundPresented = true }
  onBackgroundReadyChanged: Qt.callLater(latchBackground)
  onVisibleChanged: {
    if (!visible) backgroundPresented = false
    else Qt.callLater(latchBackground)
  }
  signal backgroundClicked()
  signal backRequested()
  signal transientCloseRequested()
  signal barPressed(int button)
  signal barDoubleClicked()
  readonly property bool barAnchorHovered: barInput.containsMouse && barInput.visible

  property Item popupInputItem: null
  readonly property rect popupScreenRect: {
    popupTransform.transform
    return popupInputItem && panelScene ? popupInputItem.mapToItem(panelScene, 0, 0, popupInputItem.width, popupInputItem.height) : Qt.rect(0, 0, 0, 0)
  }
  TransformWatcher { id: popupTransform; a: root.panelScene; b: root.popupInputItem }
  property Item previewInputItem: null
  property Item previewBlurItem: null
  property real previewBlurRadius: 0
  property Item focusTarget: null
  property bool doubleClickExpand: false
  readonly property bool backgroundHovered: backgroundPointer.containsMouse

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
  function restoreFocusAfterPress() {
    if (!keyboardActive || protectionRequested || nativeActive) return
    // Qt can focus a local TextField while an OnDemand layer remains inactive.
    // A deliberate press may prime the layer once; native focus loss itself
    // must never trigger acquisition or a retry loop.
    focusPrimed = false
    pointerReady = false
    pointerReadyTimer.stop()
    beginFocusPrime()
    focusContent()
  }
  function focusContent() {
    if (keyboardActive && focusTarget) Qt.callLater(function() {
      if (root.keyboardActive && root.focusTarget) root.focusTarget.forceActiveFocus()
    })
  }
  onFocusTargetChanged: focusContent()


  screen: anchorWindow ? anchorWindow.screen : null
  visible: open || hoverOpen || card.opacity > 0 || popoutSwitching
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  // Limit the compositor effect to the card, excluding dismissal and handoff areas.
  BackgroundEffect.blurRegion: glassEnabled && !nativePresented && (card.opacity > 0 || previewInputItem) ? glassRegion : null
  Region {
    id: glassRegion; item: root.nativePresented ? null : card; radius: card.radius
    Region { item: root.previewBlurItem; radius: root.previewBlurRadius }
  }

  // Keep Omarchy's layer role: its compositor rule disables a second animation.
  WlrLayershell.namespace: "omarchy-keyboard-panel"
  WlrLayershell.layer: WlrLayer.Overlay
  // Prime keyboard focus, then free pointer input. SearchFocus keeps typing
  // focused without an exclusive layer's implicit pointer capture.
  WlrLayershell.keyboardFocus: keyboardActive && !protectionRequested
    ? (pointerOnPreview || focusPrimed
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
    : WlrKeyboardFocus.None
  WindowPeek.SearchFocus {
    // Prime acquisition, then hold only while this surface owns the keyboard.
    // Leaving click-to-focus leased after a real loss also delays focus changes
    // between unrelated application windows until another forced refocus.
    active: root.searchKeyboardActive && (!root.pointerReady || root.nativeActive)
    pointerReady: root.pointerReady && root.keyboardActive
  }
  WindowPeek.NativeProtection {
    id: protector
    strict: root.protectionStrict
    requested: (root.protectionRequested && root.visible) || native.backingWindowVisible
    hold: root.protectionRequested && root.keyboardActive && root.protectionHold && !root.keyboardSuppressed && !root.pointerOnPreview
    monitor: root.screen ? root.screen.name : ""
    origin: Qt.point(0, 0)
    globalOrigin: root.nativeSurfaceOrigin
    panelRect: Qt.rect(root.nativeGlobalOrigin.x, root.nativeGlobalOrigin.y, root.contentWidth, root.contentHeight)
    previewRect: root.previewInputItem ? Qt.rect(root.nativeSurfaceOrigin.x + root.previewInputItem.x,
      root.nativeSurfaceOrigin.y + root.previewInputItem.y, root.previewInputItem.width, root.previewInputItem.height) : Qt.rect(0, 0, 0, 0)
    popupRect: Qt.rect(root.nativeSurfaceOrigin.x + root.popupScreenRect.x, root.nativeSurfaceOrigin.y + root.popupScreenRect.y,
      root.popupScreenRect.width, root.popupScreenRect.height)
    anchorRect: Qt.rect((root.screen ? root.screen.x : 0) + barInput.x,
      (root.screen ? root.screen.y : 0) + barInput.y, root.anchorW, root.anchorH)
    onBarPressed: function(button) { root.barPressed(button) }
    panelSize: Qt.size(root.screenW, root.screenH)
    onFailed: function(reason) { root.protectionFailed(reason) }
  }
  FloatingWindow {
    id: native
    visible: root.visible && root.nativePresented && protector.ready
    screen: root.screen
    title: protector.title
    color: "transparent"
    // Keep one stable viewport for the card AND preview. Animate their items,
    // never the native buffer size: XDG configure/commit handshakes otherwise
    // stretch frames and serialize the two windows during every resize.
    implicitWidth: root.screenW
    implicitHeight: root.screenH
    mask: Region {
      item: root.usingNative ? card : null
      Region { item: root.usingNative ? root.previewInputItem : null }
      Region { item: root.usingNative ? root.popupInputItem : null }
    }
    property var overlayWindow: root
    property Item overlayScene: root.layerScene
    property point overlayOffset: Qt.point(0, 0)
    BackgroundEffect.blurRegion: root.glassEnabled && visible ? nativeGlass : null
    Region {
      id: nativeGlass; item: card; radius: card.radius
      Region { item: root.previewBlurItem; radius: root.previewBlurRadius }
    }
    onClosed: root.close()
  }

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
  readonly property rect hoverHandoffBounds: hoverFootprint.bounds
  readonly property bool hoverHandoffActive: hoverFootprint.active
  readonly property Item hoverHandoffItem: hoverFootprint
  function retainHoverFootprint() { hoverFootprint.retain() }
  function releaseHoverFootprint() { hoverFootprint.release() }
  WindowPeek.HoverFootprint {
    id: hoverFootprint; objectName: "windowPeekHoverFootprint"
    card: root.cardItem
    onClicked: root.backgroundClicked()
  }
  readonly property rect hoverInputBounds: {
    var x = card.x, y = card.y, right = x + card.width, bottom = y + card.height
    var regions = []
    if (barBridge.enabled) regions.push(root.barBridgeBounds)
    if (hoverHandoffActive) regions.push(root.hoverHandoffBounds)
    for (var r of regions) {
      x = Math.min(x, r.x); y = Math.min(y, r.y)
      right = Math.max(right, r.x + r.width); bottom = Math.max(bottom, r.y + r.height)
    }
    return Qt.rect(x, y, right - x, bottom - y)
  }
  // Restrict pointer input to visible UI; wheel events outside go directly to
  // the underlying application. The owner observes outside button presses.
  mask: root.nativePresented ? emptyMask : normalMask
  Region {
    id: normalMask
    x: root.primeInput ? 0 : Math.floor(root.hoverInputBounds.x)
    y: root.primeInput ? 0 : Math.floor(root.hoverInputBounds.y)
    width: root.primeInput ? root.screenW : Math.ceil(root.hoverInputBounds.x + root.hoverInputBounds.width) - x
    height: root.primeInput ? root.screenH : Math.ceil(root.hoverInputBounds.y + root.hoverInputBounds.height) - y
    Region { item: barInput }
    Region { item: root.popupInputItem }
    Region { item: root.previewInputItem }
  }
  Region { id: emptyMask; width: 0; height: 0; Region { item: root.usingNative ? null : root.previewInputItem } }
  // During keyboard priming Hyprland routes pointer events to this layer even
  // over its bar anchor. Keep that one label interactive on the same surface,
  // including clicks that straddle mapping or a native double-click sequence.
  MouseArea {
    id: barInput
    x: (root.barPos === "right" ? root.screenW - root.barW : 0) + root.anchorScreenPos.x
    y: (root.barPos === "bottom" ? root.screenH - root.barH : 0) + root.anchorScreenPos.y
    width: visible ? root.anchorW : 0; height: visible ? root.anchorH : 0
    visible: root.open || root.hoverOpen
    enabled: visible; hoverEnabled: true; acceptedButtons: Qt.AllButtons
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) { root.barPressed(mouse.button) }
    onDoubleClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) { mouse.accepted = true; root.barDoubleClicked() }
    }
    onWheel: function(wheel) { wheel.accepted = false }
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
      pointerReady = false
      pointerReadyTimer.stop()
      beginFocusPrime()
      focusContent()
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
    onTriggered: if (root.keyboardActive) { root.focusPrimed = true; pointerReadyTimer.restart() }
  }

  Timer { id: pointerReadyTimer; interval: 35; onTriggered: root.pointerReady = true }

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

  Ui.BorderSurface {
    id: card
    x: root.cardOrigin.x
    y: root.cardOrigin.y
    width: root.contentWidth
    height: root.contentHeight
    color: root.glassEnabled ? Qt.alpha(root.panelColor, root.glassOpacity) : root.panelColor
    borderSpec: root.borderSpec
    padding: root.padding
    radius: root.cornerRadius
    Loader {
      id: backgroundLoader
      anchors.fill: parent; anchors.margins: 1
      active: root.visible && root.backgroundComponent !== null
      sourceComponent: root.backgroundComponent
    }
    opacity: cardMotion.value
    onOpacityChanged: if (opacity <= 0) root.nativeClosing = false
    PopupMotion {
      id: cardMotion
      targetValue: (root.open || root.hoverOpen || root.popoutSwitching)
        && (root.backgroundPresented || root.backgroundReady) ? 1 : 0
      animated: root.animationsEnabled && !root.popoutSwitching && !root.popoutSwitchClosing
    }

    // Observe presses before child controls accept them, without taking their
    // grab or interfering with text selection, buttons, scrolling or touch.
    Item {
      anchors.fill: parent
      z: 1000005
      enabled: root.keyboardActive && !root.protectionRequested
      PointHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onActiveChanged: if (active) root.restoreFocusAfterPress()
      }
    }

    MouseArea {
      id: backgroundPointer
      objectName: "windowPanelBackground"
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.AllButtons
      onClicked: function(mouse) {
        if ((mouse.button === Qt.MiddleButton || (mouse.button === Qt.LeftButton && !root.doubleClickExpand)) && mouse.modifiers === Qt.NoModifier) root.backgroundClicked()
        else if (mouse.button === Qt.RightButton) root.backRequested()
      }
      onDoubleClicked: function(mouse) {
        if (root.doubleClickExpand && mouse.button === Qt.LeftButton && mouse.modifiers === Qt.NoModifier) root.backgroundClicked()
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
