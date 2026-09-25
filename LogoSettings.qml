import QtQuick
import qs.Ui as Ui
import qs.Commons
import "vendor/omarchy" as Choice
import "Settings.js" as Settings
import "I18n.js" as I18n

Column {
    id: root
    required property var hostWidget
    readonly property var words: hostWidget ? hostWidget.words : I18n.words("en")
    spacing: Style.space(12)
    property string error: ""
    readonly property bool sharedCooldown: !!hostWidget && hostWidget.sharedLogoCooldownEnabled
    property string target: "settings"
    property string candidateTarget: "settings"
    readonly property bool picking: picker.visible
    readonly property var activePopup: picker.visible ? picker : null
    onVisibleChanged: if (!visible) picker.close()
    function sourceFor(place) {
        return !hostWidget ? "" : place === "hover" ? hostWidget.hoverLogoImage : hostWidget.settingsLogoImage;
    }
    function save(place, value) {
        var values = {};
        values[place === "hover" ? "hoverLogoImage" : "settingsLogoImage"] = value;
        return hostWidget && hostWidget.persistSettings(values);
    }
    function choose(url, place) {
        var value = Settings.logoImage(String(url));
        error = "";
        if (!value) { error = words.logoImageError; return; }
        candidateTarget = place === "hover" ? "hover" : "settings";
        candidate.source = "";
        candidate.source = value;
    }
    Image {
        id: candidate
        visible: false; width: 0; height: 0
        asynchronous: true; sourceSize: Qt.size(256, 256)
        onStatusChanged: {
            if (status === Image.Ready) root.save(root.candidateTarget, String(source));
            else if (status === Image.Error) root.error = root.words.logoImageError;
        }
    }
    LogoPicker {
        id: picker
        hostWidget: root.hostWidget; currentSource: root.sourceFor(root.target)
        onChosen: function(url) { root.choose(url, root.target); }
    }
    SettingsRow {
        objectName: "sharedLogoCooldownToggle"
        width: parent.width; text: root.words.sharedLogoCooldown
        description: root.words.sharedLogoCooldownHelp
        palette: root.hostWidget ? root.hostWidget.surfaces : null
        accent: root.hostWidget ? root.hostWidget.accent : Color.accent
        isSwitch: true; checked: root.sharedCooldown
        onClicked: if (root.hostWidget) root.hostWidget.persistSettings({sharedLogoCooldownEnabled: !checked})
    }
    LogoCooldownControl {
        visible: root.sharedCooldown
        anchors.right: parent.right; width: parent.width - Style.space(16)
        hostWidget: root.hostWidget; prefix: "shared"
        value: root.hostWidget ? root.hostWidget.sharedLogoCooldown : 0
        unit: root.hostWidget && root.hostWidget.effectiveSettings.sharedLogoCooldownUnit === "min" ? "min" : "s"
    }
    Repeater {
        model: ["hover", "settings"]
        delegate: Column {
            id: group
            required property string modelData
            readonly property string selectedSource: root.sourceFor(modelData)
            readonly property bool animated: selectedSource === "builtin:omarchy-pixel" || /\.gif$/i.test(selectedSource)
            readonly property real loopDelay: !root.hostWidget ? 4.2
                : modelData === "hover" ? root.hostWidget.hoverLogoLoopDelay : root.hostWidget.settingsLogoLoopDelay
            readonly property real cooldown: !root.hostWidget ? 0
                : modelData === "hover" ? root.hostWidget.hoverLogoCooldown : root.hostWidget.settingsLogoCooldown
            readonly property string cooldownUnit: root.hostWidget && root.hostWidget.effectiveSettings
                && root.hostWidget.effectiveSettings[modelData + "LogoCooldownUnit"] === "min" ? "min" : "s"
            readonly property real cooldownFactor: cooldownUnit === "min" ? 60 : 1
            width: root.width; spacing: Style.space(4)
            SettingsRow {
                objectName: group.modelData + "LogoToggle"
                width: parent.width
                text: group.modelData === "hover" ? root.words.hoverLogo : root.words.settingsLogo
                palette: root.hostWidget ? root.hostWidget.surfaces : null
                accent: root.hostWidget ? root.hostWidget.accent : Color.accent
                isSwitch: true
                checked: !!root.hostWidget && (group.modelData === "hover" ? root.hostWidget.hoverLogo : root.hostWidget.settingsLogo)
                onClicked: {
                    if (!root.hostWidget) return;
                    var values = {}; values[group.modelData + "Logo"] = !checked;
                    root.hostWidget.persistSettings(values);
                }
            }
            Choice.Dropdown {
                id: choices
                objectName: group.modelData + "LogoPicker"
                anchors.right: parent.right; width: parent.width - Style.space(16)
                hostWidget: root.hostWidget; uiScale: root.hostWidget ? root.hostWidget.uiScale : 1
                accent: root.hostWidget ? root.hostWidget.accent : Color.accent
                showLabel: false
                value: group.selectedSource.indexOf("file:") === 0 ? "image" : group.selectedSource
                options: [{value:"", label:"Omarchy"},
                    {value:"builtin:omarchy-pixel", label:root.words.animatedOmarchy},
                    {value:"image", label:group.selectedSource.indexOf("file:") === 0
                        ? decodeURIComponent(group.selectedSource.split("/").pop()) : root.words.chooseLogoImage}]
                onChanged: function(value) {
                    root.error = "";
                    if (value === "image") { root.target = group.modelData; picker.begin(choices); }
                    else root.save(group.modelData, value);
                    choices.value = Qt.binding(function() {
                        return group.selectedSource.indexOf("file:") === 0 ? "image" : group.selectedSource;
                    });
                }
            }
            Item {
                visible: group.animated
                anchors.right: parent.right; width: parent.width - Style.space(16)
                height: Style.space(26)
                ReadableText {
                    anchors.left: parent.left; anchors.right: delay.left; anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.words.delayLoop; textFormat: Text.PlainText; elide: Text.ElideRight
                    textColor: Qt.alpha(Color.popups.text, loop.checked ? 0.7 : 0.4)
                    font.family: Style.font.family; font.pixelSize: Style.font.caption
                }
                EditField {
                    id: delay; objectName: group.modelData + "LogoLoopDelay"
                    anchors.right: seconds.left; anchors.rightMargin: Style.space(4)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(64); height: Style.space(24)
                    enabled: loop.checked
                    font.pixelSize: Style.font.caption
                    verticalPadding: 0; horizontalPadding: Style.space(4)
                    horizontalAlignment: TextInput.AlignHCenter
                    LayoutMirroring.enabled: false
                    maximumLength: 9; selectByMouse: true
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    validator: RegularExpressionValidator { regularExpression: /\d{1,5}([.,]\d{0,3})?/ }
                    accent: root.hostWidget ? root.hostWidget.accent : Color.accent
                    Accessible.name: root.words.delayLoop + " (s)"
                    Component.onCompleted: text = String(group.loopDelay)
                    function save() {
                        var value = Number(text.replace(",", "."));
                        if (acceptableInput && value <= 86400 && root.hostWidget
                                && Settings.logoLoopDelay(value) !== group.loopDelay) {
                            var values = {}; values[group.modelData + "LogoLoopDelay"] = Settings.logoLoopDelay(value);
                            root.hostWidget.persistSettings(values);
                        }
                        text = String(group.loopDelay);
                    }
                    onAccepted: save()
                    onEditingFinished: Qt.callLater(function() { if (delay) delay.save(); })
                    Connections {
                        target: group
                        function onLoopDelayChanged() { if (!delay.activeFocus) delay.text = String(group.loopDelay); }
                    }
                }
                ReadableText {
                    id: seconds
                    anchors.right: loop.left; anchors.rightMargin: Style.space(16)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "s"; textColor: Qt.alpha(Color.popups.text, loop.checked ? 0.7 : 0.4)
                    font.family: Style.font.family; font.pixelSize: Style.font.caption
                }
                UpdateSwitch {
                    id: loop; objectName: group.modelData + "LogoLoopToggle"
                    anchors.right: loopReset.left; anchors.rightMargin: Style.space(4)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width * 0.4)
                    checked: !root.hostWidget || (group.modelData === "hover" ? root.hostWidget.hoverLogoLoop : root.hostWidget.settingsLogoLoop)
                    highlightWhenChecked: true
                    text: root.words.loopAnimation
                    accent: root.hostWidget ? root.hostWidget.accent : Color.accent
                    onClicked: {
                        if (!root.hostWidget) return;
                        delay.save();
                        var values = {}; values[group.modelData + "LogoLoop"] = !checked;
                        root.hostWidget.persistSettings(values);
                    }
                }
                ResetButton {
                    id: loopReset; objectName: group.modelData + "LogoLoopDelayReset"
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(24); height: Style.space(26)
                    hostWidget: root.hostWidget; words: root.words
                    label: root.words.delayLoop; valueText: "4.2 s"
                    modified: group.loopDelay !== 4.2
                    accent: root.hostWidget ? root.hostWidget.accent : Color.accent
                    onResetRequested: {
                        delay.text = "4.2";
                        var values = {}; values[group.modelData + "LogoLoopDelay"] = 4.2;
                        root.hostWidget.persistSettings(values);
                    }
                }
            }
            LogoCooldownControl {
                visible: group.animated && !root.sharedCooldown
                anchors.right: parent.right; width: parent.width - Style.space(16)
                hostWidget: root.hostWidget; prefix: group.modelData
                value: group.cooldown; unit: group.cooldownUnit
            }
        }
    }
    ReadableText {
        anchors.right: parent.right; width: parent.width - Style.space(16)
        text: root.words.logoFormats; textFormat: Text.PlainText; wrapMode: Text.Wrap
        textColor: Qt.alpha(Color.popups.text, 0.7)
        font.family: Style.font.family; font.pixelSize: Style.font.caption
    }
    ReadableText {
        width: parent.width; visible: root.error !== ""
        text: root.error; textFormat: Text.PlainText; wrapMode: Text.Wrap
        textColor: Color.urgent; font.family: Style.font.family; font.pixelSize: Style.font.caption
    }
}
