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
    color: Color.popups.background
    border.color: Qt.alpha(accent, 0.5); border.width: 1
    radius: Style.space(8)

    Column {
        id: content
        x: root.inset; y: root.inset; width: parent.width - root.inset * 2
        spacing: Style.space(12)
        LayoutMirroring.enabled: root.rtl
        LayoutMirroring.childrenInherit: true
        Item {
            id: heading; width: parent.width; height: Style.space(29)
            Text {
                anchors.left: parent.left; anchors.right: countBadge.left; anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                text: root.hostWidget ? root.hostWidget.textTemplates.panelTitle : "WindowPeek"
                textFormat: Text.PlainText; elide: Text.ElideRight
                color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true
            }
            Rectangle {
                id: countBadge
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(parent.width * 0.55, countLabel.implicitWidth + Style.space(18)); height: Style.space(26)
                radius: Style.space(5); color: Qt.alpha(root.accent, 0.09)
                Text {
                    id: countLabel; anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - Style.space(18))
                    text: Labels.render(root.hostWidget ? root.hostWidget.textTemplates.windowCount : root.words.windowsLabel + "  {count}",
                        {count:root.preview.status === "ready" ? root.preview.count : "—"})
                    textFormat: Text.PlainText; elide: Text.ElideRight
                    color: root.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true
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
            Text {
                width: parent.width; visible: root.errorText !== ""
                text: root.errorText; textFormat: Text.PlainText; wrapMode: Text.Wrap
                color: Color.urgent; font.family: Style.font.family; font.pixelSize: Style.font.caption
            }
            Text {
                id: help; width: parent.width; visible: root.showHint
                text: root.words.focusHint + "\n" + root.words.chooseMoveHint + "\n" + root.words.bringHint + "\n" + root.words.openSearchHint
                textFormat: Text.PlainText; wrapMode: Text.Wrap
                color: Qt.alpha(Color.popups.text, 0.6); font.family: Style.font.family; font.pixelSize: Style.font.caption
            }
        }
    }
}
