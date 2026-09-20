import QtQuick
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
    function navigate(event, moveAction) {
        if (!root.expanded || event.modifiers !== Qt.NoModifier) return;
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            root.navigateRequested(root.window.address, event.key === Qt.Key_Down ? 1 : -1, moveAction);
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            var towardMove = event.key === (root.LayoutMirroring.enabled ? Qt.Key_Left : Qt.Key_Right);
            root.focusAction(towardMove);
        } else return;
        event.accepted = true;
    }
    implicitHeight: Style.space(compact ? 40 : 50)
    LayoutMirroring.enabled: hostWidget.language === "ar"
    LayoutMirroring.childrenInherit: true

    RowSurface {
        id: main
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
        Keys.onReturnPressed: if (!root.busy) root.focusRequested(root.window.address)
        Keys.onEnterPressed: if (!root.busy) root.focusRequested(root.window.address)
        Keys.onSpacePressed: if (!root.busy) root.focusRequested(root.window.address)
        Rectangle {
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
            Text {
                width: parent.width
                text: root.window.title || root.window.app || root.words.unnamed
                textFormat: Text.PlainText; elide: Text.ElideRight
                color: Color.popups.text
                font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: root.window.active
            }
            Item {
                width: parent.width; height: appLabel.implicitHeight
                Text {
                    id: appLabel
                    width: parent.width - (activeLabel.visible ? activeLabel.width + Style.space(8) : 0)
                    text: (root.window.app || root.words.unnamed)
                        + (root.window.grouped ? " · " + root.words.grouped : "")
                    textFormat: Text.PlainText; elide: Text.ElideRight
                    color: Qt.alpha(Color.popups.text, 0.7)
                    font.family: Style.font.family; font.pixelSize: Style.font.caption
                }
                Text {
                    id: activeLabel; objectName: "activeWindowLabel"
                    anchors.right: parent.right
                    width: Math.min(activeMetrics.advanceWidth, parent.width * 0.4)
                    visible: root.window.active
                    text: root.words.activeWindow; textFormat: Text.PlainText; elide: Text.ElideRight
                    color: root.accent
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
                if (modifiers & Qt.ControlModifier) {
                    if (modifiers & Qt.ShiftModifier) root.bringRequested(address);
                    else root.hostWidget.chooseDestination(address,
                        pointer.mapToItem(pointer.Window.window.contentItem, position.x, position.y));
                } else root.focusRequested(address);
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
            requested: root.hintsAllowed && !root.busy && pointer.containsMouse
            text: root.words.focusHint + "\n" + root.words.chooseMoveHint + "\n" + root.words.bringHint
        }
    }
    RowSurface {
        id: move
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
        Text {
            id: moveLabel; anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - Style.space(16)); elide: Text.ElideRight
            text: root.words.move; textFormat: Text.PlainText
            color: root.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
        MouseArea {
            id: movePointer; objectName: "windowMovePointer"; anchors.fill: parent; hoverEnabled: true; enabled: !root.busy
            cursorShape: Qt.PointingHandCursor
            property string pressedAddress: ""
            onPressed: pressedAddress = root.window.address
            onClicked: root.moveRequested(pressedAddress)
            onCanceled: pressedAddress = ""
        }
        PanelHint { objectName: "windowMoveHint"; hostWidget: root.hostWidget; requested: root.hintsAllowed && movePointer.containsMouse; text: root.words.moveHint }
    }
}
