import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Wayland
import qs.Ui as Ui
import qs.Commons
import "vendor/omarchy" as Choice
import "Shortcuts.js" as Shortcuts

QQC.Popup {
    id: root
    objectName: "shortcutRecorder"
    required property var hostWidget
    required property var editor
    readonly property var words: hostWidget.words
    readonly property color accent: hostWidget.accent
    property var definition: ({id:"",label:"",modifier:false})
    property string candidate: ""
    property Item returnFocus: null
    property bool recording: false
    readonly property bool captureReady: recording && inhibitor.active
    readonly property string problem: candidate ? editor.candidateError(definition.id,candidate) : words.shortcutChoose
    signal chosen(string id,string value)
    x: 0; y: 0; width: parent.width; height: parent.height
    padding: Style.space(16); modal: true; focus: true
    closePolicy: QQC.Popup.NoAutoClose
    background: DropdownSurface {
        hostWidget: root.hostWidget; uiScale: root.hostWidget.uiScale
        fallbackBackground: root.hostWidget.surfaces.pickerBackground
        radius: Style.space(8); borderSpec: Border.flat(root.accent,1)
    }
    function begin(def, value, origin) {
        definition=def; candidate=value; returnFocus=origin; recording=false; open();
    }
    function toggleModifier(modifier) {
        recording=false;
        var parts=Shortcuts.modifiers.filter(function(mod) {
            return mod === modifier ? !(Shortcuts.mask(root.candidate)&Shortcuts.masks[mod]) : !!(Shortcuts.mask(root.candidate)&Shortcuts.masks[mod]);
        });
        var key=Shortcuts.keyPart(candidate);
        candidate=parts.concat(key ? [key] : []).join("+");
    }
    function chooseKey(key) { recording=false; candidate=Shortcuts.modifiers.filter(function(mod) { return Shortcuts.mask(root.candidate)&Shortcuts.masks[mod]; }).concat([key]).join("+"); }
    function record(event) {
        if (event.key === Qt.Key_Escape) { recording=false; close(); event.accepted=true; return; }
        if (!captureReady) return;
        var value=Shortcuts.fromEvent(event,!!definition.modifier);
        if (value) candidate=value;
        event.accepted=true;
    }
    function accept() {
        if (!Shortcuts.normalizeChord(candidate,!!definition.modifier) || problem) return;
        chosen(definition.id,candidate); close();
    }
    onClosed: {
        recording=false; keyPicker.close();
        if (returnFocus) returnFocus.forceActiveFocus(Qt.OtherFocusReason);
    }
    // Only a confirmed inhibitor enables recording. The mouse composer works
    // even when the compositor declines keyboard-shortcut inhibition.
    ShortcutInhibitor {
        id: inhibitor
        window: root.contentItem.QsWindow.window
        enabled: root.visible && root.recording
        onCancelled: root.recording=false
    }
    contentItem: FocusScope {
        readonly property var hostWidget: root.hostWidget
        readonly property color readabilityBackground: root.background.readabilityBackground
        id: content
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) { root.record(event); }
        Keys.onReleased: function(event) { if (root.captureReady) event.accepted=true; }
        Flickable {
            id: recorderScroll
            WheelScroll { view: recorderScroll; speed: root.hostWidget ? root.hostWidget.wheelScrollSpeed : 102 }
            anchors.fill: parent; contentHeight: body.implicitHeight; clip: true
            boundsBehavior: Flickable.StopAtBounds
            QQC.ScrollBar.vertical: ScrollHandle { accent: root.accent }
            Column {
                id: body; width: parent.width; spacing: Style.space(16)
                ReadableText {
                    width: parent.width; text: root.words[root.definition.label] || root.words.shortcutsTitle
                    textColor: root.accent; font.bold: true; font.pixelSize: Style.font.subtitle
                    textFormat: Text.PlainText; wrapMode: Text.Wrap
                }
                Rectangle {
                    width: parent.width; height: Style.space(80); radius: Style.space(6)
                    color: Qt.alpha(root.accent,0.10); border.color: Qt.alpha(root.accent,0.55)
                    ReadableText {
                        anchors.fill: parent; anchors.margins: Style.space(12)
                        text: Shortcuts.display(root.candidate) || root.words.shortcutChoose
                        textFormat: Text.PlainText; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        textColor: Color.popups.text; font.pixelSize: Style.font.subtitle; font.bold:true
                    }
                }
                LabelButton {
                    objectName: "recordShortcut"; width: parent.width; focusable:true; bordered:true; accent:root.accent
                    label: root.recording ? root.words.shortcutStop : root.words.shortcutRecord
                    onClicked: { root.recording=!root.recording; content.forceActiveFocus(); }
                }
                ReadableText {
                    width: parent.width; text: root.recording ? (root.captureReady ? root.words.shortcutPress : root.words.shortcutWaiting) : root.words.shortcutCompose
                    textFormat: Text.PlainText; wrapMode: Text.Wrap; textColor: Qt.alpha(Color.popups.text,0.75); font.pixelSize:Style.font.caption
                }
                Row {
                    width: parent.width; spacing: Style.space(6)
                    Repeater {
                        model: ["Super","Ctrl","Alt","Shift"]
                        delegate: ReadableButton {
                            required property string modelData
                            width: (body.width-Style.space(18))/4; text:modelData
                            selected: !!(Shortcuts.mask(root.candidate)&Shortcuts.masks[modelData])
                            bordered:true; focusable:true; accent:root.accent
                            onClicked: root.toggleModifier(modelData)
                        }
                    }
                }
                Choice.SearchableDropdown {
                    id: keyPicker; objectName: "shortcutKeyPicker"
                    width:parent.width; visible: !root.definition.modifier
                    hostWidget:root.hostWidget; label:root.words.shortcutKey
                    uiScale:root.hostWidget.uiScale; accent:root.accent
                    value:Shortcuts.keyPart(root.candidate)
                    options:Shortcuts.keyChoices().map(function(key) { return {value:key,label:key}; })
                    placeholderText:root.words.shortcutChoose; emptyText:root.words.noMatches
                    onChanged:function(value) { root.chooseKey(value); }
                }
                ReadableText {
                    width:parent.width; text: root.problem; textFormat:Text.PlainText; wrapMode:Text.Wrap
                    textColor:Color.urgent; font.pixelSize:Style.font.caption
                    // Keep the status slot stable while trying another chord.
                    height: Math.max(Style.space(48),implicitHeight)
                }
                Row {
                    width:parent.width; spacing:Style.space(10)
                    ReadableButton { width:(body.width-parent.spacing)/2; text:root.words.cancel; focusable:true; onClicked:root.close() }
                    ReadableButton {
                        objectName:"acceptShortcut"; width:(body.width-parent.spacing)/2; text:root.words.apply
                        focusable:true; bordered:true; accent:root.accent
                        enabled:!!Shortcuts.normalizeChord(root.candidate,!!root.definition.modifier) && !root.problem
                        onClicked:root.accept()
                    }
                }
            }
        }
    }
}
