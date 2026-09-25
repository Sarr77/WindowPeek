import QtQuick
import QtQuick.Window
import qs.Ui as Ui
import qs.Commons
import "TextReadability.js" as Readability

// End editing on an outside press even when the clicked item takes no focus.
// The passive handler leaves clicks, selection drags and wheel input intact.
Ui.TextField {
    id: root
    property bool blurOnOutsidePress: true
    readonly property var shadowHost: Readability.hostFor(parent)
    readonly property color shadowBacking: Qt.tint(Readability.backingFor(parent),
        background && "color" in background ? background.color : "transparent")
    readonly property color originalPlaceholderColor: Qt.darker(foreground, 1.6)
    readonly property var readability: visible ? Readability.decision(shadowHost, foreground, Color.popups.text, shadowBacking) : ({active:false,ink:foreground})
    readonly property var readableInk: readability.ink
    readonly property var placeholderReadability: visible && !length && !preeditText ? Readability.decision(shadowHost, originalPlaceholderColor, Color.popups.text, shadowBacking) : ({active:false,ink:originalPlaceholderColor})
    readonly property bool readablePlaceholderEnabled: !!shadowHost
        && (shadowHost.panelStyle === "wallpaper" || shadowHost.panelStyle === "glass")
        && placeholderReadability.active
    color: Qt.rgba(readableInk.r, readableInk.g, readableInk.b, readableInk.a)
    placeholderTextColor: readablePlaceholderEnabled ? "transparent" : originalPlaceholderColor
    // Keep native editing, selection, IME and cursor rendering. Decorative
    // layers or a duplicated Text item would also duplicate/misalign these.

    // Only the empty-field hint is separate: unlike editable text it has no
    // cursor, selection or composition. This gives its glyphs a real shadow
    // without shading the input border/background or duplicating typed text.
    ReadableText {
        objectName: "readableInputPlaceholder"
        anchors.fill: parent
        anchors.leftMargin: root.leftPadding; anchors.rightMargin: root.rightPadding
        anchors.topMargin: root.topPadding; anchors.bottomMargin: root.bottomPadding
        visible: root.readablePlaceholderEnabled && !root.length && !root.preeditText
            && (!root.activeFocus || root.horizontalAlignment !== Qt.AlignHCenter)
        enabled: false
        text: root.placeholderText; textFormat: Text.PlainText
        font: root.font; elide: Text.ElideRight
        horizontalAlignment: root.horizontalAlignment; verticalAlignment: root.verticalAlignment
        shadowHost: root.shadowHost; shadowBacking: root.shadowBacking
        textColor: Qt.alpha(Color.popups.text, 1)
        style: Text.Raised
        Accessible.ignored: true // The native field already exposes its hint.
    }

    // Local item focus is not proof that this window receives keyboard input.
    cursorVisible: activeFocus && Window.active
    function containsPress(scene, position) {
        for (var item = root; item; item = item.parent) {
            if (item !== root && !item.clip) continue;
            var point = item.mapFromItem(scene, position.x, position.y);
            if (point.x < 0 || point.y < 0 || point.x >= item.width || point.y >= item.height) return false;
        }
        return true;
    }
    onVisibleChanged: if (!visible) focus = false
    onEnabledChanged: if (!enabled) focus = false
    Item {
        parent: root.Window.window ? root.Window.window.contentItem : null
        anchors.fill: parent
        z: 1000004
        visible: root.blurOnOutsidePress && root.activeFocus && root.visible && root.enabled
        PointHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onActiveChanged: if (active && !root.containsPress(parent, point.position)) root.focus = false
        }
    }
}
