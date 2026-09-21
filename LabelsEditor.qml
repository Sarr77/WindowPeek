pragma ComponentBehavior: Bound
import QtQuick
import qs.Ui as Ui
import qs.Commons
import "vendor/omarchy" as Choice
import "Labels.js" as Labels
import "I18n.js" as I18n

Column {
    id: root
    required property var hostWidget
    readonly property var words: I18n.words(hostWidget ? hostWidget.language : "en")
    readonly property color accent: hostWidget ? hostWidget.accent : Color.accent
    property string style: "default"
    property string group: "panel"
    property var custom: ({})
    property bool saveFailed: false
    readonly property var fields: Labels.fields.filter(function(field) { return field.group === root.group; })
    readonly property var defaults: Labels.defaults(words, hostWidget ? hostWidget.preference("barLabel", "full") : "full", false)
    readonly property bool valid: Labels.valid(draft())
    signal finished()
    signal ensureVisible(var item)
    spacing: Style.space(12)

    function draft() { return {labelStyle: style, customLabels: custom}; }
    function begin() {
        var saved = hostWidget.savedLabels;
        style = saved.labelStyle; custom = JSON.parse(JSON.stringify(saved.customLabels));
        group = "panel"; saveFailed = false;
        publishPreview(); root.forceActiveFocus();
    }
    function closePickers() { stylePicker.close(); groupPicker.close(); }
    function publishPreview() { hostWidget.previewLabels(draft()); }
    function setStyle(value) { style = value; publishPreview(); }
    function setText(key, value) {
        var next = Object.assign({}, custom); next[key] = value;
        custom = next; saveFailed = false; publishPreview();
    }
    function reset() { custom = {}; saveFailed = false; publishPreview(); }
    function cancel() { closePickers(); hostWidget.cancelLabels(); finished(); }
    function apply() {
        if (!valid) return;
        if (hostWidget.saveLabels(draft())) { closePickers(); finished(); }
        else saveFailed = true;
    }
    function example(key) {
        var templates = Labels.templates(words, draft(), hostWidget ? hostWidget.preference("barLabel", "full") : "full", false);
        return Labels.render(templates[key], {count: 6, monitor: "DP-1", name: key === "specialWorkspaceLabel" ? "notes" : "4",
            workspace: I18n.workspaceTitle("4", words)});
    }
    function caption(field) {
        return field.caption ? words[field.caption] : Labels.render(defaults[field.key], {name: "4", workspace: "…"});
    }
    Keys.onEscapePressed: function(event) {
        if (stylePicker.popupOpen || groupPicker.popupOpen) closePickers(); else cancel();
        event.accepted = true;
    }

    Choice.Dropdown {
        id: stylePicker; objectName: "labelStylePicker"
        hostWidget: root.hostWidget
        width: parent.width; label: root.words.labelStyle
        value: root.style; accent: root.accent; uiScale: root.hostWidget ? root.hostWidget.uiScale : 1
        options: [{value:"default", label:root.words.defaultLabels}, {value:"custom", label:root.words.customLabels}]
        onChanged: function(value) { root.setStyle(value); stylePicker.value = Qt.binding(function() { return root.style; }); }
    }
    Text {
        width: parent.width; text: root.words.labelHelp
        textFormat: Text.PlainText; wrapMode: Text.Wrap
        color: Qt.alpha(Color.popups.text, 0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption
    }
    Choice.Dropdown {
        id: groupPicker; objectName: "labelGroupPicker"
        hostWidget: root.hostWidget
        width: parent.width; label: root.words.labelSection
        value: root.group; accent: root.accent; uiScale: root.hostWidget ? root.hostWidget.uiScale : 1
        options: Labels.groups.map(function(group) { return {value:group.value, label:root.words[group.word]}; })
        onChanged: function(value) {
            root.group = value;
            groupPicker.value = Qt.binding(function() { return root.group; });
            root.ensureVisible(groupPicker);
        }
    }
    Repeater {
        model: root.fields
        delegate: Column {
            id: field
            required property var modelData
            readonly property var invalid: Labels.invalidVariables(modelData.key, root.custom[modelData.key])
            width: root.width; spacing: Style.space(4)
            Text {
                width: parent.width; text: root.caption(field.modelData)
                textFormat: Text.PlainText; wrapMode: Text.Wrap
                color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.caption
            }
            Ui.TextField {
                objectName: "labelInput_" + field.modelData.key
                width: parent.width; visible: root.style === "custom"
                maximumLength: Labels.maximumLength
                text: root.custom[field.modelData.key] || ""
                placeholderText: root.defaults[field.modelData.key]
                Accessible.name: root.caption(field.modelData)
                accent: root.accent
                onTextEdited: root.setText(field.modelData.key, text)
                onActiveFocusChanged: if (activeFocus) root.ensureVisible(field)
            }
            DefaultValue {
                objectName: "labelDefault_" + field.modelData.key
                width: parent.width; visible: root.style === "custom"
                words: root.words; label: root.caption(field.modelData); accent: root.accent
                valueText: root.defaults[field.modelData.key]
                modified: !!root.custom[field.modelData.key]
                onResetRequested: root.setText(field.modelData.key, "")
                onEnsureVisible: root.ensureVisible(field)
            }
            Text {
                width: parent.width; visible: root.style === "custom" && field.modelData.variables.length > 0
                text: I18n.format(root.words.labelVariables, {variables:field.modelData.variables.map(function(name) { return "{" + name + "}"; }).join(", ")})
                textFormat: Text.PlainText; wrapMode: Text.Wrap
                color: Qt.alpha(Color.popups.text, 0.6); font.family: Style.font.family; font.pixelSize: Style.font.caption
            }
            Text {
                objectName: "labelExample_" + field.modelData.key
                width: parent.width; visible: root.style !== "custom" || field.modelData.variables.length > 0
                text: root.example(field.modelData.key)
                textFormat: Text.PlainText; wrapMode: Text.Wrap
                color: root.accent; font.family: Style.font.family; font.pixelSize: Style.font.body
            }
            Text {
                width: parent.width; visible: root.style === "custom" && field.invalid.length > 0
                text: I18n.format(root.words.labelInvalidVariables, {variables:field.invalid.join(", ")})
                textFormat: Text.PlainText; wrapMode: Text.Wrap
                color: Color.urgent; font.family: Style.font.family; font.pixelSize: Style.font.caption
            }
        }
    }
    Ui.Button {
        objectName: "resetLabelsButton"
        width: parent.width; visible: root.style === "custom"
        text: root.words.resetLabels; accent: root.accent; bordered: true; focusable: true
        onClicked: root.reset()
        onActiveFocusChanged: if (activeFocus) root.ensureVisible(this)
    }
    Text {
        width: parent.width; visible: !root.valid
        text: Labels.fields.filter(function(field) { return Labels.invalidVariables(field.key, root.custom[field.key]).length > 0; })
            .map(function(field) { return root.caption(field) + " — " + I18n.format(root.words.labelInvalidVariables,
                {variables:Labels.invalidVariables(field.key, root.custom[field.key]).join(", ")}); }).join("\n")
        textFormat: Text.PlainText; wrapMode: Text.Wrap
        color: Color.urgent; font.family: Style.font.family; font.pixelSize: Style.font.caption
    }
    Text {
        width: parent.width; visible: root.saveFailed; text: root.words.labelSaveError
        textFormat: Text.PlainText; wrapMode: Text.Wrap
        color: Color.urgent; font.family: Style.font.family; font.pixelSize: Style.font.caption
    }
    Row {
        width: parent.width; spacing: Style.space(10)
        Ui.Button {
            objectName: "cancelLabelsButton"; width: (parent.width-parent.spacing)/2
            text: root.words.cancel; accent: root.accent; focusable: true
            onClicked: root.cancel()
            onActiveFocusChanged: if (activeFocus) root.ensureVisible(this)
        }
        Ui.Button {
            objectName: "applyLabelsButton"; width: (parent.width-parent.spacing)/2
            text: root.words.apply; accent: root.accent; focusable: true; bordered: true; enabled: root.valid
            onClicked: root.apply()
            onActiveFocusChanged: if (activeFocus) root.ensureVisible(this)
        }
    }
}
