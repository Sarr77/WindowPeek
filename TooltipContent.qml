pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import "I18n.js" as I18n
import "WindowModel.js" as Model
import "WindowPreview.js" as Preview
import "WindowListModel.js" as ListData
import "Labels.js" as Labels

Rectangle {
    id: root
    required property var hostWidget
    property bool interactive: true
    property size wallpaperCanvasSize: Qt.size(width, height)
    property point wallpaperOrigin: Qt.point(1, 1)
    property real maximumHeight: Style.space(560)
    property bool showHint: !hostWidget || !hostWidget.hints || hostWidget.hints.enabled
    readonly property var words: hostWidget ? hostWidget.words : I18n.words("en")
    readonly property bool compact: hostWidget && hostWidget.appearance.tooltipStyle === "compact"
    readonly property bool rtl: hostWidget && hostWidget.language === "ar"
    readonly property color accent: hostWidget ? hostWidget.accent : Color.accent
    readonly property real inset: Style.space(compact ? 12 : 16)
    readonly property real rowHeight: Style.space(compact ? 40 : 50)
    readonly property real rowGap: Style.space(3)
    readonly property var view: Model.search(hostWidget && hostWidget.inventory ? hostWidget.inventory : Model.normalize(null),
        "", {includeSpecial: hostWidget && hostWidget.includeSpecial})
    readonly property var preview: Preview.arrange(view)
    TextMetrics {
        id: activeLabelMetrics
        text: root.words.activeWindow
        font.family: Style.font.family; font.pixelSize: Style.font.caption
    }
    readonly property bool interacting: list.interacting
    readonly property bool busy: !!hostWidget && hostWidget.actionBusy
    readonly property string errorText: hostWidget && hostWidget.actionError
        ? words[hostWidget.actionError] || words.actionFailed : ""
    signal focusRequested(string address)
    signal bringRequested(string address)
    signal moveRequested(string address)
    function containsPoint(item, x, y) {
        if (!item || !item.visible) return false;
        var point = item.mapFromItem(root, x, y);
        return point.x >= 0 && point.y >= 0 && point.x < item.width && point.y < item.height;
    }
    function appearanceElementAt(x, y) {
        var edge = Style.space(3);
        if (x < edge || y < edge || x >= width - edge || y >= height - edge
                || containsPoint(countBadge, x, y) || containsPoint(list.scrollbar, x, y)) return "accent";
        if (containsPoint(list, x, y)) {
            for (var i = 0; i < list.rows.length; ++i) {
                var row = list.itemAtIndex(i);
                if (!row || row.model.kind !== "window" || !containsPoint(row, x, y)) continue;
                var point = row.item.mapFromItem(root, x, y);
                return row.item.appearanceElementAt(point.x, point.y);
            }
        }
        return "panel";
    }
    function appearanceItems(target) {
        if (target === "panel" || target === "grain") return [root];
        if (target !== "accent" && target !== "windows") return [];
        // Reevaluate after the sample's delegates have been laid out.
        list.contentHeight;
        var items = target === "accent" ? [countBadge, list.scrollbar.contentItem] : [];
        for (var i = 0; i < list.rows.length; ++i) {
            var row = list.itemAtIndex(i);
            if (row && row.item && row.model.kind === "window")
                items = items.concat(row.item.appearanceItems(target));
        }
        return items.filter(function(item) { return item.visible; });
    }
    function resetScroll() { list.cancelFlick(); list.contentY = 0; }
    function activate(address, action) {
        if (!interactive || busy) return;
        // A released press must never target a replacement row after refresh.
        if (view.sections.some(function(s) { return s.windows.some(function(w) { return w.address === address; }); })) {
            if (action === "move") moveRequested(address);
            else if (action === "bring") bringRequested(address);
            else focusRequested(address);
        }
    }
    implicitWidth: Style.space(compact ? 360 : 420)
    implicitHeight: content.implicitHeight + inset * 2
    color: hostWidget && hostWidget.panelStyle === "glass" ? Qt.alpha(hostWidget.surfaces.panel, hostWidget.glassOpacity)
        : hostWidget ? hostWidget.surfaces.panel : Color.popups.background
    border.color: Qt.alpha(accent, 0.5); border.width: 1
    radius: Style.space(8)

    Loader {
        anchors.fill: parent; anchors.margins: 1
        active: !!root.hostWidget && (root.hostWidget.panelStyle === "wallpaper"
            || (root.hostWidget.glassPanels && root.hostWidget.backgroundTexture))
        sourceComponent: WallpaperBackdrop {
            palette: root.hostWidget.surfaces
            source: root.hostWidget.wallpaperSource
            wallpaper: root.hostWidget.panelStyle === "wallpaper"
            blurred: root.hostWidget.backgroundBlur; textured: root.hostWidget.backgroundTexture
            tintOpacity: 1-root.hostWidget.wallpaperTransparency/100
            screenSize: root.wallpaperCanvasSize; screenOrigin: root.wallpaperOrigin
            radius: root.radius-1
        }
    }

    Column {
        id: content
        x: root.inset; y: root.inset; width: parent.width - root.inset * 2
        spacing: Style.space(12)
        LayoutMirroring.enabled: root.rtl
        LayoutMirroring.childrenInherit: true
        Item {
            id: heading; width: parent.width; height: Style.space(29)
            ReadableText {
                anchors.left: parent.left; anchors.right: countBadge.left; anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                text: root.hostWidget ? root.hostWidget.textTemplates.panelTitle : "WindowPeek"
                textFormat: Text.PlainText; elide: Text.ElideRight
                textColor: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true
            }
            Rectangle {
                id: countBadge
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(parent.width * 0.55, countLabel.implicitWidth + Style.space(18)); height: Style.space(26)
                radius: Style.space(5); color: Qt.alpha(root.accent, 0.09)
                ReadableText {
                    id: countLabel; objectName: "windowCountText"; anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - Style.space(18))
                    text: Labels.render(root.hostWidget ? root.hostWidget.textTemplates.windowCount : root.words.windowsLabel + "  {count}",
                        {count:root.preview.status === "ready" ? root.preview.count : "—"})
                    textFormat: Text.PlainText; elide: Text.ElideRight
                    textColor: root.accent; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true
                }
            }
        }
        WindowList {
            id: list
            hostWidget: root.hostWidget; rows: ListData.rows(root.preview)
            enabled: root.interactive
            expanded: false; expansion: 0; opened: root.interactive && root.visible
            previewBoundsItem: root
            scrollbarGutter: root.inset
            scrollbarParent: root
            height: Math.min(contentHeight, Math.max(0, root.maximumHeight - root.inset * 2
                - heading.height - content.spacing - (footer.visible ? footer.implicitHeight + content.spacing : 0)))
            onFocusRequested: function(address) { root.activate(address, "focus"); }
            onBringRequested: function(address) { root.activate(address, "bring"); }
            onMoveRequested: function(address) { root.activate(address, "move"); }
        }
        Column {
            id: footer
            width: parent.width; spacing: Style.space(9)
            visible: root.showHint || root.errorText !== ""
            Rectangle { width: parent.width; height: 1; color: Qt.alpha(Color.popups.text, 0.1) }
            ReadableText {
                width: parent.width; visible: root.errorText !== ""
                text: root.errorText; textFormat: Text.PlainText; wrapMode: Text.Wrap
                textColor: Color.urgent; font.family: Style.font.family; font.pixelSize: Style.font.caption
            }
            ReadableText {
                id: help; width: parent.width; visible: root.showHint
                text: root.words.focusHint + "\n" + root.words.chooseMoveHint + "\n" + root.words.bringHint + "\n" + root.words.openSearchHint
                textFormat: Text.PlainText; wrapMode: Text.Wrap
                textColor: Qt.alpha(Color.popups.text, 0.6); font.family: Style.font.family; font.pixelSize: Style.font.caption
            }
        }
    }
}
