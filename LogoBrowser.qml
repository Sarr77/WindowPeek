import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import "LogoCatalog.js" as Catalog
import "LogoWords.js" as Copy
import "vendor/omarchy" as Choice

QQC.Popup {
    id: root
    required property var hostWidget
    readonly property var words: hostWidget.words
    readonly property var copy: Copy.words(hostWidget.language)
    readonly property real uiScale: hostWidget.uiScale
    property Item returnFocus: null
    property string selection: ""
    property string currentSource: ""
    property string artworkTarget: "settings"
    readonly property string defaultSource: Catalog.artworkDefaults(artworkTarget)[artworkTarget + "LogoImage"]
    property bool themeColors: true
    property var opacityOverride: null
    readonly property real artworkOpacity: Catalog.opacity(opacityOverride, selection)
    readonly property real defaultOpacity: Catalog.defaultOpacity(selection)
    property string motion: "none"
    property string reveal: "none"
    property bool filesTab: false
    property bool busy: false
    property string error: ""
    property bool previewPlaying: true
    property string randomizedSource: ""
    readonly property string previewSource: Catalog.isRandom(selection) ? randomizedSource : selection
    readonly property var activePopup: filePicker.visible ? filePicker : null
    readonly property var entries: filesTab ? Catalog.recent(hostWidget.effectiveSettings.logoRecentFiles)
        .filter(function(s) { return Catalog.label(s, words).toLocaleLowerCase().indexOf(search.text.toLocaleLowerCase()) >= 0; })
        .map(function(s) { return {source:s, name:Catalog.label(s, words), group:2}; })
        : Catalog.library(words, search.text).filter(function(e) { return e.group === 1; })
    signal chosen(string source, bool themeColors, string motion, string reveal, var artworkOpacity)
    objectName: "logoBrowser"
    parent: returnFocus ? returnFocus.QQC.Overlay.overlay : null
    popupType: QQC.Popup.Item
    width: Math.min(Style.space(500), parent ? parent.width / uiScale - Style.space(24) : 500)
    height: Math.min(Style.space(650), parent ? parent.height / uiScale - Style.space(24) : 650)
    x: parent ? (parent.width / uiScale - width) / 2 : 0
    y: parent ? (parent.height / uiScale - height) / 2 : 0
    padding: Style.space(16); modal: true; focus: true
    closePolicy: QQC.Popup.CloseOnEscape
    function begin(origin, source, tint, move, entry, opacity) {
        returnFocus = origin; currentSource = source; selection = source;
        themeColors = tint; motion = move; reveal = Catalog.reveal(entry); error = ""; busy = false;
        opacityOverride = Catalog.opacitySetting(opacity);
        filesTab = source.indexOf("file:") === 0; search.text = "";
        previewPlaying = true; open(); search.forceActiveFocus();
        if (Catalog.isRandom(source)) randomizedSource = Catalog.randomSource(randomizedSource);
    }
    function select(source) {
        if (selection !== source && selection.indexOf("file:") === 0 && (Catalog.effect(source) || Catalog.isRandom(source))) themeColors = true;
        if (Catalog.isRandom(source)) randomizedSource = Catalog.randomSource(randomizedSource);
        selection = source; error = ""; previewPlaying = true;
    }
    function replay() { previewPlaying = false; Qt.callLater(function() { if (root.visible) root.previewPlaying = true; }); }
    function revealSelection() {
        var index = entries.findIndex(function(entry) { return entry.source === root.selection; });
        if (index >= 0) choices.positionViewAtIndex(index, ListView.Contain);
    }
    onOpened: Qt.callLater(revealSelection)
    onFilesTabChanged: Qt.callLater(revealSelection)
    onClosed: { filePicker.close(); previewPlaying = false; if (returnFocus) returnFocus.forceActiveFocus(Qt.OtherFocusReason); }
    background: DropdownSurface {
        hostWidget: root.hostWidget; uiScale: root.uiScale
        fallbackBackground: root.hostWidget.surfaces.pickerBackground
        radius: Style.space(8); borderSpec: Border.flat(root.hostWidget.accent, 1)
    }
    LogoPicker {
        id: filePicker; hostWidget: root.hostWidget; currentSource: root.selection
        onChosen: function(url) { root.select(url); root.themeColors = false; root.filesTab = true; }
    }
    contentItem: Column {
        readonly property var hostWidget: root.hostWidget
        readonly property color readabilityBackground: root.background.readabilityBackground
        spacing: Style.space(8)
        Row {
            id: heading; width: parent.width; spacing: Style.space(8)
            ReadableText {
                width: parent.width - close.width - parent.spacing; anchors.verticalCenter: parent.verticalCenter
                text: root.copy.library; textColor: Color.popups.text; font.family: Style.font.family
                font.pixelSize: Style.font.subtitle; font.bold: true; elide: Text.ElideRight
            }
            LabelButton { id: close; label: root.words.back; focusable: true; enabled: !root.busy; onClicked: root.close() }
        }
        EditField {
            id: search; objectName: "logoLibrarySearch"; width: parent.width
            placeholderText: root.copy.search; accent: root.hostWidget.accent; selectByMouse: true
            onTextChanged: { choices.currentIndex = -1; choices.positionViewAtBeginning(); }
            Keys.onDownPressed: { choices.forceActiveFocus(); choices.currentIndex = 0; }
        }
        Row {
            id: originals; width: parent.width; spacing: Style.space(6)
            Repeater {
                model: [{source:"",label:"Omarchy"},
                    {source:"builtin:omarchy-pixel",label:root.defaultSource === "builtin:omarchy-pixel" ? "Omarchy · " + root.copy.original : root.words.animatedOmarchy}]
                LabelButton {
                    required property var modelData
                    width: (originals.width - originals.spacing) / 2; focusable: true; bordered: true
                    label: modelData.label; selected: root.selection === modelData.source; accent: root.hostWidget.accent
                    onClicked: root.select(modelData.source)
                }
            }
        }
        LabelButton {
            id: randomChoice; objectName: "logoRandomChoice"; width: parent.width
            label: root.copy.randomGif + (root.defaultSource === Catalog.randomChoice ? " · " + root.copy.original : "")
            selected: Catalog.isRandom(root.selection); bordered: true; focusable: true
            accent: root.hostWidget.accent; Accessible.description: root.copy.randomHelp
            onClicked: root.select(Catalog.randomChoice)
        }
        Row {
            id: tabs; width: parent.width; spacing: Style.space(6)
            LabelButton { width: (parent.width - parent.spacing) / 2; label: root.copy.animations + " · 37"; selected: !root.filesTab; focusable: true; onClicked: root.filesTab = false }
            LabelButton { objectName: "logoFilesTab"; width: (parent.width - parent.spacing) / 2; label: root.copy.files; selected: root.filesTab; focusable: true; onClicked: root.filesTab = true }
        }
        Row {
            id: browsing; width: parent.width; spacing: Style.space(12)
            height: Math.max(Style.space(72), root.availableHeight - heading.height - search.height - originals.height - randomChoice.height - tabs.height
                - colorToggle.height - opacityRow.height - effectChoices.height - actions.height - message.height - parent.spacing * 10)
            Column {
                width: parent.width * 0.42; height: parent.height; spacing: Style.space(6)
                LabelButton {
                    id: browseFile; objectName: "browseLogoFile"; width: parent.width
                    visible: root.filesTab; label: root.copy.browse; bordered: true; focusable: true
                    onClicked: filePicker.begin(browseFile)
                }
                ListView {
                    id: choices; objectName: "logoLibraryList"; width: parent.width
                    height: parent.height - (browseFile.visible ? browseFile.height + parent.spacing : 0)
                    model: root.entries; clip: true; currentIndex: -1; boundsBehavior: Flickable.StopAtBounds
                    WheelScroll { view: choices; speed: root.hostWidget.wheelScrollSpeed }
                    QQC.ScrollBar.vertical: ScrollHandle { accent: root.hostWidget.accent }
                    Keys.onReturnPressed: if (currentIndex >= 0) root.select(root.entries[currentIndex].source)
                    Keys.onEnterPressed: if (currentIndex >= 0) root.select(root.entries[currentIndex].source)
                    onCurrentIndexChanged: if (activeFocus && currentIndex >= 0 && currentIndex < root.entries.length) root.select(root.entries[currentIndex].source)
                    delegate: LabelButton {
                        required property var modelData
                        required property int index
                        width: choices.width - Style.space(8); label: modelData.name; leftAlign: true; focusable: true
                        selected: root.selection === modelData.source; accent: root.hostWidget.accent
                        onClicked: { choices.currentIndex = index; root.select(modelData.source); }
                    }
                    ReadableText {
                        anchors.fill: parent; anchors.margins: Style.space(8)
                        visible: root.entries.length === 0; text: root.filesTab && !search.text ? root.copy.emptyFiles : root.words.noMatches
                        textColor: Qt.alpha(Color.popups.text, 0.75); wrapMode: Text.Wrap; font.pixelSize: Style.font.bodySmall
                        font.family: Style.font.family
                    }
                }
            }
            Column {
                width: parent.width - parent.spacing - parent.width * 0.42; height: parent.height; spacing: Style.space(8)
                ReadableText {
                    width: parent.width; text: Catalog.label(root.previewSource, root.words, root.copy); textFormat: Text.PlainText
                    textColor: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true; elide: Text.ElideMiddle
                }
                Item {
                    clip: true
                    width: parent.width; height: Math.max(Style.space(48), parent.height - selectedActions.height - Style.space(32))
                    LogoArt {
                        id: preview; objectName: "logoLibraryPreview"; anchors.fill: parent; anchors.margins: Style.space(6)
                        source: root.visible ? root.previewSource : ""; accent: root.hostWidget.accent; themeColors: root.themeColors
                        artworkOpacity: root.artworkOpacity
                        motion: root.motion; reveal: root.reveal; playing: root.visible && root.previewPlaying && !filePicker.visible
                        pendingPlayback: root.visible && !root.previewPlaying && !filePicker.visible
                        loopDelay: 1.5
                    }
                }
                Row {
                    id: selectedActions; width: parent.width; spacing: Style.space(4)
                    LabelButton {
                        width: parent.width / 2; label: Catalog.isRandom(root.selection) ? root.copy.nextGif : root.copy.replay; focusable: true
                        enabled: preview.animated
                        onClicked: if (Catalog.isRandom(root.selection)) root.select(Catalog.randomChoice); else root.replay()
                    }
                    LabelButton {
                        width: parent.width / 2; label: root.copy.remove; focusable: true
                        visible: root.filesTab && Catalog.recent(root.hostWidget.effectiveSettings.logoRecentFiles).indexOf(root.selection) >= 0
                        onClicked: root.hostWidget.persistSettings({logoRecentFiles:Catalog.recent(root.hostWidget.effectiveSettings.logoRecentFiles).filter(function(s) { return s !== root.selection; })})
                    }
                }
            }
        }
        SettingsRow {
            id: colorToggle; objectName: "logoThemeColors"; width: parent.width; text: root.copy.theme
            palette: root.hostWidget.surfaces; accent: root.hostWidget.accent
            isSwitch: true; checked: root.themeColors; enabled: root.selection !== "" && root.selection !== "builtin:omarchy-pixel"
            onClicked: root.themeColors = !root.themeColors
        }
        Row {
            id: opacityRow; width: parent.width; spacing: Style.space(8)
            ReadableText {
                id: opacityLabel; anchors.verticalCenter: parent.verticalCenter
                text: root.words.transparency; textColor: Color.popups.text
                font.family: Style.font.family; font.pixelSize: Style.font.body
            }
            QQC.Slider {
                id: opacitySlider; objectName: "logoTransparencySlider"
                width: parent.width - opacityLabel.width - opacityPercent.width - opacityReset.width - parent.spacing * 3
                anchors.verticalCenter: parent.verticalCenter
                from: 0; to: 100; stepSize: 1; snapMode: QQC.Slider.SnapAlways
                value: 100 - root.artworkOpacity; palette.highlight: root.hostWidget.accent
                Accessible.name: root.words.transparency
                onMoved: {
                    root.opacityOverride = 100 - value;
                    value = Qt.binding(function() { return 100 - root.artworkOpacity; });
                }
            }
            ReadableText {
                id: opacityPercent; anchors.verticalCenter: parent.verticalCenter
                width: Style.space(42); horizontalAlignment: Text.AlignRight
                text: Math.round(100 - root.artworkOpacity) + "%"; textColor: root.hostWidget.accent
                font.family: Style.font.family; font.pixelSize: Style.font.body
            }
            ResetButton {
                id: opacityReset; objectName: "logoTransparencyReset"
                anchors.verticalCenter: parent.verticalCenter; width: Style.space(24)
                hostWidget: root.hostWidget; words: root.words; label: root.words.transparency; valueText: (100-root.defaultOpacity) + "%"
                modified: root.opacityOverride !== null; onResetRequested: root.opacityOverride = null
            }
        }
        Row {
            id: effectChoices; width: parent.width; spacing: Style.space(8)
            Choice.Dropdown {
                id: revealChoice; objectName: "logoRevealChoice"; width: (parent.width-parent.spacing)/2; hostWidget: root.hostWidget; uiScale: root.uiScale
                label: root.copy.openingEffect; showLabel: true; accent: root.hostWidget.accent; value: root.reveal
                options: Catalog.reveals.map(function(v) { return {value:v,label:root.copy[v]}; })
                onChanged: function(value) { root.reveal = value; root.replay(); }
            }
            Choice.Dropdown {
                id: motionChoice; objectName: "logoMotionChoice"; width: (parent.width-parent.spacing)/2; hostWidget: root.hostWidget; uiScale: root.uiScale
                label: root.copy.motion; showLabel: true; accent: root.hostWidget.accent; value: root.motion
                options: ["none", "pulse", "float", "sway", "spin", "fade"].map(function(v) { return {value:v,label:root.copy[v]}; })
                onChanged: function(value) { root.motion = value; }
            }
        }
        ReadableText {
            id: message; width: parent.width; wrapMode: Text.Wrap
            text: root.error || (preview.status === Image.Error ? root.copy.missing : Catalog.isRandom(root.selection) ? root.copy.randomHelp : root.reveal !== "none" ? root.copy.openingHelp : root.copy.fit)
            textColor: root.error || preview.status === Image.Error ? Color.urgent : Qt.alpha(Color.popups.text, 0.65)
            font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
        Row {
            id: actions; width: parent.width; spacing: Style.space(8)
            LabelButton { width: (parent.width - parent.spacing) / 2; label: root.words.cancel; focusable: true; enabled: !root.busy; onClicked: root.close() }
            LabelButton {
                objectName: "applyLogoChoice"; width: (parent.width - parent.spacing) / 2
                label: root.busy ? root.copy.saving : root.copy.use; bordered: true; focusable: true; accent: root.hostWidget.accent
                enabled: !root.busy && preview.status === Image.Ready
                onClicked: root.chosen(root.selection, root.themeColors, root.motion, root.reveal, root.opacityOverride)
            }
        }
    }
}
