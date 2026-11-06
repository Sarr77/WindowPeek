import QtQuick
import qs.Commons
import "../vendor/omarchy" as Choice
import "Settings.js" as Settings
import "I18n.js" as I18n

Column {
    id: root
    required property var hostWidget
    readonly property var words: hostWidget ? hostWidget.words : I18n.words("en")
    readonly property color accent: hostWidget ? hostWidget.accent : "#d898f5"
    spacing: Style.space(12)
    signal ensureVisible(var item)
    function closePickers() {
        for (var i = 0; i < rules.count; i++) {
            var row = rules.itemAt(i);
            if (row) row.closePicker();
        }
    }
    function save(state, values) {
        if (hostWidget) hostWidget.persistSettings(Settings.setBarStyleRule(hostWidget.requestedSettings, state, values));
    }
    ReadableText {
        width: parent.width; text: root.words.barStyleRulesHint; textFormat: Text.PlainText
        wrapMode: Text.Wrap; font.family: Style.font.family; font.pixelSize: Style.font.caption
    }
    Repeater {
        id: rules
        model: ["opaque", "glassy", "none"]
        delegate: Column {
            id: row
            required property string modelData
            readonly property var rule: Settings.barStyleRule(root.hostWidget
                ? root.hostWidget.effectiveSettings.barStyleRules : null, modelData)
            width: root.width; spacing: Style.space(8)
            function closePicker() { picker.close(); }
            Choice.Dropdown {
                id: picker; objectName: "barStylePicker-" + row.modelData
                hostWidget: root.hostWidget; width: parent.width; accent: root.accent
                label: row.modelData === "opaque" ? root.words.barStyleOpaque
                    : row.modelData === "glassy" ? root.words.barStyleGlassy : root.words.barStyleTransparent
                rowHeight: Style.space(36); popupRowHeight: Style.space(36); labelFontSize: Style.font.body
                uiScale: root.hostWidget ? root.hostWidget.uiScale : 1
                value: row.rule.style
                options: [{value:"solid",label:root.words.solidPanel},
                    {value:"wallpaper",label:root.words.wallpaperPanel},{value:"glass",label:root.words.glassPanel}]
                onChanged: function(value) {
                    root.save(row.modelData, {style:value});
                    picker.value = Qt.binding(function() { return row.rule.style; });
                }
            }
            TransparencyControl {
                id: glassLevel
                objectName: "barStyleTransparency-" + row.modelData
                width: parent.width; visible: row.rule.style === "glass"
                hostWidget: root.hostWidget; words: root.words; accent: root.accent
                value: row.rule.glassTransparency; defaultValue: 65
                onChanged: function(value) { root.save(row.modelData, {glassTransparency:value}); }
                onEnsureVisible: root.ensureVisible(glassLevel)
            }
        }
    }
}
