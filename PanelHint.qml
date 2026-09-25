import QtQuick
import QtQuick.Window
import Quickshell
import qs.Ui as Ui
import qs.Commons
import "I18n.js" as I18n

// Draw hints without a Popup so wheel and click events reach rows beneath them.
Item {
  id: root
  required property var hostWidget
  property bool alwaysAvailable: false
  property bool requested: false
  property string text: ""
  property real maximumWidth: 400
  property bool belowAnchor: false
  property Item anchorItem: parent
  property bool shownThisHover: false
  property bool dwellElapsed: false
  property alias contentItem: label
  readonly property string statusText: hostWidget && !alwaysAvailable && hostWidget.hints.mode === "auto"
    ? I18n.format(hostWidget.words.hintsRemaining, {remaining: hostWidget.hints.remaining})
        + "\n" + hostWidget.words.hintsDisableExpanded : ""
  readonly property string displayText: I18n.hintText(text + (statusText ? "\n\n" + statusText : ""))
  readonly property Item windowRoot: parent && parent.Window.window ? parent.Window.window.contentItem : null
  readonly property var surface: parent ? parent.QsWindow.window : null
  readonly property Item overlayRoot: surface && surface.overlayScene ? surface.overlayScene : windowRoot
  readonly property point overlayOffset: surface && surface.overlayOffset ? surface.overlayOffset : Qt.point(0, 0)
  readonly property bool eligible: requested && parent && parent.visible && windowRoot
    && (alwaysAvailable || (!!hostWidget && (hostWidget.hints.enabled || (shownThisHover && hostWidget.hints.mode === "auto"))))

  visible: eligible && dwellElapsed
  onEligibleChanged: {
    dwellElapsed = false;
    if (eligible) dwell.restart(); else dwell.stop();
  }
  onRequestedChanged: if (!requested) shownThisHover = false
  Timer { id: dwell; interval: 400; onTriggered: root.dwellElapsed = root.eligible }

  // Observe the control, not the backing window's contentItem: Quickshell may
  // replace that window while opening the panel and destroy its direct handlers.
  // Keeping this handler on the control survives that transfer without adding
  // an overlay that would intercept the MouseAreas beneath it.
  HoverHandler { id: pointer; parent: root.parent; blocking: false; enabled: !root.belowAnchor }
  readonly property point pointerPosition: {
    var p = parent && windowRoot ? parent.mapToItem(windowRoot, pointer.point.position.x, pointer.point.position.y) : Qt.point(0, 0);
    return Qt.point(p.x + overlayOffset.x, p.y + overlayOffset.y);
  }
  // Watch the whole ancestor transform for scaled text and pointer clearance.
  TransformWatcher { id: anchorTransform; a: root.anchorItem; b: root.windowRoot }
  TransformWatcher { id: textTransform; a: root.parent; b: root.windowRoot }
  readonly property rect anchorRect: {
    anchorTransform.transform;
    var r = anchorItem && windowRoot ? anchorItem.mapToItem(windowRoot, 0, 0, anchorItem.width, anchorItem.height) : Qt.rect(0, 0, 0, 0);
    return Qt.rect(r.x + overlayOffset.x, r.y + overlayOffset.y, r.width, r.height);
  }
  readonly property real hintScale: {
    textTransform.transform;
    if (!parent || !windowRoot) return 1;
    var a = parent.mapToItem(windowRoot, 0, 0), b = parent.mapToItem(windowRoot, 1, 0);
    return Math.hypot(b.x - a.x, b.y - a.y) || 1;
  }
  readonly property var tipBorder: Border.localOrSurfaceSpec("tooltip", "border", Color.tooltip.border, Color.tooltip.border, Math.max(1, Style.normalBorderWidth))

  Ui.BorderSurface {
    id: bubble
    readonly property var hostWidget: root.hostWidget
    readonly property color readabilityBackground: Color.tooltip.background
    objectName: "panelHintSurface"
    parent: root.overlayRoot
    z: 1000002 // Above Qt Controls' overlay, without registering an input popup.
    visible: root.visible
    enabled: false
    scale: root.hintScale
    transformOrigin: Item.TopLeft
    readonly property real margin: Style.space(6) * scale
    width: Math.min(label.implicitWidth, root.maximumWidth, Math.max(1, ((parent ? parent.width : 400) - margin * 2) / scale))
    height: label.implicitHeight
    x: Math.max(margin, Math.min(root.belowAnchor
        ? root.anchorRect.x + (root.anchorRect.width - width * scale) / 2
        : root.pointerPosition.x + Style.space(12) * scale,
        (parent ? parent.width : 0) - margin - width * scale))
    y: {
      var desired;
      if (root.belowAnchor) {
        desired = root.anchorRect.y + root.anchorRect.height + Style.space(3) * scale;
      } else {
        var gap = Style.space(18) * scale;
        var below = root.pointerPosition.y + gap;
        desired = below + height * scale <= (parent ? parent.height : 0) - margin
          ? below : root.pointerPosition.y - gap - height * scale;
      }
      return Math.max(margin, Math.min(desired, (parent ? parent.height : 0) - margin - height * scale));
    }
    color: Color.tooltip.background
    borderSpec: root.tipBorder
    radius: 0
    Accessible.role: Accessible.ToolTip
    Accessible.name: root.displayText
    Accessible.ignored: !visible
    LayoutMirroring.enabled: root.parent ? root.parent.LayoutMirroring.enabled : false
    LayoutMirroring.childrenInherit: true
    onVisibleChanged: {
      if (visible && !root.shownThisHover) {
        root.shownThisHover = true;
        if (!root.alwaysAvailable && root.hostWidget) root.hostWidget.recordHintShown();
      }
    }
    ReadableText {
      id: label
      width: parent.width
      text: root.displayText
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      textColor: Color.tooltip.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      leftPadding: Border.left(root.tipBorder) + Style.spacing.controlPaddingX
      rightPadding: Border.right(root.tipBorder) + Style.spacing.controlPaddingX
      topPadding: Border.top(root.tipBorder) + Style.spacing.controlPaddingY
      bottomPadding: Border.bottom(root.tipBorder) + Style.spacing.controlPaddingY
    }
  }
}
