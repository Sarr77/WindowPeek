import QtQuick
import qs.Commons

Item {
    id: root
    objectName: "appearanceLivePreview"
    required property var hostWidget
    property string selectedTarget: ""
    readonly property var selectionItems: {
        if (selectedTarget === "wallpaper") return [root];
        if (selectedTarget === "menu") return [menuSample];
        return windowSample.appearanceItems(selectedTarget);
    }
    signal elementPicked(string target)
    function targetAt(x, y) {
        var point = windowSample.mapFromItem(root, x, y);
        if (point.x >= 0 && point.y >= 0 && point.x < windowSample.width && point.y < windowSample.height)
            return windowSample.appearanceElementAt(point.x, point.y);
        point = menuSample.mapFromItem(root, x, y);
        if (point.x >= 0 && point.y >= 0 && point.x < menuSample.width && point.y < menuSample.height) return "menu";
        return hostWidget.panelStyle === "wallpaper" ? "wallpaper" : "panel";
    }
    implicitHeight: sample.height + Style.space(24)
    function observe(enabled) { if (hostWidget) hostWidget.observeWallpaper(root,enabled); }
    Component.onCompleted: observe(visible)
    onVisibleChanged: observe(visible)
    Component.onDestruction: observe(false)
    Rectangle { anchors.fill:parent; radius:Style.space(8); color:Color.popups.background; clip:true }
    WallpaperBackdrop {
        anchors.fill:parent; source:root.hostWidget.wallpaperSource
        screenSize:Qt.size(root.width,root.height); tintOpacity:0; radius:Style.space(8)
    }
    // A small neutral window makes real transparency distinguishable from wallpaper.
    Rectangle {
        x:root.width*0.33; y:Style.space(24); width:root.width*0.6; height:root.height-Style.space(40)
        visible:root.hostWidget.panelStyle === "glass"
        color:Color.popups.text; opacity:0.65; radius:Style.space(5)
        Rectangle { x:0; y:Style.space(24); width:parent.width; height:1; color:Color.popups.background }
    }
    Column {
        id:sample; x:Style.space(12); y:x; width:parent.width-x*2; spacing:Style.space(8)
        TooltipContent {
            id: windowSample; objectName: "appearanceWindowSample"
            hostWidget:root.hostWidget; width:parent.width; maximumHeight:Style.space(220)
            interactive:false; showHint:false
            wallpaperCanvasSize:Qt.size(root.width,root.height)
            wallpaperOrigin:Qt.point(sample.x+1,sample.y+1)
        }
        SettingsSection {
            id: menuSample; objectName: "appearanceMenuSample"
            width:parent.width; title:root.hostWidget.words.settings
            palette:root.hostWidget.surfaces; accent:root.hostWidget.accent; enabled:false
        }
    }
    Repeater {
        model: root.selectionItems
        delegate: Item {
            id: selection
            required property var modelData
            // Stay attached to the real sample geometry, including RTL and clipping.
            Item {
                parent: selection.modelData
                anchors.fill: parent
                anchors.margins: parent && Math.min(parent.width, parent.height) < Style.space(20) ? -4 : -1
                z: 10; enabled: false
                Accessible.ignored: true
                Rectangle {
                    anchors.fill: parent; radius: Style.space(6)
                    color: "transparent"; border.width: 4
                    border.color: Color.popups.background
                }
                Rectangle {
                    anchors.fill: parent; anchors.margins: 1; radius: Style.space(5)
                    color: "transparent"; border.width: 2
                    border.color: root.hostWidget.accent
                }
            }
        }
    }
    MouseArea {
        id: picker; objectName: "appearancePreviewPicker"
        anchors.fill: parent; hoverEnabled: true
        acceptedButtons: Qt.LeftButton; cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) { root.elementPicked(root.targetAt(mouse.x, mouse.y)); }
        // Let the surrounding editor keep its normal scrolling behavior.
        onWheel: function(wheel) { wheel.accepted = false; }
    }
}
