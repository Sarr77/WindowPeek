import QtQuick
import QtQuick.Controls as QQC
import Qt.labs.folderlistmodel
import QtCore
import qs.Ui as Ui
import qs.Commons

// Stay on the panel's layer surface: a separate file-dialog window cannot take
// keyboard focus from an exclusive Wayland layer. No portal or shell commands.
QQC.Popup {
    id: root
    required property var hostWidget
    readonly property var words: hostWidget.words
    readonly property real uiScale: hostWidget.uiScale
    property Item returnFocus: null
    property string selection: ""
    property string currentSource: ""
    signal chosen(string url)
    objectName: "logoImagePicker"
    // Resolve the overlay from a live control, not from this popup: Quickshell
    // replaces the layer window during hover/open/close transitions.
    parent: returnFocus ? returnFocus.QQC.Overlay.overlay : null
    popupType: QQC.Popup.Item
    // Panel.qml already scales the overlay. Keep geometry in its logical units
    // or the chooser scales twice and Apply ends up outside the screen.
    width: Math.min(Style.space(480), parent ? parent.width / uiScale - Style.space(24) : 480)
    height: Math.min(Style.space(560), parent ? parent.height / uiScale - Style.space(24) : 560)
    x: parent ? (parent.width / uiScale - width) / 2 : 0
    y: parent ? (parent.height / uiScale - height) / 2 : 0
    padding: Style.space(16)
    modal: true; focus: true
    closePolicy: QQC.Popup.CloseOnEscape
    function begin(origin) {
        returnFocus = origin; selection = "";
        var current = currentSource;
        folders.folder = current.indexOf("file:") === 0 ? current.slice(0, current.lastIndexOf("/"))
            : StandardPaths.writableLocation(StandardPaths.HomeLocation);
        open(); files.forceActiveFocus();
    }
    function select(index) {
        if (index < 0 || index >= folders.count) return;
        var url = String(folders.get(index, "fileUrl"));
        if (folders.isFolder(index)) { selection = ""; folders.folder = url; }
        else { files.currentIndex = index; selection = url; }
    }
    function openPath(value) {
        var path = value.trim();
        if (path === "~" || path.indexOf("~/") === 0)
            path = StandardPaths.writableLocation(StandardPaths.HomeLocation) + path.slice(1);
        if (path[0] !== "/") return;
        var url = "file://" + path.split("/").map(encodeURIComponent).join("/");
        if (/\.(png|jpe?g|webp|svg|gif)$/i.test(path)) {
            folders.folder = url.slice(0, url.lastIndexOf("/"));
            selection = url;
        } else folders.folder = url;
        files.forceActiveFocus();
    }
    function accept() { if (preview.status === Image.Ready) { chosen(selection); close(); } }
    onClosed: if (returnFocus) returnFocus.forceActiveFocus(Qt.OtherFocusReason)
    background: DropdownSurface {
        hostWidget: root.hostWidget; uiScale: root.uiScale
        fallbackBackground: root.hostWidget.surfaces.pickerBackground
        radius: Style.space(8); borderSpec: Border.flat(root.hostWidget.accent, 1)
    }
    FolderListModel {
        id: folders
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg", "*.gif"]
        caseSensitive: false; showDirsFirst: true; showOnlyReadable: true
        onFolderChanged: { files.currentIndex = -1; root.selection = ""; }
    }
    contentItem: Column {
        readonly property var hostWidget: root.hostWidget
        readonly property color readabilityBackground: root.background.readabilityBackground
        spacing: Style.space(10)
        ReadableText {
            id: title
            width: parent.width; text: root.words.chooseLogoImage; textFormat: Text.PlainText
            textColor: Color.popups.text; font.family: Style.font.family
            font.pixelSize: Style.font.subtitle; font.bold: true; elide: Text.ElideRight
        }
        ReadableText {
            id: formats
            width: parent.width; text: root.words.logoFormats
            textFormat: Text.PlainText; wrapMode: Text.Wrap
            textColor: Qt.alpha(Color.popups.text, 0.7)
            font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
        Row {
            id: location; width: parent.width; spacing: Style.space(8)
            LabelButton {
                width: Style.space(40); label: "↑"; focusable: true; bordered: true
                Accessible.name: root.words.back
                enabled: String(folders.folder) !== "file:///"
                onClicked: folders.folder = folders.parentFolder
            }
            EditField {
                id: path; objectName: "logoFolderPath"
                width: parent.width - Style.space(48)
                text: decodeURIComponent(String(folders.folder).replace(/^file:\/\//, ""))
                accent: root.hostWidget.accent; selectByMouse: true
                onAccepted: root.openPath(text)
            }
        }
        ListView {
            id: files; objectName: "logoFileList"
            width: parent.width
            height: Math.max(Style.space(48), root.availableHeight - title.height - formats.height
                - location.height - actions.height - preview.height - parent.spacing * 5)
            clip: true; model: folders; currentIndex: -1
            boundsBehavior: Flickable.StopAtBounds
            WheelScroll { view: files; speed: root.hostWidget.wheelScrollSpeed }
            QQC.ScrollBar.vertical: ScrollHandle { accent: root.hostWidget.accent }
            Keys.onReturnPressed: root.select(currentIndex)
            Keys.onEnterPressed: root.select(currentIndex)
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Backspace) { folders.folder = folders.parentFolder; event.accepted = true; }
            }
            delegate: LabelButton {
                required property int index
                required property string fileName
                required property bool fileIsDir
                width: files.width; label: (fileIsDir ? "▸ " : "") + fileName
                leftAlign: true
                selected: files.currentIndex === index
                accent: root.hostWidget.accent; focusable: true
                onClicked: { files.forceActiveFocus(); root.select(index); }
            }
            ReadableText {
                anchors.centerIn: parent; visible: folders.count === 0
                text: root.words.noMatches; textColor: Color.popups.text; font.pixelSize: Style.font.body
            }
        }
        LogoImage {
            id: preview; objectName: "logoImagePreview"
            width: parent.width; height: Style.space(80); source: root.selection
            sourceSize: Qt.size(640, 160); playing: root.visible; loopDelay: 0
            ReadableText {
                anchors.fill: parent; visible: preview.status === Image.Error
                text: root.words.logoImageError; textFormat: Text.PlainText; wrapMode: Text.Wrap
                verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
                textColor: Color.urgent; font.family: Style.font.family; font.pixelSize: Style.font.caption
            }
        }
        Row {
            id: actions; width: parent.width; spacing: Style.space(10)
            LabelButton {
                width: (parent.width - parent.spacing) / 2; label: root.words.cancel
                focusable: true; onClicked: root.close()
            }
            LabelButton {
                objectName: "acceptLogoImage"
                width: (parent.width - parent.spacing) / 2; label: root.words.apply
                focusable: true; bordered: true; accent: root.hostWidget.accent
                enabled: preview.status === Image.Ready; onClicked: root.accept()
            }
        }
    }
}
