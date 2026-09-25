pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import "WindowListModel.js" as ListData

Flickable {
    id: list; objectName: "windowList"
    required property var hostWidget
    required property var rows
    property Item previewBoundsItem: list
    property real scrollbarGutter: Style.spacing.popupPadding
    property Item scrollbarParent: parent
    property bool expanded: true
    property real expansion: expanded ? 1 : 0
    property bool opened: true
    property string selectedAddress: ""
    property bool showShortcuts: false
    readonly property var shortcutAddresses: visibleWindowAddresses()
    readonly property Item focusedAction: {
        for (var i = 0; i < windowRepeater.count; i++) {
            var loader = itemAtIndex(i);
            if (loader && loader.item && loader.model.kind === "window" && loader.item.focusedAction)
                return loader.item.focusedAction;
        }
        return null;
    }
    readonly property bool compact: !!hostWidget && hostWidget.appearance.tooltipStyle === "compact"
    readonly property bool rtl: !!hostWidget && hostWidget.language === "ar"
    readonly property bool busy: !!hostWidget && hostWidget.actionBusy
    readonly property color accent: hostWidget ? hostWidget.accent : Color.accent
    readonly property bool interacting: windowScrollbar.pressed || dragging
    readonly property bool rowHovered: {
        for (var i = 0; i < windowRepeater.count; i++) {
            var loader = itemAtIndex(i);
            if (loader && loader.item && loader.model.kind === "window" && loader.item.hovered)
                return true;
        }
        return false;
    }
    property alias scrollbar: windowScrollbar
    signal focusRequested(string address)
    signal bringRequested(string address)
    signal moveRequested(string address)
    signal backgroundClicked()
    signal actionFocused(string address)
    signal navigateRequested(string address, int delta, bool moveAction)
    ListModel { id: windowRows }
    function syncRows() { if (windowRows) ListData.syncRows(windowRows, rows); }
    onRowsChanged: syncRows()
    Component.onCompleted: syncRows()
    width: parent.width - (windowScrollbar.visible ? windowScrollbar.width + Style.space(4) : 0)
    x: list.rtl ? parent.width - width : 0
    clip: true
    pixelAligned: true
    contentWidth: width
    contentHeight: windowColumn.height
    flickableDirection: Flickable.VerticalFlick
    // The window inventory is finite. Like the hover preview, lay it out
    // exactly instead of estimating mixed header/row heights in ListView.
    function itemAtIndex(index) { return windowRepeater.itemAt(index); }
    function itemAt(x, y) { return windowColumn.childAt(x, y); }
    function visibleWindowAddresses() {
        var result = [];
        if (!opened || !visible || height <= 0) return result;
        for (var i = 0; i < windowRepeater.count && result.length < 10; i++) {
            var item = itemAtIndex(i);
            if (!item || !item.item || item.model.kind !== "window") continue;
            if (item.y + item.height > contentY && item.y < contentY + height)
                result.push(item.model.address);
        }
        return result;
    }
    function fittedHeight(preferred, maximum, minimum) {
        var total = contentHeight;
        var limit = Math.max(0, maximum);
        var target = Math.min(preferred, limit);
        var last = 0;
        // Measure the actual laid-out rows, including workspace headings and gaps.
        // Never depend on contentY: scrolling must not resize the panel.
        for (var i = 0; i < windowRepeater.count; i++) {
            var item = itemAtIndex(i);
            if (!item || !item.item || item.model.kind !== "window") continue;
            var bottom = item.y + item.height;
            if (bottom > limit) break;
            last = bottom;
            if (bottom >= target) return bottom;
        }
        // Prefer the previous complete window when the screen cannot fit the next.
        return last || Math.min(limit, Math.max(minimum, total));
    }
    function positionViewAtBeginning() { contentY = 0; }
    function pageAddress(key) {
        cancelFlick();
        var last = key === Qt.Key_End;
        var boundary = last || key === Qt.Key_Home;
        contentY = boundary ? (last ? Math.max(0, contentHeight - height) : 0)
            : Math.max(0, Math.min(Math.max(0, contentHeight - height), contentY + (key === Qt.Key_PageDown ? height : -height)));
        var address = "";
        for (var i = 0; i < windowRepeater.count; i++) {
            var item = itemAtIndex(i);
            if (!item || !item.item || item.model.kind !== "window") continue;
            if (last) address = item.model.address;
            else if (item.y >= contentY && item.y < contentY + height) return item.model.address;
        }
        return address || visibleWindowAddresses()[0] || "";
    }
    function ensureRowVisible(index) {
        var item = itemAtIndex(index);
        if (!item) return;
        if (item.y < contentY) contentY = item.y;
        else if (item.y + item.height > contentY + height)
            contentY = item.y + item.height - height;
    }
    function focusAction(address, moveAction) {
        var index = rows.findIndex(function(row) { return row.kind === "window" && row.address === address; });
        var loader = itemAtIndex(index);
        if (!expanded || !loader || !loader.item) return false;
        cancelFlick(); ensureRowVisible(index);
        loader.item.focusAction(moveAction);
        return true;
    }
    // Match ScratchPeek's window list: use Qt's default edge rebound.
    boundsBehavior: list.hostWidget && list.hostWidget.scrollBounce ? Flickable.DragAndOvershootBounds : Flickable.StopAtBounds
    onBoundsBehaviorChanged: if (boundsBehavior === Flickable.StopAtBounds) { cancelFlick(); returnToBounds(); }
    WheelScroll { view: list; speed: list.hostWidget ? list.hostWidget.wheelScrollSpeed : 102 }
    QQC.ScrollBar.vertical: ScrollHandle {
        id: windowScrollbar; objectName: "windowScrollbar"
        parent: list.scrollbarParent
        LayoutMirroring.enabled: false
        readonly property point listOrigin: {
            list.x; list.y; list.parent.x; list.parent.y;
            return list.mapToItem(parent, 0, 0);
        }
        visible: list.visible && size < 1 && policy !== QQC.ScrollBar.AlwaysOff
        x: list.rtl ? listOrigin.x - (list.parent.width - list.width + list.scrollbarGutter + width) / 2
            : listOrigin.x + (list.width + list.parent.width + list.scrollbarGutter - width) / 2
        y: listOrigin.y; height: list.height; accent: list.accent
    }
    MouseArea {
        id: backgroundPointer
        objectName: "windowListBackground"
        width: list.width; height: Math.max(list.height, list.contentHeight)
        z: -1
        enabled: list.opened && !list.busy
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: function(mouse) {
            if (mouse.modifiers === Qt.NoModifier && (mouse.button === Qt.MiddleButton || !list.hostWidget.doubleClickExpand)) list.backgroundClicked();
        }
        onDoubleClicked: function(mouse) {
            if (list.hostWidget.doubleClickExpand && mouse.button === Qt.LeftButton && mouse.modifiers === Qt.NoModifier) list.backgroundClicked();
        }
        onWheel: function(wheel) { wheel.accepted = false; }
    }
    readonly property bool backgroundHovered: backgroundPointer.containsMouse
    Column {
        id: windowColumn
        width: list.width
        spacing: Style.space(3)
        Repeater {
            id: windowRepeater
            model: windowRows
            delegate: Loader {
                required property var model
                width: list.width
                sourceComponent: model.kind === "workspace" ? workspaceHeader : windowRow
                Component {
                    id: workspaceHeader
                    WorkspaceHeader {
                        row: parent ? parent.model : null
                        hostWidget: list.hostWidget
                        compact: list.compact
                    }
                }
                Component {
                    id: windowRow
                    WindowRow {
                        window: {
                            var value = parent ? parent.model : null;
                            return {address: value ? value.address : "", app: value ? value.app : "",
                                appId: value ? value.appId : "", title: value ? value.title : "",
                                active: value ? value.active : false, grouped: value ? value.grouped : false};
                        }
                        hostWidget: list.hostWidget
                        compact: list.compact
                        previewBoundsItem: list.previewBoundsItem
                        expanded: list.expanded
                        expansion: list.expansion
                        selected: list.expanded && list.selectedAddress === window.address
                        shortcutIndex: list.shortcutAddresses.indexOf(window.address)
                        showShortcut: list.showShortcuts
                        enabled: list.opened
                        busy: list.busy
                        previewAllowed: list.opened && list.visible && !list.busy
                        hintsAllowed: list.opened && list.visible && !list.busy && !list.interacting
                            && !list.hostWidget.moveMenuOpen
                        onFocusRequested: function(address) { list.focusRequested(address); }
                        onBringRequested: function(address) { list.bringRequested(address); }
                        onMoveRequested: function(address) { list.moveRequested(address); }
                        onActionFocused: function(address) { list.actionFocused(address); }
                        onNavigateRequested: function(address, delta, moveAction) { list.navigateRequested(address, delta, moveAction); }
                    }
                }
            }
        }
    }
}
