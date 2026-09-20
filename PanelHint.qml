import QtQuick
import QtQuick.Window
import Quickshell
import qs.Ui as Ui
import qs.Commons

// Draw hints without a Popup so wheel and click events reach rows beneath them.
Item {
  id: root
  required property var hostWidget
  property bool alwaysAvailable: false
  property bool requested: false
  property string text: ""
  property real maximumWidth: 400
  property bool shownThisHover: false
  property bool dwellElapsed: false
  property alias contentItem: label
  readonly property Item windowRoot: Window.window ? Window.window.contentItem : null
  readonly property bool eligible: requested && parent && parent.visible && windowRoot
    && (alwaysAvailable || (!!hostWidget && (hostWidget.hints.enabled || (shownThisHover && hostWidget.hints.mode === "auto"))))

  visible: eligible && dwellElapsed
  onEligibleChanged: {
    dwellElapsed = false;
    if (eligible) dwell.restart(); else dwell.stop();
  }
  onRequestedChanged: if (!requested) shownThisHover = false
  Timer { id: dwell; interval: 400; onTriggered: root.dwellElapsed = root.eligible }

  // Watch the whole ancestor transform, including scroll position and scaling.
  TransformWatcher { id: anchorTransform; a: root.parent; b: root.windowRoot }
  readonly property rect anchorRect: {
    anchorTransform.transform;
    return parent && windowRoot ? parent.mapToItem(windowRoot, 0, 0, parent.width, parent.height) : Qt.rect(0, 0, 0, 0);
  }
  readonly property real hintScale: {
    anchorTransform.transform;
    if (!parent || !windowRoot) return 1;
    var a = parent.mapToItem(windowRoot, 0, 0), b = parent.mapToItem(windowRoot, 1, 0);
    return Math.hypot(b.x - a.x, b.y - a.y) || 1;
  }
  readonly property var tipBorder: Border.localOrSurfaceSpec("tooltip", "border", Color.tooltip.border, Color.tooltip.border, Math.max(1, Style.normalBorderWidth))

  Ui.BorderSurface {
    id: bubble
    objectName: "panelHintSurface"
    parent: root.windowRoot
    z: 1000002 // Above Qt Controls' overlay, without registering an input popup.
    visible: root.visible
    enabled: false
    scale: root.hintScale
    transformOrigin: Item.TopLeft
    readonly property real margin: Style.space(6) * scale
    width: Math.min(label.implicitWidth, root.maximumWidth, Math.max(1, ((parent ? parent.width : 400) - margin * 2) / scale))
    height: label.implicitHeight
    x: Math.max(margin, Math.min(root.anchorRect.x + (root.anchorRect.width - width * scale) / 2,
        (parent ? parent.width : 0) - margin - width * scale))
    y: {
      var gap = Style.space(3) * scale;
      var above = root.anchorRect.y - gap - height * scale;
      var desired = above >= margin ? above : root.anchorRect.y + root.anchorRect.height + gap;
      return Math.max(margin, Math.min(desired, (parent ? parent.height : 0) - margin - height * scale));
    }
    color: Color.tooltip.background
    borderSpec: root.tipBorder
    radius: 0
    Accessible.role: Accessible.ToolTip
    Accessible.name: root.text
    Accessible.ignored: !visible
    LayoutMirroring.enabled: root.parent ? root.parent.LayoutMirroring.enabled : false
    LayoutMirroring.childrenInherit: true
    onVisibleChanged: {
      if (visible && !root.shownThisHover) {
        root.shownThisHover = true;
        if (!root.alwaysAvailable && root.hostWidget) root.hostWidget.recordHintShown();
      }
    }
    Text {
      id: label
      width: parent.width
      text: root.text
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      color: Color.tooltip.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      leftPadding: Border.left(root.tipBorder) + Style.spacing.controlPaddingX
      rightPadding: Border.right(root.tipBorder) + Style.spacing.controlPaddingX
      topPadding: Border.top(root.tipBorder) + Style.spacing.controlPaddingY
      bottomPadding: Border.bottom(root.tipBorder) + Style.spacing.controlPaddingY
    }
  }
}
