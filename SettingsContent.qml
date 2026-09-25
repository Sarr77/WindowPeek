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
    readonly property string selectedPanelStyle: hostWidget ? hostWidget.selectedPanelStyle : "wallpaper"
    spacing: Style.space(16)
    property int editorFocusReason: Qt.MouseFocusReason
    property var sectionHistory: []
    signal openEditor(string mode)
    signal ensureVisible(var item)

    function begin() {
        closePickers();
        panelSection.expanded = false;
        listSection.expanded = false;
        personalizationSection.expanded = false;
        controlsSection.expanded = false;
        sectionHistory = [];
    }
    function sectionToggled(section) {
        sectionHistory = sectionHistory.filter(function(item) { return item !== section; })
            .concat(section.expanded ? [section] : []);
        closePickers();
        Qt.callLater(function() {
            section.forceLayout(); root.forceLayout();
            root.ensureVisible(section.headerItem);
        });
    }
    function focusLanguage() { languages.focusTrigger(); }
    function collapseSection() {
        var section = sectionHistory.slice().reverse().find(function(item) { return item.expanded; });
        if (!section) return false;
        section.expanded = false;
        return true;
    }
    function edit(mode, source) {
        editorFocusReason = source.activationFocusReason;
        openEditor(mode);
    }
    function focusEditor(mode, reason) {
        if (typeof reason !== "number") reason = editorFocusReason;
        if (mode === "shortcuts" || mode === "troubleshooting") {
            controlsSection.expanded = true;
            var control = mode === "shortcuts" ? shortcutsEntry : troubleshootingEntry;
            control.forceActiveFocus(reason);
            if (reason === Qt.TabFocusReason || reason === Qt.BacktabFocusReason) ensureVisible(control);
            return;
        }
        personalizationSection.expanded = true;
        var target = mode === "pictures" ? pictures : mode === "appearance" ? colors : mode === "scaling" ? scaling : labels;
        target.forceActiveFocus(reason);
        if (reason === Qt.TabFocusReason || reason === Qt.BacktabFocusReason) ensureVisible(target);
    }
    function closePickers() { languages.close(); density.close(); barLabels.close(); panelStyle.close(); textShadow.close(); }

    Choice.SearchableDropdown {
        id: languages; objectName: "languages"
        hostWidget: root.hostWidget
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
        hostWidget: root.hostWidget
        objectName: "languageDefault"
        width: parent.width; words: root.words; valueText: root.words.automatic; showReset: false
    }
    SettingsSection {
        palette: root.hostWidget ? root.hostWidget.surfaces : null
        id: panelSection; objectName: "settingsPanelSection"
        width: parent.width; title: root.words.settingsPanel; accent: root.accent
        onToggled: root.sectionToggled(panelSection)
        SettingsRow {
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            objectName: "openOnHoverToggle"
            width: parent.width; text: root.words.openOnHover; accent: root.accent
            description: root.words.enabledByDefault
            isSwitch: true; checked: !!root.hostWidget && root.hostWidget.openOnHover
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({openOnHover: !checked})
        }
        HoverDelayControl {
            hostWidget: root.hostWidget
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
            objectName: "doubleClickExpandToggle"
            width: parent.width; text: root.words.doubleClickExpand
            description: root.words.doubleClickExpandHelp
            palette: root.hostWidget ? root.hostWidget.surfaces : null; accent: root.accent
            isSwitch: true; checked: !!root.hostWidget && root.hostWidget.doubleClickExpand
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({doubleClickExpand: !checked})
        }
        SettingsRow {
            objectName: "pinByTitleClickToggle"
            width: parent.width; text: root.words.pinByTitleClick
            palette: root.hostWidget ? root.hostWidget.surfaces : null; accent: root.accent
            isSwitch: true; checked: !!root.hostWidget && root.hostWidget.pinByTitleClick
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({pinByTitleClick: !checked})
        }
        SettingsRow {
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            objectName: "windowPreviewsToggle"
            width: parent.width; text: root.words.windowPreviews; accent: root.accent
            description: root.words.enabledByDefault
            isSwitch: true; checked: !!root.hostWidget && root.hostWidget.windowPreviews
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({windowPreviews: !checked})
        }
        SettingsRow {
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            objectName: "previewBackdropToggle"
            width: parent.width; text: root.words.previewBackdrop; accent: root.accent
            description: root.words.enabledByDefault; enabled: !!root.hostWidget && root.hostWidget.windowPreviews
            isSwitch: true; checked: !!root.hostWidget && root.hostWidget.previewBackdrop
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({previewBackdrop: !checked})
        }
        SettingsRow {
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            objectName: "previewFitToggle"
            width: parent.width; text: root.words.previewFit; accent: root.accent
            description: root.words.enabledByDefault; enabled: !!root.hostWidget && root.hostWidget.windowPreviews
            isSwitch: true; checked: !!root.hostWidget && root.hostWidget.previewFit
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({previewFit: !checked})
        }
        HoverDelayControl {
            hostWidget: root.hostWidget
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
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            objectName: "popupAnimationsToggle"
            width: parent.width; text: root.words.popupAnimations
            description: root.words.popupAnimationsHelp + "\n" + root.words.enabledByDefault
            accent: root.accent; isSwitch: true; checked: !!root.hostWidget && root.hostWidget.popupAnimations
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({popupAnimations: !checked})
        }
    }
    SettingsSection {
        palette: root.hostWidget ? root.hostWidget.surfaces : null
        id: listSection; objectName: "settingsListSection"
        width: parent.width; title: root.words.settingsList; accent: root.accent
        onToggled: root.sectionToggled(listSection)
        SettingsRow {
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            objectName: "includeSpecialToggle"
            width: parent.width; text: root.words.showSpecial; accent: root.accent
            description: root.words.enabledByDefault
            isSwitch: true; checked: !!root.hostWidget && root.hostWidget.includeSpecial
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({includeSpecial: !checked})
        }
        Choice.Dropdown {
            id: density; objectName: "listDensityPicker"
            hostWidget: root.hostWidget
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
            hostWidget: root.hostWidget
            objectName: "densityDefault"
            width: parent.width; words: root.words; valueText: root.words.spacious; showReset: false
        }
        SettingsRow {
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            objectName: "scrollBounceToggle"
            width: parent.width; text: root.words.scrollBounce; accent: root.accent
            description: root.words.enabledByDefault
            isSwitch: true; checked: !!root.hostWidget && root.hostWidget.scrollBounce
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({scrollBounce: !checked})
        }
        StyleValueControl {
            hostWidget: root.hostWidget
            id: wheelSpeed; objectName: "wheelScrollSpeedControl"
            width: parent.width; words: root.words; label: root.words.wheelScrollSpeed
            accent: root.accent; from: 50; to: 300; stepSize: 1; defaultValue: 102
            value: root.hostWidget ? root.hostWidget.wheelScrollSpeed : 102
            onChanged: function(value) { if (root.hostWidget) root.hostWidget.persistSettings({wheelScrollSpeed: value}); }
            onResetRequested: if (root.hostWidget) root.hostWidget.persistSettings({wheelScrollSpeed: 102})
            onEnsureVisible: root.ensureVisible(wheelSpeed)
        }
        DefaultValue {
            hostWidget: root.hostWidget
            width: parent.width; words: root.words; valueText: "102%"; showReset: false
        }
        SettingsRow {
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            objectName: "shortcutNumbersRightToggle"
            width: parent.width; text: root.words.shortcutNumbersRight; accent: root.accent
            description: I18n.format(root.words.defaultValue, {value: root.words.shortcutNumbersInline})
            isSwitch: true; checked: !!root.hostWidget && root.hostWidget.shortcutNumbersRight
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({shortcutNumbersRight: !checked})
        }
    }
    SettingsSection {
        palette: root.hostWidget ? root.hostWidget.surfaces : null
        id: personalizationSection; objectName: "settingsPersonalizationSection"
        width: parent.width; title: root.words.settingsPersonalization; accent: root.accent
        onToggled: root.sectionToggled(personalizationSection)
        Choice.Dropdown {
            id: panelStyle; objectName: "panelStylePicker"
            hostWidget: root.hostWidget
            width: parent.width; label: root.words.panelBackground; accent: root.accent
            rowHeight: Style.space(36); popupRowHeight: Style.space(36); labelFontSize: Style.font.body
            uiScale: root.hostWidget ? root.hostWidget.uiScale : 1
            value: root.selectedPanelStyle
            options: [{value: "solid", label: root.words.solidPanel}, {value: "wallpaper", label: root.words.wallpaperPanel},
                {value: "glass", label: root.words.glassPanel}]
            onChanged: function(value) {
                if (root.hostWidget) root.hostWidget.persistSettings({panelStyle: value});
                panelStyle.value = Qt.binding(function() { return root.selectedPanelStyle; });
            }
        }
        Item {
            width: parent.width
            height: Math.max(panelStyleDefault.implicitHeight, followBar.visible ? followBar.implicitHeight : 0)
            DefaultValue {
                hostWidget: root.hostWidget
                id: panelStyleDefault; objectName: "panelStyleDefault"
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (followBar.visible ? followBar.width + Style.space(12) : 0)
                words: root.words; valueText: root.words.wallpaperPanel; showReset: false
            }
            UpdateSwitch {
                id: followBar; objectName: "followBarStyleToggle"
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width * 0.56)
                text: root.words.followBarStyle; accent: root.accent
                visible: root.selectedPanelStyle === "wallpaper"
                checked: !!root.hostWidget && root.hostWidget.followBarStyle
                onClicked: if (root.hostWidget) root.hostWidget.persistSettings({followBarStyle: !checked})
            }
        }
        TransparencyControl {
            hostWidget: root.hostWidget
            id: transparency; objectName: "backgroundTransparencyControl"
            width: parent.width; visible: !!root.hostWidget && root.selectedPanelStyle !== "solid"
            words: root.words; accent: root.accent
            readonly property bool wallpaper: !!root.hostWidget && root.selectedPanelStyle === "wallpaper"
            enabled: !wallpaper || !!root.hostWidget.themeId
            defaultValue: wallpaper && root.hostWidget ? root.hostWidget.wallpaperTransparencyDefault : 8
            value: root.hostWidget ? (wallpaper ? root.hostWidget.wallpaperTransparency : root.hostWidget.glassTransparency) : defaultValue
            onChanged: function(value) {
                if (!root.hostWidget) return;
                if (wallpaper) root.hostWidget.saveWallpaperTransparency(value);
                else root.hostWidget.persistSettings({glassTransparency:value});
            }
            onEnsureVisible: root.ensureVisible(transparency)
        }
        ReadableText {
            width: parent.width
            visible: transparency.visible && transparency.wallpaper
            text: I18n.format(root.words.colorThisTheme, {theme: root.hostWidget ? root.hostWidget.themeId.replace(/(^|-)([a-z])/g,
                function(_, dash, c) { return (dash ? " " : "") + c.toUpperCase(); }) : ""})
            textFormat: Text.PlainText; wrapMode: Text.Wrap
            textColor: Qt.alpha(Color.popups.text, 0.7)
            font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
        SettingsRow {
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            objectName: "wallpaperBlurToggle"
            width: parent.width; visible: !!root.hostWidget && root.selectedPanelStyle === "wallpaper"
            text: root.words.wallpaperBlur; accent: root.accent; isSwitch: true
            checked: !!root.hostWidget && root.hostWidget.backgroundBlur
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({backgroundBlur: !checked})
        }
        SettingsRow {
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            objectName: "backgroundTextureToggle"
            width: parent.width; visible: !!root.hostWidget && root.selectedPanelStyle !== "solid"
            text: root.words.backgroundTexture; accent: root.accent; isSwitch: true
            checked: !!root.hostWidget && root.hostWidget.backgroundTexture
            onClicked: if (root.hostWidget) root.hostWidget.persistSettings({backgroundTexture: !checked})
        }
        Choice.Dropdown {
            id: textShadow; objectName: "textShadowPicker"
            hostWidget: root.hostWidget
            width: parent.width; label: root.words.textShadow; accent: root.accent
            rowHeight: Style.space(36); popupRowHeight: Style.space(36); labelFontSize: Style.font.body
            uiScale: root.hostWidget ? root.hostWidget.uiScale : 1
            value: root.hostWidget ? root.hostWidget.textShadowMode : "auto"
            options: [{value:"auto", label:root.words.automatic},
                {value:"on", label:root.words.textShadowOn}, {value:"off", label:root.words.textShadowOff}]
            onChanged: function(value) {
                if (root.hostWidget) root.hostWidget.persistSettings({textShadowMode:value});
                textShadow.value = Qt.binding(function() { return root.hostWidget ? root.hostWidget.textShadowMode : "auto"; });
            }
        }
        SettingsRow {
            id: pictures; objectName: "openPicturesButton"
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            bordered: true; width: parent.width
            text: root.words.picturesAndGifs; accent: root.accent
            onClicked: root.edit("pictures", pictures)
        }
        SettingsRow {
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            id: colors; objectName: "openColorsButton"
            bordered: true
            width: parent.width; text: root.words.appearance; accent: root.accent
            description: root.colorRule.mode === "adaptive" ? root.words.colorAdaptive
                : root.colorRule.mode === "theme" ? root.words.colorTheme
                : root.words.customLabels + " · " + root.colorRule.color
            onClicked: root.edit("appearance", colors)
        }
        SettingsRow {
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            id: scaling; objectName: "openScalingButton"
            bordered: true
            width: parent.width; text: root.words.scaling; accent: root.accent
            description: I18n.format(root.words.scaleSummary, {panel: Math.round(root.saved.uiScale * 100), bar: Math.round(root.saved.barScale * 100)})
            onClicked: root.edit("scaling", scaling)
        }
        Choice.Dropdown {
            id: barLabels; objectName: "barLabelPicker"
            hostWidget: root.hostWidget
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
            hostWidget: root.hostWidget
            objectName: "barLabelDefault"
            width: parent.width; words: root.words; valueText: "WindowPeek · 6"; showReset: false
        }
        SettingsRow {
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            id: labels; objectName: "openLabelsButton"
            width: parent.width; text: root.words.labels; accent: root.accent
            description: root.hostWidget && root.hostWidget.savedLabels.labelStyle === "custom" ? root.words.customLabels : root.words.defaultLabels
            onClicked: root.edit("labels", labels)
        }
    }
    SettingsSection {
        palette: root.hostWidget ? root.hostWidget.surfaces : null
        id: controlsSection; objectName: "settingsControlsSection"
        width: parent.width; title: root.words.controls; accent: root.accent
        onToggled: root.sectionToggled(controlsSection)
        SettingsRow {
            id: shortcutsEntry; objectName: "shortcutsEntry"
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            width: parent.width; text: root.words.shortcutsTitle
            description: root.words.shortcutsSummary
            accent: root.accent; bordered: true
            onClicked: root.edit("shortcuts", shortcutsEntry)
        }
        SettingsRow {
            id: troubleshootingEntry; objectName: "troubleshootingEntry"
            width: parent.width; text: root.words.troubleshooting
            description: root.words.troubleshootingSummary
            accent: root.accent; bordered: true
            onClicked: root.edit("troubleshooting", troubleshootingEntry)
        }
        ControlsHelp {
            doubleClickExpand: !!root.hostWidget && root.hostWidget.doubleClickExpand
            shortcuts: root.hostWidget ? root.hostWidget.shortcuts : {}
            objectName: "controlsHelp"
            width: parent.width; language: root.hostWidget ? root.hostWidget.language : "en"
            accent: root.accent
        }
    }
}
