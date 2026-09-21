pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui as Ui
import qs.Commons
import "Shortcuts.js" as Shortcuts
import "OpenShortcut.js" as Binding
import "I18n.js" as I18n

Column {
    id: root
    objectName: "shortcutsEditor"
    required property var hostWidget
    required property Item popupParent
    readonly property var words: hostWidget.words
    readonly property color accent: hostWidget.accent
    property var draft: Shortcuts.normalize({})
    property var original: Shortcuts.normalize({})
    property var systemBindings: []
    property bool probeReady: false
    property bool saveFailed: false
    property bool saving: false
    readonly property var errors: validate(draft)
    property alias recorder: recorder
    signal finished()
    signal ensureVisible(var item)
    spacing: Style.space(14)

    function begin() {
        original = Shortcuts.normalize(hostWidget.shortcuts);
        draft = Object.assign({}, original); saveFailed = false;
        refreshBindings(); forceActiveFocus();
    }
    function refreshBindings() {
        probeReady = false;
        if (Quickshell.env("QT_QPA_PLATFORM") === "offscreen") { systemBindings=[]; probeReady=true; return; }
        probe.running = true;
    }
    function validate(values) {
        var result = Shortcuts.collisions(values);
        if (!probeReady) return result;
        for (var def of Shortcuts.definitions) {
            if (values[def.id] === original[def.id] || def.modifier && def.id !== "numbers") continue;
            var chords = def.id === "numbers" ? Array.from({length:10}, function(_,i) { return values.numbers+"+"+i; }) : [values[def.id]];
            var occupied = def.id === "numbers" ? Binding.numberOccupied(root.systemBindings,values.numbers) : chords.some(function(chord) { return Binding.occupied(root.systemBindings, chord); });
            if (occupied) result[def.id] = {type:"system"};
        }
        return result;
    }
    function errorText(error) {
        if (!error) return "";
        if (error.type === "duplicate") {
            var def=Shortcuts.definitions.find(function(item) { return item.id === error.other; });
            return I18n.format(words.shortcutConflict, {action: def ? words[def.label] : error.other});
        }
        return words[error.type === "system" ? "shortcutSystemConflict" : error.type === "globalModifier" ? "shortcutNeedModifier"
            : error.type === "quickDigits" ? "shortcutDigitsReserved" : error.type === "text" ? "shortcutTextReserved" : "shortcutReserved"];
    }
    function setValue(id, value) { var next=Object.assign({}, draft); next[id]=value; draft=next; saveFailed=false; }
    function candidateError(id, value) {
        var next=Object.assign({}, draft); next[id]=value;
        return errorText(validate(next)[id]);
    }
    function apply() {
        if (Object.keys(errors).length || !probeReady || saving) return;
        // Recheck compositor conflicts immediately before committing the draft.
        saving = true;
        if (Quickshell.env("QT_QPA_PLATFORM") === "offscreen") commit(); else refreshBindings();
    }
    function commit() {
        saving=false;
        if (Object.keys(errors).length || !probeReady) return;
        if (hostWidget.persistSettings({shortcuts: Shortcuts.normalize(draft)})) finished(); else saveFailed=true;
    }
    function edit(definition, button) { recorder.begin(definition, draft[definition.id], button); }
    function cancel() { recorder.close(); finished(); }
    Keys.onEscapePressed: function(event) { cancel(); event.accepted=true; }
    Process {
        id: probe
        property string result: ""
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector { onStreamFinished: probe.result = text }
        onExited: function(code) {
            try {
                var data=JSON.parse(result);
                if (code !== 0 || !Array.isArray(data)) throw new Error("bindings unavailable");
                root.systemBindings=data; root.probeReady=true;
            } catch (error) { root.probeReady=false; root.saving=false; }
            if (root.saving) root.commit();
        }
    }
    Text {
        width: parent.width; text: root.words.shortcutsTitle; textFormat: Text.PlainText
        wrapMode: Text.Wrap; color: Color.popups.text; font.pixelSize: Style.font.subtitle; font.bold: true
    }
    Text {
        width: parent.width; text: root.words.shortcutsHelp; textFormat: Text.PlainText
        wrapMode: Text.Wrap; color: Qt.alpha(Color.popups.text,0.75); font.pixelSize: Style.font.caption
    }
    Repeater {
        model: ["shortcutOpening","shortcutWindowActions","shortcutNavigation","shortcutMouse"]
        delegate: Column {
            id: group
            required property string modelData
            width: root.width; spacing: Style.space(6)
            Text {
                width: parent.width; text: root.words[group.modelData]; textFormat: Text.PlainText
                color: root.accent; wrapMode: Text.Wrap; font.pixelSize: Style.font.body; font.bold: true
            }
            Repeater {
                model: Shortcuts.definitions.filter(function(def) { return def.group === group.modelData; })
                delegate: Item {
                    id: row
                    required property var modelData
                    width: group.width
                    implicitHeight: Math.max(Style.space(42), caption.implicitHeight + Style.space(12), chord.implicitHeight)
                    Text {
                        id: caption
                        anchors.left: parent.left; anchors.right: chord.left; anchors.rightMargin: Style.space(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.words[row.modelData.label]; textFormat: Text.PlainText; wrapMode: Text.Wrap
                        color: Color.popups.text; font.pixelSize: Style.font.body
                    }
                    LabelButton {
                        id: chord; objectName: "shortcut-" + row.modelData.id
                        anchors.right: reset.left; anchors.rightMargin: Style.space(6); anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(row.width * 0.55, Math.max(Style.space(110), implicitWidth))
                        label: Shortcuts.display(root.draft[row.modelData.id]) + (row.modelData.suffix ? " + " + (row.modelData.suffix === "click" ? root.words.shortcutClick : row.modelData.suffix) : "")
                        bordered: true; focusable: true; accent: root.accent
                        foreground: root.errors[row.modelData.id] ? Color.urgent : root.accent
                        tooltipText: root.errorText(root.errors[row.modelData.id]) || root.words.shortcutEdit
                        Accessible.name: root.words[row.modelData.label] + " · " + label
                        onClicked: root.edit(row.modelData,chord)
                        onActiveFocusChanged: if (activeFocus) root.ensureVisible(row)
                    }
                    ResetButton {
                        id: reset; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        words: root.words; accent: root.accent; label: root.words[row.modelData.label]
                        valueText: Shortcuts.display(Shortcuts.defaults[row.modelData.id])
                        modified: root.draft[row.modelData.id] !== Shortcuts.defaults[row.modelData.id]
                        onResetRequested: root.setValue(row.modelData.id,Shortcuts.defaults[row.modelData.id])
                        onEnsureVisible: root.ensureVisible(row)
                    }
                }
            }
        }
    }
    Text {
        width: parent.width; text: root.words.shortcutManual; textFormat: Text.PlainText
        wrapMode: Text.Wrap; color: Qt.alpha(Color.popups.text,0.65); font.pixelSize: Style.font.caption
    }
    Text {
        width: parent.width; visible: !!text; color: Color.urgent; textFormat: Text.PlainText; wrapMode: Text.Wrap
        text: !root.probeReady ? root.words.shortcutProbeError : root.saveFailed ? root.words.settingsError
            : Object.keys(root.errors).map(function(id) {
                return root.words[Shortcuts.definitions.find(function(def) { return def.id === id; }).label] + ": " + root.errorText(root.errors[id]);
            }).join("\n")
        font.pixelSize: Style.font.caption
    }
    LabelButton {
        width: parent.width; label: root.words.shortcutReset; focusable: true; bordered: true; accent: root.accent
        onClicked: { root.draft=Shortcuts.normalize({}); root.saveFailed=false; }
        onActiveFocusChanged: if (activeFocus) root.ensureVisible(this)
    }
    Row {
        width: parent.width; spacing: Style.space(10)
        Ui.Button { width: (parent.width-parent.spacing)/2; text: root.words.cancel; focusable:true; onClicked: root.cancel(); onActiveFocusChanged: if(activeFocus) root.ensureVisible(this) }
        Ui.Button {
            objectName: "applyShortcuts"; width: (parent.width-parent.spacing)/2; text: root.words.apply
            focusable:true; bordered:true; accent:root.accent
            enabled: !Object.keys(root.errors).length && root.probeReady && !root.saving
            onClicked: root.apply(); onActiveFocusChanged: if(activeFocus) root.ensureVisible(this)
        }
    }
    ShortcutRecorder {
        id: recorder; parent: root.popupParent
        hostWidget: root.hostWidget
        editor: root
        onChosen: function(id,value) { root.setValue(id,value); }
    }
}
