import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Shapes
import qs.Ui as Ui
import qs.Commons

// Native focus reasons keep mouse activation distinct from keyboard focus.
QQC.AbstractButton {
    id: root
    property color accent: Color.accent
    property bool pointerFocus: false
    readonly property bool keyboardFocusVisible: visualFocus && !pointerFocus
    onActiveFocusChanged: if (!activeFocus) pointerFocus = false
    onVisualFocusChanged: if (visualFocus) pointerFocus = false
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitWidth: Style.space(30)
    implicitHeight: Style.space(29)
    Accessible.name: text
    Accessible.checkable: true
    Accessible.checked: checked
    Keys.onPressed: function(event) { pointerFocus = false; event.accepted = false; }
    Keys.onReturnPressed: function(event) { pointerFocus = false; if (!event.isAutoRepeat) clicked(); }
    Keys.onEnterPressed: function(event) { pointerFocus = false; if (!event.isAutoRepeat) clicked(); }
    background: Ui.BorderSurface {
        radius: Style.cornerRadius
        color: root.down ? Style.pressedFillFor(Color.foreground, root.accent)
            : root.keyboardFocusVisible ? Style.focusFillFor(Color.foreground, root.accent)
            : root.hovered ? Style.hoverFillFor(Color.foreground, root.accent)
            : root.checked ? Qt.alpha(root.accent, 0.10) : "transparent"
        borderSpec: root.keyboardFocusVisible ? Border.controlSpec("focus", Color.foreground, root.accent)
            : root.hovered ? Border.controlSpec("hover-cursor", Color.foreground, root.accent)
            : Border.none()
    }
    contentItem: Item {
        Shape {
            anchors.centerIn: parent
            width: 20; height: 20
            scale: Style.space(14) / 20
            rotation: root.checked ? 0 : 35
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.checked ? Qt.alpha(root.accent, 0.85) : Qt.alpha(Color.popups.text, 0.75)
                strokeWidth: 1.4; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M6 2 H14 L13 5 V9 L16 12 V13 H4 V12 L7 9 V5 Z M10 13 V18" }
            }
        }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler { onPressedChanged: if (pressed) root.pointerFocus = true }
}
