import QtQuick

// Row ownership prevents a late leave event from dismissing another preview.
Item {
    id: root
    objectName: "windowPreviewTarget"
    required property var hostWidget
    required property string address
    property Item anchorItem: parent
    property Item boundsItem: anchorItem
    property bool requested: false
    property bool immediate: false
    readonly property var controller: hostWidget ? hostWidget.windowPreview : null
    readonly property bool extendedHover: !!controller && controller.anchorItem === anchorItem
        && controller.visible && (controller.containsPointer || controller.menuRetained)
    function sync() {
        if (!controller) return;
        if (requested) controller.showFor(anchorItem, address, boundsItem, immediate);
        else controller.hideFor(anchorItem);
    }
    onRequestedChanged: sync()
    // `immediate` and `requested` can change in either binding order when the
    // query rebuilds rows. Wait for both before upgrading an existing request.
    onImmediateChanged: Qt.callLater(function() { if (root.requested) root.sync(); })
    onAddressChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (controller && controller.anchorItem === anchorItem) controller.dismiss()
}
