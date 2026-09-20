import QtQuick
import qs.Commons
import "vendor/omarchy" as Choice
import "Appearance.js" as Appearance
import "I18n.js" as I18n

Column {
    id: root
    required property var hostWidget
    readonly property var words: I18n.words(hostWidget ? hostWidget.language : "en")
    readonly property color accent: hostWidget ? hostWidget.accent : Color.accent
    readonly property var saved: hostWidget ? hostWidget.savedAppearance : Appearance.normalize({})
    readonly property var colorRule: Appearance.ruleFor(saved, hostWidget ? hostWidget.themeId : "")
    spacing: Style.space(16)
    signal openEditor(string mode)
    signal ensureVisible(var item)

    function begin() {
        closePickers();
        panelSection.expanded = false;
        listSection.expanded = false;
        personalizationSection.expanded = false;
        controlsSection.expanded = false;
    }
    function sectionToggled(section) {
        closePickers();
        Qt.callLater(function() {
            section.forceLayout(); root.forceLayout();
            root.ensureVisible(section.headerItem);
        });
    }
    function focusLanguage() { languages.focusTrigger(); }
    function focusEditor(mode) {
        personalizationSection.expanded = true;
        var target = mode === "appearance" ? colors : mode === "scaling" ? scaling : labels;
        target.forceActiveFocus(Qt.TabFocusReason);
    }
    function closePickers() { languages.close(); density.close(); barLabels.close(); }

    Choice.SearchableDropdown {
        id: languages; objectName: "languages"
        width: parent.width; label: root.words.language
        rowHeight: Style.space(36); popupRowHeight: Style.space(36); labelFontSize: Style.font.body
        uiScale: root.hostWidget ? root.hostWidget.uiScale : 1
        value: root.hostWidget ? root.hostWidget.languageSetting : "auto"
        options: I18n.options(root.hostWidget ? root.hostWidget.language : "en", root.hostWidget ? root.hostWidget.detectedLanguage : "en")
        placeholderText: root.words.search; emptyText: root.words.noMatches; accent: root.accent
        onChanged: function(value) {
            if (root.hostWidget) root.hostWidget.setLanguage(value);
            languages.value = Qt.binding(function() { return root.hostWidget ? root.hostWidget.languageSetting : "auto"; });
        }
    }
    DefaultValue {
        objectName: "languageDefault"
        width: parent.width; words: root.words; valueText: root.words.automatic; showReset: false
    }
    SettingsSection {
        id: panelSection; objectName: "settingsPanelSection"
        width: parent.width; title: root.words.settingsPanel; accent: root.accent
        onToggled: root.sectionToggled(panelSection)
        SettingsRow {
            objectName: "openOnHoverToggle"
            width: parent.width; text: root.words.openOnHover; accent: root.accent
            description: root.words.enabledByDefault
            isSwitch: true; checked: !!root.hostWidget && root.hostWidget.openOnHover
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({openOnHover: !checked})
        }
        HoverDelayControl {
            id: panelDelay; objectName: "panelHoverDelayControl"
            anchors.right: parent.right
            width: parent.width - Style.space(16)
            label: root.words.panelHoverDelay; helpText: root.words.hoverDelayHelp; accent: root.accent
            words: root.words
            enabled: !!root.hostWidget && root.hostWidget.openOnHover
            value: root.hostWidget ? root.hostWidget.panelHoverDelay : 400
            onChanged: function(value) { if (root.hostWidget) root.hostWidget.persistSettings({panelHoverDelay: value}); }
            onEnsureVisible: root.ensureVisible(panelDelay)
        }
        SettingsRow {
            objectName: "windowPreviewsToggle"
            width: parent.width; text: root.words.windowPreviews; accent: root.accent
            description: root.words.enabledByDefault
            isSwitch: true; checked: !!root.hostWidget && root.hostWidget.windowPreviews
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({windowPreviews: !checked})
        }
        HoverDelayControl {
            id: previewDelay; objectName: "previewHoverDelayControl"
            anchors.right: parent.right
            width: parent.width - Style.space(16)
            label: root.words.previewHoverDelay; helpText: root.words.hoverDelayHelp; accent: root.accent
            words: root.words
            enabled: !!root.hostWidget && root.hostWidget.windowPreviews
            value: root.hostWidget ? root.hostWidget.previewHoverDelay : 400
            onChanged: function(value) { if (root.hostWidget) root.hostWidget.persistSettings({previewHoverDelay: value}); }
            onEnsureVisible: root.ensureVisible(previewDelay)
        }
        SettingsRow {
            objectName: "popupAnimationsToggle"
            width: parent.width; text: root.words.popupAnimations
            description: root.words.popupAnimationsHelp + "\n" + root.words.enabledByDefault
            accent: root.accent; isSwitch: true; checked: !!root.hostWidget && root.hostWidget.popupAnimations
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({popupAnimations: !checked})
        }
    }
    SettingsSection {
        id: listSection; objectName: "settingsListSection"
        width: parent.width; title: root.words.settingsList; accent: root.accent
        onToggled: root.sectionToggled(listSection)
        SettingsRow {
            objectName: "includeSpecialToggle"
            width: parent.width; text: root.words.showSpecial; accent: root.accent
            description: root.words.enabledByDefault
            isSwitch: true; checked: !!root.hostWidget && root.hostWidget.includeSpecial
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({includeSpecial: !checked})
        }
        Choice.Dropdown {
            id: density; objectName: "listDensityPicker"
            width: parent.width; label: root.words.listDensity; accent: root.accent
            rowHeight: Style.space(36); popupRowHeight: Style.space(36); labelFontSize: Style.font.body
            uiScale: root.hostWidget ? root.hostWidget.uiScale : 1
            value: root.saved.tooltipStyle
            options: [{value: "panel", label: root.words.spacious}, {value: "compact", label: root.words.compactTip}]
            onChanged: function(value) {
                if (root.hostWidget) root.hostWidget.saveAppearance({tooltipStyle: value});
                density.value = Qt.binding(function() { return root.saved.tooltipStyle; });
            }
        }
        DefaultValue {
            objectName: "densityDefault"
            width: parent.width; words: root.words; valueText: root.words.spacious; showReset: false
        }
        SettingsRow {
            objectName: "scrollBounceToggle"
            width: parent.width; text: root.words.scrollBounce; accent: root.accent
            description: root.words.enabledByDefault
            isSwitch: true; checked: !!root.hostWidget && root.hostWidget.scrollBounce
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({scrollBounce: !checked})
        }
        SettingsRow {
            objectName: "shortcutNumbersRightToggle"
            width: parent.width; text: root.words.shortcutNumbersRight; accent: root.accent
            description: I18n.format(root.words.defaultValue, {value: root.words.shortcutNumbersInline})
            isSwitch: true; checked: !!root.hostWidget && root.hostWidget.shortcutNumbersRight
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({shortcutNumbersRight: !checked})
        }
    }
    SettingsSection {
        id: personalizationSection; objectName: "settingsPersonalizationSection"
        width: parent.width; title: root.words.settingsPersonalization; accent: root.accent
        onToggled: root.sectionToggled(personalizationSection)
        SettingsRow {
            id: colors; objectName: "openColorsButton"
            width: parent.width; text: root.words.appearance; accent: root.accent
            description: root.colorRule.mode === "adaptive" ? root.words.colorAdaptive
                : root.colorRule.mode === "theme" ? root.words.colorTheme
                : root.words.customLabels + " · " + root.colorRule.color
            onClicked: root.openEditor("appearance")
        }
        SettingsRow {
            id: scaling; objectName: "openScalingButton"
            width: parent.width; text: root.words.scaling; accent: root.accent
            description: I18n.format(root.words.scaleSummary, {panel: Math.round(root.saved.uiScale * 100), bar: Math.round(root.saved.barScale * 100)})
            onClicked: root.openEditor("scaling")
        }
        Choice.Dropdown {
            id: barLabels; objectName: "barLabelPicker"
            width: parent.width; label: root.words.barLabel; accent: root.accent
            rowHeight: Style.space(36); popupRowHeight: Style.space(36); labelFontSize: Style.font.body
            uiScale: root.hostWidget ? root.hostWidget.uiScale : 1
            value: root.hostWidget ? root.hostWidget.preference("barLabel", "full") : "full"
            options: [{value: "full", label: "WindowPeek · 6"}, {value: "compact", label: "▣ 6"}, {value: "name", label: "WindowPeek"}]
            onChanged: function(value) {
                if (root.hostWidget) root.hostWidget.persistSettings({barLabel: value});
                barLabels.value = Qt.binding(function() { return root.hostWidget ? root.hostWidget.preference("barLabel", "full") : "full"; });
            }
        }
        DefaultValue {
            objectName: "barLabelDefault"
            width: parent.width; words: root.words; valueText: "WindowPeek · 6"; showReset: false
        }
        SettingsRow {
            id: labels; objectName: "openLabelsButton"
            width: parent.width; text: root.words.labels; accent: root.accent
            description: root.hostWidget && root.hostWidget.savedLabels.labelStyle === "custom" ? root.words.customLabels : root.words.defaultLabels
            onClicked: root.openEditor("labels")
        }
    }
    SettingsSection {
        id: controlsSection; objectName: "settingsControlsSection"
        width: parent.width; title: root.words.controls; accent: root.accent
        onToggled: root.sectionToggled(controlsSection)
        ControlsHelp {
            objectName: "controlsHelp"
            width: parent.width; language: root.hostWidget ? root.hostWidget.language : "en"
            accent: root.accent
        }
    }
}
