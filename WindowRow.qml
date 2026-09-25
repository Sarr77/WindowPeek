import QtQuick
import "Shortcuts.js" as Shortcuts
import QtQuick.Window
import Quickshell
import qs.Commons

Item {
    id: root
    required property var window
    required property var hostWidget
    property Item previewBoundsItem: root
    property bool selected: false
    property bool busy: false
    property bool hintsAllowed: true
    property bool previewAllowed: hintsAllowed
    property bool expanded: true
    property real expansion: expanded ? 1 : 0
    property bool compact: false
    property int shortcutIndex: -1
    property bool showShortcut: false
    readonly property bool shortcutAtRight: !!hostWidget && hostWidget.shortcutNumbersRight === true
    readonly property Item focusedAction: move.focus ? move : main.focus ? main : null
    readonly property bool hovered: main.hovered || move.hovered
    readonly property var words: hostWidget.words
    readonly property color accent: hostWidget.accent
    signal focusRequested(string address)
    signal bringRequested(string address)
    signal moveRequested(string address)
    signal actionFocused(string address)
    signal navigateRequested(string address, int delta, bool moveAction)
    function focusAction(moveAction) {
        if (root.expanded) (moveAction ? move : main).forceActiveFocus(Qt.OtherFocusReason);
    }
    // Geometry only: the appearance sample never invokes the row's actions.
    function appearanceElementAt(x, y) {
        for (var item of [activeMarker, activeLabel, shortcutLabel]) {
            if (!item.visible) continue;
            var point = item.mapFromItem(root, x, y);
            var margin = Style.space(3);
            if (point.x >= -margin && point.y >= -margin
                    && point.x < item.width + margin && point.y < item.height + margin) return "accent";
        }
        return "windows";
    }
    function appearanceItems(target) {
        return target === "windows" ? [main] : [activeMarker, activeLabel, shortcutLabel];
    }
    function navigate(event, moveAction) {
        if (!root.expanded) return;
        var config = Shortcuts.normalize(root.hostWidget.shortcuts);
        if (Shortcuts.matches(event, config.move)) {
            if (!root.busy && !event.isAutoRepeat) root.moveRequested(root.window.address);
        } else if (Shortcuts.matches(event, config.previous) || Shortcuts.matches(event, config.next)) {
            root.navigateRequested(root.window.address, Shortcuts.matches(event, config.next) ? 1 : -1, moveAction);
        } else if (Shortcuts.matches(event, Shortcuts.actionChord(config, "windowSide", root.LayoutMirroring.enabled))) {
            root.focusAction(false);
        } else if (Shortcuts.matches(event, Shortcuts.actionChord(config, "moveSide", root.LayoutMirroring.enabled))) {
            root.focusAction(true);
        } else return;
        event.accepted = true;
    }
    implicitHeight: Style.space(compact ? 40 : 50)
    LayoutMirroring.enabled: hostWidget.language === "ar"
    LayoutMirroring.childrenInherit: true

    RowSurface {
        id: main
        glass: !!root.hostWidget && root.hostWidget.glassPanels === true
        fillColor: root.hostWidget.surfaces.windows
        fillOpacity: root.hostWidget.surfaces.windowOpacity
        objectName: "windowFocus"
        anchors.left: parent.left
        width: parent.width - (move.width + Style.space(6)) * root.expansion
        height: parent.height
        accent: root.accent
        hovered: !root.busy && (pointer.containsMouse || previewTarget.extendedHover)
        pressed: pointer.pressed
        selected: root.selected && !move.activeFocus
        currentWindow: root.window.active
        activeFocusOnTab: root.expanded
        onActiveFocusChanged: if (activeFocus) root.actionFocused(root.window.address)
        Keys.onPressed: function(event) { root.navigate(event, false); }
        Accessible.role: Accessible.Button
        Accessible.name: root.window.app + " · " + root.window.title
        Accessible.onPressAction: if (!root.busy) root.focusRequested(root.window.address)
        Keys.onReturnPressed: function(event) { event.accepted=false; root.navigate(event, false); if (!event.accepted && !root.busy) root.focusRequested(root.window.address); }
        Keys.onEnterPressed: function(event) { event.accepted=false; root.navigate(event, false); if (!event.accepted && !root.busy) root.focusRequested(root.window.address); }
        Keys.onSpacePressed: if (!root.busy) root.focusRequested(root.window.address)
        Rectangle {
            id: activeMarker
            objectName: "activeWindowMarker"
            anchors.left: parent.left; anchors.leftMargin: 1
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(3); height: parent.height - Style.space(16); radius: width / 2
            color: root.accent; visible: root.window.active
        }
        WindowIcon {
            id: icon; objectName: "windowIcon"
            appId: root.window.appId || root.window.app
            imageScale: root.hostWidget.uiScale
            width: Style.space(root.compact ? 20 : 24); height: width
            anchors.left: parent.left; anchors.leftMargin: Style.space(9)
            anchors.verticalCenter: parent.verticalCenter
        }
        Column {
            anchors.left: icon.right; anchors.leftMargin: Style.space(9)
            anchors.right: parent.right; anchors.rightMargin: Style.space(9)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            ReadableText {
                width: parent.width
                text: root.window.title || root.window.app || root.words.unnamed
                textFormat: Text.PlainText; elide: Text.ElideRight
                textColor: Color.popups.text
                font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: root.window.active
            }
            Item {
                width: parent.width; height: appLabel.implicitHeight
                readonly property bool mirrored: !root.shortcutAtRight && root.LayoutMirroring.enabled
                ReadableText {
                    id: appLabel; objectName: "windowAppLabel"
                    x: parent.mirrored ? parent.width - width : 0
                    width: Math.min(appMetrics.advanceWidth, Math.max(0, parent.width
                        - (activeLabel.visible ? activeLabel.width + Style.space(8) : 0)
                        - (shortcutLabel.visible ? shortcutLabel.width + Style.space(6) : 0)))
                    text: (root.window.app || root.words.unnamed)
                        + (root.window.grouped ? " · " + root.words.grouped : "")
                    textFormat: Text.PlainText; elide: Text.ElideRight
                    textColor: Qt.alpha(Color.popups.text, 0.7)
                    font.family: Style.font.family; font.pixelSize: Style.font.caption
                    TextMetrics { id: appMetrics; text: appLabel.text; font: appLabel.font }
                }
                ReadableText {
                    id: shortcutLabel; objectName: "windowShortcutLabel"
                    x: root.shortcutAtRight ? parent.width - width
                        : parent.mirrored ? appLabel.x - width - Style.space(6)
                        : appLabel.x + appLabel.width + Style.space(6)
                    width: Math.max(implicitWidth, Style.space(12))
                    horizontalAlignment: root.shortcutAtRight ? Text.AlignRight : Text.AlignLeft
                    visible: root.showShortcut && root.shortcutIndex >= 0
                    text: root.shortcutIndex < 0 ? "" : String((root.shortcutIndex + 1) % 10)
                    textFormat: Text.PlainText; textColor: root.accent
                    font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true
                }
                ReadableText {
                    id: activeLabel; objectName: "activeWindowLabel"
                    x: root.shortcutAtRight && shortcutLabel.visible ? shortcutLabel.x - width - Style.space(6)
                        : parent.mirrored ? 0 : parent.width - width
                    width: Math.min(activeMetrics.advanceWidth, parent.width * 0.4)
                    visible: root.window.active
                    text: root.words.activeWindow; textFormat: Text.PlainText; elide: Text.ElideRight
                    textColor: root.accent
                    font.family: Style.font.family; font.pixelSize: Style.font.caption
                    TextMetrics { id: activeMetrics; text: activeLabel.text; font: activeLabel.font }
                }
            }
        }
        WindowClickArea {
            id: pointer; objectName: "windowFocusPointer"
            anchors.fill: parent; hoverEnabled: true; enabled: !root.busy
            cursorShape: Qt.PointingHandCursor
            address: root.window.address
            onActivated: function(address, modifiers, position) {
                var action = Shortcuts.mouseAction(root.hostWidget.shortcuts, modifiers);
                if (action === "bring") root.bringRequested(address);
                else if (action === "move") {
                    var point = pointer.mapToItem(pointer.Window.window.contentItem, position.x, position.y);
                    var surface = pointer.QsWindow.window;
                    if (surface && surface.overlayOffset) point = Qt.point(point.x + surface.overlayOffset.x, point.y + surface.overlayOffset.y);
                    root.hostWidget.chooseDestination(address, point);
                }
                else root.focusRequested(address);
            }
        }
        WindowPreviewTarget {
            id: previewTarget
            hostWidget: root.hostWidget; address: root.window.address
            boundsItem: root.previewBoundsItem
            requested: root.previewAllowed && !root.busy && pointer.containsMouse
        }
        PanelHint {
            objectName: "windowFocusHint"
            hostWidget: root.hostWidget
            belowAnchor: true
            anchorItem: root.previewBoundsItem
            requested: root.hintsAllowed && !root.busy && pointer.containsMouse
            text: root.words.focusHint + "\n" + root.words.chooseMoveHint + "\n" + root.words.bringHint
        }
    }
    RowSurface {
        id: move
        glass: !!root.hostWidget && root.hostWidget.glassPanels === true
        fillColor: root.hostWidget.surfaces.windows
        fillOpacity: root.hostWidget.surfaces.windowOpacity
        objectName: "windowMove"
        anchors.right: parent.right; height: parent.height
        opacity: root.expansion
        visible: root.expansion > 0
        enabled: root.expanded
        width: Math.min(parent.width * 0.35, Math.max(Style.space(62), moveLabel.implicitWidth + Style.space(16)))
        accent: root.accent
        hovered: !root.busy && movePointer.containsMouse
        pressed: movePointer.pressed
        activeFocusOnTab: root.expanded
        onActiveFocusChanged: if (activeFocus) root.actionFocused(root.window.address)
        Keys.onPressed: function(event) { root.navigate(event, true); }
        Accessible.role: Accessible.Button
        Accessible.name: root.words.move + " · " + root.window.app
        Accessible.onPressAction: if (!root.busy) root.moveRequested(root.window.address)
        Keys.onReturnPressed: if (!root.busy) root.moveRequested(root.window.address)
        Keys.onEnterPressed: if (!root.busy) root.moveRequested(root.window.address)
        Keys.onSpacePressed: if (!root.busy) root.moveRequested(root.window.address)
        ReadableText {
            id: moveLabel; anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - Style.space(16)); elide: Text.ElideRight
            text: root.words.move; textFormat: Text.PlainText
            textColor: root.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
        MouseArea {
            id: movePointer; objectName: "windowMovePointer"; anchors.fill: parent; hoverEnabled: true; enabled: !root.busy
            cursorShape: Qt.PointingHandCursor
            property string pressedAddress: ""
            onPressed: pressedAddress = root.window.address
            onClicked: root.moveRequested(pressedAddress)
            onCanceled: pressedAddress = ""
        }
        PanelHint {
            objectName: "windowMoveHint"; hostWidget: root.hostWidget
            belowAnchor: true; anchorItem: root.previewBoundsItem
            requested: root.hintsAllowed && movePointer.containsMouse; text: root.words.moveHint
        }
    }
}
