import QtQuick
import QtQuick.Controls as QQC
import qs.Ui as Ui
import qs.Commons

// Mouse activation and keyboard focus have separate visual states.
QQC.AbstractButton {
    id: root
    property color accent: Color.accent
    property color foreground: Color.popups.text
    property real fontSize: Style.font.body
    property bool textOnly: false
    property bool emphasized: false
    property bool pointerFocus: false
    readonly property bool keyboardFocusVisible: visualFocus && !pointerFocus
    readonly property bool hot: hovered || keyboardFocusVisible
    readonly property int activationFocusReason: keyboardFocusVisible ? Qt.TabFocusReason : Qt.MouseFocusReason
    onActiveFocusChanged: if (!activeFocus) pointerFocus = false
    onVisualFocusChanged: if (visualFocus) pointerFocus = false
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    leftPadding: textOnly ? 0 : Style.spacing.controlPaddingX
    rightPadding: leftPadding
    topPadding: Style.space(3)
    bottomPadding: topPadding
    implicitWidth: label.implicitWidth + leftPadding + rightPadding + (textOnly ? 0 : 2)
    implicitHeight: Math.max(Style.space(textOnly ? 24 : 30), label.implicitHeight + topPadding + bottomPadding)
    Accessible.name: text
    Keys.onPressed: function(event) { pointerFocus = false; event.accepted = false; }
    Keys.onReturnPressed: function(event) { pointerFocus = false; if (!event.isAutoRepeat) clicked(); }
    Keys.onEnterPressed: function(event) { pointerFocus = false; if (!event.isAutoRepeat) clicked(); }
    background: Ui.BorderSurface {
        color: root.textOnly ? "transparent"
            : root.down ? Style.pressedFillFor(root.foreground, root.accent)
            : root.keyboardFocusVisible ? Style.focusFillFor(root.foreground, root.accent)
            : root.hovered ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"
        borderSpec: root.textOnly ? Border.none()
            : Border.controlSpec(root.keyboardFocusVisible ? "focus" : root.hovered ? "hover-cursor" : "normal", root.foreground, root.accent)
        radius: Style.cornerRadius
    }
    contentItem: ReadableText {
        id: label
        text: root.text; textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        textColor: root.textOnly && (root.hot || root.down || root.emphasized) ? root.accent : root.foreground
        font.family: Style.font.family; font.pixelSize: root.fontSize
        font.underline: root.textOnly && root.keyboardFocusVisible
        opacity: root.enabled ? 1 : 0.5
    }
    HoverHandler { cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    // Qt can retain the old focus reason when clicking an already focused control.
    TapHandler { onPressedChanged: if (pressed) root.pointerFocus = true }
}
