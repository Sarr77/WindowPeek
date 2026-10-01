import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import "LogoCatalog.js" as Catalog
import qs.Commons

FocusScope {
    id: root
    required property var hostWidget
    readonly property var words: hostWidget.words
    readonly property color accent: hostWidget.accent
    property bool opened: false
    property string requestedUrl: ""
    property string artworkSource: ""
    property real dismissMargin: 0
    readonly property bool popupOpen: opened
    readonly property Item popupInputItem: card
    signal closed(int focusReason)
    visible: opened
    Accessible.role: Accessible.Dialog
    Accessible.name: "WindowPeek"
    function open() {
        requestedUrl = "";
        artworkSource = Catalog.randomSource(artworkSource);
        supportScroll.contentY = 0;
        opened = true;
        if (hostWidget.windowPreview) hostWidget.windowPreview.dismiss();
        catalog.forceActiveFocus(Qt.OtherFocusReason);
    }
    function openLink(url) { requestedUrl = url; BrowserLinks.open(url); }
    function close(reason) {
        if (!opened) return;
        opened = false;
        closed(typeof reason === "number" ? reason : Qt.MouseFocusReason);
    }
    function revealKeyboardFocus() {
        var item = root.Window.window ? root.Window.window.activeFocusItem : null;
        for (var ancestor = item; ancestor; ancestor = ancestor.parent) {
            if (ancestor !== supportScroll.contentItem) continue;
            var top = item.mapToItem(supportScroll.contentItem, 0, 0).y;
            var next = supportScroll.contentY;
            if (top < next) next = top;
            else if (top + item.height > next + supportScroll.height) next = top + item.height - supportScroll.height;
            supportScroll.cancelFlick();
            supportScroll.contentY = Math.max(0, Math.min(next, supportScroll.contentHeight - supportScroll.height));
            return;
        }
    }
    Keys.onShortcutOverride: function(event) { Qt.callLater(root.revealKeyboardFocus); event.accepted = false; }
    Keys.onEscapePressed: function(event) { close(Qt.TabFocusReason); event.accepted = true; }
    MouseArea { anchors.fill: parent; anchors.margins: -root.dismissMargin; hoverEnabled: true; onClicked: root.close(); onWheel: function(wheel) { wheel.accepted = true; } }
    DropdownSurface {
        id: card; objectName: "projectSupportCard"
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Style.space(16))
        height: Math.min(Math.max(0, parent.height - Style.space(16)), content.implicitHeight + Style.space(48))
        hostWidget: root.hostWidget; uiScale: root.hostWidget.uiScale
        fallbackBackground: root.hostWidget.surfaces.pickerBackground
        borderSpec: Border.flat(root.accent, Style.normalBorderWidth)
        radius: Style.space(8)
        MouseArea { anchors.fill: parent; onClicked: {} }
        Flickable {
            id: supportScroll; objectName: "projectSupportScroll"
            anchors.fill: parent; anchors.margins: Style.space(24)
            contentHeight: content.implicitHeight; clip: true
            boundsBehavior: Flickable.StopAtBounds
            WheelScroll { view: supportScroll; speed: root.hostWidget.wheelScrollSpeed || 102 }
            QQC.ScrollBar.vertical: ScrollHandle { accent: root.accent }
            Column {
                id: content; width: parent.width; spacing: Style.space(24)
                Column {
                    width: parent.width; spacing: Style.space(16)
                    ReadableText {
                        objectName: "projectSupportHeading"
                        width: parent.width
                        text: root.words.projectSupportIntro; textFormat: Text.PlainText; wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true
                        textColor: Color.popups.text
                    }
                    LogoArt {
                        objectName: "projectSupportArtwork"
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(parent.width * 0.8, Style.space(260)); height: Style.space(76)
                        source: root.artworkSource; accent: root.accent; themeColors: false
                        artworkOpacity: Catalog.defaultOpacity(source)
                        playing: root.opened && root.visible && !!root.Window.window && root.Window.window.visible
                            && root.hostWidget.popupAnimations !== false
                        suspended: !root.visible || !root.Window.window || !root.Window.window.visible
                        loopAnimation: false
                        Accessible.ignored: true
                    }
                    ReadableText {
                        objectName: "projectSupportMission"
                        width: parent.width
                        text: root.words.projectSupportMission; textFormat: Text.PlainText; wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Style.font.family; font.pixelSize: Style.font.title
                        textColor: Color.popups.text
                    }
                }
                Column {
                    width: parent.width; spacing: Style.space(12)
                    ProjectLinkButton {
                        id: catalog; objectName: "starWindowPeekCatalog"
                        KeyNavigation.priority: KeyNavigation.BeforeItem
                        KeyNavigation.backtab: linkError.visible ? linkError : issues
                        width: parent.width; text: root.words.starWindowPeekCatalog; accent: root.accent; heart: true
                        enabled: !BrowserLinks.busy
                        onClicked: root.openLink("https://plugins.omarchy.org/plugin.html?id=sarr.windowpeek")
                    }
                    ProjectLinkButton {
                        objectName: "starWindowPeekGitHub"
                        width: parent.width; text: root.words.starWindowPeekGitHub; accent: root.accent
                        enabled: !BrowserLinks.busy
                        onClicked: root.openLink("https://github.com/Sarr77/WindowPeek")
                    }
                    ProjectLinkButton {
                        id: issues; objectName: "projectSupportIssues"
                        KeyNavigation.priority: KeyNavigation.BeforeItem
                        KeyNavigation.tab: linkError.visible ? linkError : catalog
                        width: parent.width; text: root.words.reportIssue; accent: root.accent; discussion: true
                        enabled: !BrowserLinks.busy
                        onClicked: root.openLink("https://github.com/Sarr77/WindowPeek/issues")
                    }
                }
                ReadableText {
                    width: parent.width; text: root.words.projectSupportThanks
                    textFormat: Text.PlainText; wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    textColor: Color.popups.text
                    font.family: Style.font.family; font.pixelSize: Style.font.title
                }
                EditField {
                    id: linkError; objectName: "projectSupportLinkError"
                    KeyNavigation.priority: KeyNavigation.BeforeItem
                    KeyNavigation.tab: catalog
                    visible: BrowserLinks.failed && BrowserLinks.lastUrl === root.requestedUrl
                    width: parent.width; readOnly: true; text: BrowserLinks.lastUrl
                    Accessible.name: root.words.browserOpenFailed
                }
                ReadableText {
                    visible: BrowserLinks.failed && BrowserLinks.lastUrl === root.requestedUrl
                    width: parent.width; text: root.words.browserOpenFailed
                    textFormat: Text.PlainText; wrapMode: Text.Wrap
                    textColor: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.title
                }
            }
        }
    }
}
