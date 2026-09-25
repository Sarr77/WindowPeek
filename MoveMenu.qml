import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui as Ui
import "WindowCommands.js" as Commands
import "I18n.js" as I18n

FocusScope {
    id: root
    required property var hostWidget
    property string address: ""
    property point invocation: Qt.point(0, 0)
    readonly property real uiScale: hostWidget ? hostWidget.uiScale : 1
    readonly property var words: hostWidget ? hostWidget.words : I18n.words("en")
    readonly property color accent: hostWidget ? hostWidget.accent : Color.accent
    readonly property var entry: hostWidget ? hostWidget.inventory.windows.find(function(w) { return w.address === root.address; }) : null
    readonly property var destinations: hostWidget ? Commands.destinations(hostWidget.snapshot, address, true) : []
    readonly property var filtered: destinations.filter(function(item) {
        if (item.value === "special:scratchpad") return false;
        var q = search.text.trim().toLocaleLowerCase();
        return !q || (I18n.workspaceTitle(item.name, words) + " " + item.monitor).toLocaleLowerCase().indexOf(q) >= 0;
    })
    readonly property bool busy: !!hostWidget && hostWidget.actionBusy
    property alias searchField: search
    property alias list: results
    property bool opened: false
    property Item previousFocus: null
    readonly property var window: parent ? parent.Window.window : null
    readonly property alias card: card
    width: parent ? parent.width / uiScale : 500
    height: parent ? parent.height / uiScale : 600
    scale: uiScale; transformOrigin: Item.TopLeft
    visible: opened; z: 100
    Keys.onEscapePressed: close()
    BackMouseArea { enabled: root.opened; onClicked: root.close() }
    function open() {
        if (!opened) previousFocus = window ? window.activeFocusItem : null;
        opened = true; results.currentIndex = 0;
        search.forceActiveFocus();
    }
    function close() {
        opened = false; focus = false;
        if (previousFocus && previousFocus.visible && previousFocus.enabled) previousFocus.forceActiveFocus();
        previousFocus = null;
    }
    function show(value, position) {
        address = value; invocation = position; search.text = "";
        hostWidget.clearError();
        open();
    }
    function select(value) {
        if (busy || !entry || !destinations.some(function(item) { return item.value === value; })) return;
        hostWidget.moveWindow(address, value);
    }
    onFilteredChanged: results.currentIndex = filtered.length ? 0 : -1
    Connections {
        target: root.hostWidget
        function onMoveCompleted() { if (root.visible) root.close(); }
    }
    MouseArea {
        anchors.fill: parent; acceptedButtons: Qt.AllButtons
        onPressed: root.close()
        onWheel: function(wheel) { wheel.accepted = true; }
    }
    DropdownSurface {
        id: card; objectName: "moveMenuCard"
        hostWidget: root.hostWidget; uiScale: root.uiScale
        fallbackBackground: root.hostWidget ? root.hostWidget.surfaces.pickerBackground : Color.popups.background
        x: Math.max(Style.space(8), Math.min(root.invocation.x / root.uiScale, root.width - width - Style.space(8)))
        y: Math.max(Style.space(8), Math.min(root.invocation.y / root.uiScale, root.height - height - Style.space(8)))
        width: Math.min(Style.space(280), root.width - Style.space(16))
        padding: Style.space(10)
        height: Math.min(heading.implicitHeight + search.implicitHeight
            + Math.max(Style.space(32), Math.min(root.filtered.length * Style.space(34), Style.space(216)))
            + (error.visible ? error.implicitHeight + layout.spacing : 0)
            + footer.implicitHeight + layout.spacing * 3 + padding * 2, root.height - Style.space(16))
        radius: Style.space(7)
        borderSpec: Border.flat(root.accent,1)
        // The list handles scrolling first. Consume anything it leaves behind,
        // including wheel events at its edges and over non-scrollable content.
        MouseArea {
            anchors.fill: parent; acceptedButtons: Qt.AllButtons
            onWheel: function(wheel) { wheel.accepted = true; }
        }
        Column {
            id: layout
            x: card.padding; y: card.padding; width: card.width - card.padding * 2
            spacing: Style.space(8)
            LayoutMirroring.enabled: root.hostWidget && root.hostWidget.language === "ar"
            LayoutMirroring.childrenInherit: true
            Column {
                id: heading
                width: parent.width; spacing: Style.space(3)
                ReadableText {
                    width: parent.width
                    text: root.entry ? root.entry.title || root.entry.app : root.words.windowClosed
                    textFormat: Text.PlainText; elide: Text.ElideRight
                    textColor: Color.popups.text
                    font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true
                }
                ReadableText {
                    width: parent.width
                    text: root.entry ? I18n.format(root.words.moveFrom, {workspace: I18n.workspaceTitle(root.entry.workspace.name, root.words)}) : ""
                    textFormat: Text.PlainText; elide: Text.ElideRight
                    textColor: Qt.alpha(Color.popups.text, 0.65)
                    font.family: Style.font.family; font.pixelSize: Style.font.caption
                }
            }
            EditField {
                id: search; objectName: "moveMenuSearch"
                width: parent.width; accent: root.accent
                placeholderText: root.words.moveTo
                Keys.onDownPressed: { if (results.count) { results.currentIndex = 0; results.forceActiveFocus(); } }
                Keys.onReturnPressed: { if (root.filtered.length) root.select(root.filtered[0].value); }
                Keys.onEnterPressed: { if (root.filtered.length) root.select(root.filtered[0].value); }
            }
            ListView {
                id: results; objectName: "moveMenuList"
                WheelScroll { view: results; speed: root.hostWidget ? root.hostWidget.wheelScrollSpeed : 102 }
                width: parent.width
                height: Math.max(Style.space(32), Math.min(contentHeight, Style.space(216),
                    card.height - card.padding * 2 - y - footer.implicitHeight - layout.spacing
                    - (error.visible ? error.implicitHeight + layout.spacing : 0)))
                clip: true; boundsBehavior: Flickable.StopAtBounds
                model: root.filtered
                keyNavigationEnabled: true
                QQC.ScrollBar.vertical: ScrollHandle { accent: root.accent }
                Keys.onUpPressed: {
                    if (currentIndex <= 0) search.forceActiveFocus();
                    else decrementCurrentIndex();
                }
                Keys.onReturnPressed: { if (currentIndex >= 0) root.select(root.filtered[currentIndex].value); }
                Keys.onEnterPressed: { if (currentIndex >= 0) root.select(root.filtered[currentIndex].value); }
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: results.width - Style.space(12); height: Style.space(34)
                    readonly property bool highlighted: mouse.containsMouse || (results.activeFocus && results.currentIndex === index)
                    radius: Style.space(4)
                    color: highlighted ? Qt.alpha(root.accent, 0.12) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Rectangle {
                        anchors.fill: parent; radius: parent.radius; color: "transparent"
                        border.width: 1; border.color: root.accent
                        opacity: row.highlighted ? 0.7 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    enabled: !root.busy && !!root.entry
                    opacity: enabled ? 1 : 0.5
                    Accessible.role: Accessible.MenuItem
                    Accessible.name: label.text
                    Accessible.onPressAction: root.select(modelData.value)
                    ReadableText {
                        id: label; anchors.left: parent.left; anchors.leftMargin: Style.space(8)
                        anchors.right: monitor.left; anchors.rightMargin: Style.space(6)
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.workspaceTitle(row.modelData.name, root.words)
                        textFormat: Text.PlainText; elide: Text.ElideRight
                        textColor: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body
                    }
                    ReadableText {
                        id: monitor; anchors.right: parent.right; anchors.rightMargin: Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width * 0.3)
                        text: row.modelData.monitor; textFormat: Text.PlainText; elide: Text.ElideRight
                        textColor: Qt.alpha(Color.popups.text, 0.55); font.family: Style.font.family; font.pixelSize: Style.font.caption
                    }
                    MouseArea {
                        id: mouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.select(row.modelData.value)
                    }
                }
                ReadableText {
                    anchors.centerIn: parent; visible: !results.count
                    text: root.words.noMatches; textColor: Qt.alpha(Color.popups.text, 0.65)
                    font.family: Style.font.family; font.pixelSize: Style.font.body
                }
            }
            ReadableText {
                id: error; width: parent.width; visible: !!root.hostWidget && !!root.hostWidget.actionError
                text: root.hostWidget ? root.words[root.hostWidget.actionError] || root.words.actionFailed : ""
                textFormat: Text.PlainText; wrapMode: Text.Wrap
                textColor: root.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption
            }
            Column {
                id: footer
                width: parent.width; spacing: Style.space(8)
                Rectangle { width: parent.width; height: 1; color: Qt.alpha(Color.popups.text, 0.1) }
                LabelButton {
                    id: scratchpad; objectName: "moveMenuScratchpad"
                    width: parent.width; label: root.words.moveToScratchpad
                    accent: root.accent; bordered: true; focusable: true
                    enabled: !root.busy && !!root.entry
                        && root.destinations.some(function(item) { return item.value === "special:scratchpad"; })
                    onClicked: root.select("special:scratchpad")
                }
            }
        }
    }
}
