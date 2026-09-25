import QtQuick
import qs.Commons
import "FocusRecoveryText.js" as Texts

Column {
    id: root
    required property var hostWidget
    signal protectionRequested()
    readonly property var copy: Texts.words(hostWidget ? hostWidget.language : "en")
    readonly property var issues: hostWidget && hostWidget.focusRecovery ? hostWidget.focusRecovery.issues : null
    spacing: Style.space(20)

    component Paragraph: ReadableText {
        width: parent.width
        textFormat: Text.PlainText; wrapMode: Text.Wrap
        textColor: Color.popups.text
        font.family: Style.font.family; font.pixelSize: Style.font.body
        lineHeight: 1.15
    }
    component Heading: Paragraph { font.bold: true }
    component Divider: Rectangle {
        width: parent.width; height: 1; color: Qt.alpha(Color.popups.text, 0.12)
    }

    Column {
        objectName: "focusTroubleshootingIntro"
        width: parent.width; spacing: Style.space(8)
        Heading { text: root.copy.introTitle; font.pixelSize: Style.font.subtitle }
        Paragraph { text: root.copy.intro }
    }
    Column {
        width: parent.width; spacing: Style.space(8)
        Heading { text: root.copy.whyTitle }
        Paragraph { text: root.copy.why }
    }
    Column {
        objectName: "focusTroubleshootingAlternatives"
        width: parent.width; spacing: Style.space(8)
        Heading { text: root.copy.tryTitle }
        Repeater {
            model: [root.copy.trySpace, root.copy.tryClose, root.copy.tryWayland]
            Row {
                required property string modelData
                width: parent.width; spacing: Style.space(8)
                Paragraph { width: Style.space(10); text: "•"; color: root.hostWidget.accent }
                Paragraph { width: parent.width - Style.space(18); text: parent.modelData }
            }
        }
    }
    Divider {}
    Column {
        objectName: "focusProtectionSection"
        width: parent.width; spacing: Style.space(10)
        Heading { text: root.copy.protectionTitle }
        SettingsRow {
            objectName: "keepSearchFocusToggle"
            width: parent.width; text: root.copy.keep
            description: root.copy.protectionWhen
            accent: root.hostWidget ? root.hostWidget.accent : Color.accent
            bordered: true
            isSwitch: true; checked: !!root.hostWidget && root.hostWidget.keepSearchFocus
            onClicked: if (root.hostWidget) { if (checked) root.hostWidget.persistSettings({keepSearchFocus:false}); else root.protectionRequested(); }
        }
        Column {
            objectName: "focusProtectionTradeoffs"
            width: parent.width; spacing: Style.space(6)
            Heading { text: root.copy.tradeoffTitle }
            Paragraph { text: root.copy.tradeoff }
            Paragraph { text: root.copy.protectionScope; color: Qt.alpha(Color.popups.text, 0.78) }
        }
    }
    Divider {}
    Column {
        objectName: "focusWarningPreferences"
        width: parent.width; spacing: Style.space(10)
        Heading { text: root.copy.warningsTitle }
        Paragraph { text: root.copy.warningsHelp }
        SettingsRow {
            objectName: "ignoreFocusSession"; width: parent.width
            text: root.copy.ignoreSession; description: root.copy.sessionHelp
            isSwitch: true; checked: !!root.issues && root.issues.sessionIgnored
            enabled: !!root.issues && root.issues.ready && !root.issues.readBlocked
            accent: root.hostWidget.accent
            onClicked: root.issues.choose("session", !checked, "")
        }
        SettingsRow {
            objectName: "ignoreAllFocusWarnings"; width: parent.width
            text: root.copy.ignoreAll; description: root.copy.allHelp
            isSwitch: true; checked: !!root.issues && root.issues.allIgnored
            enabled: !!root.issues && root.issues.ready && !root.issues.readBlocked
            accent: root.hostWidget.accent
            onClicked: root.issues.choose("all", !checked, "")
        }
    }
    Divider {}
    Column {
        objectName: "focusApplicationsSection"
        width: parent.width; spacing: Style.space(10)
        Heading { text: root.copy.detectedApps }
        Paragraph { text: root.copy.detectedHelp }
        Paragraph {
            visible: !!root.issues && (root.issues.allIgnored || root.issues.sessionIgnored)
            text: root.copy.globalOverride; color: root.hostWidget.accent
        }
        Paragraph { visible: !root.issues || root.issues.apps.length === 0; text: root.copy.noApps }
        Repeater {
            model: root.issues ? root.issues.apps : []
            Rectangle {
                id: appCard
                required property var modelData
                width: parent.width; implicitHeight: appDetails.implicitHeight + Style.space(24)
                radius: Style.space(5); color: Qt.alpha(Color.popups.text, 0.025)
                border.width: 1; border.color: Qt.alpha(Color.popups.text, 0.16)
                Column {
                    id: appDetails
                    x: Style.space(12); y: Style.space(12)
                    width: parent.width - Style.space(24); spacing: Style.space(8)
                    Heading { text: appCard.modelData.name }
                    Paragraph {
                        text: root.copy.appUncertain + " · " + (appCard.modelData.ignored ? root.copy.ignored : root.copy.warningsOn)
                        color: Qt.alpha(Color.popups.text, 0.78)
                    }
                    SettingsRow {
                        objectName: "focusIssueApp"; width: parent.width
                        text: root.copy.appIgnoreLabel
                        isSwitch: true; checked: appCard.modelData.ignored
                        enabled: !!root.issues && root.issues.ready && !root.issues.readBlocked
                        accent: root.hostWidget.accent
                        Accessible.description: root.copy.ignoreAppAction + ": " + appCard.modelData.name
                        onClicked: root.issues.choose("app", !checked, appCard.modelData.key)
                    }
                    Paragraph {
                        text: root.copy.lastSeen.replace("{date}", Qt.formatDateTime(new Date(appCard.modelData.lastSeen), "yyyy-MM-dd hh:mm")) + "\n"
                            + root.copy.seenCount.replace("{count}", appCard.modelData.incidents) + "\n"
                            + root.copy.classLabel.replace("{class}", appCard.modelData.klass)
                        color: Qt.alpha(Color.popups.text, 0.78)
                        font.pixelSize: Style.font.caption
                    }
                }
            }
        }
        Paragraph { visible: !!root.issues && root.issues.apps.length > 0; text: root.copy.appHelp }
        Paragraph { text: root.copy.historyPrivacy; color: Qt.alpha(Color.popups.text, 0.78) }
    }
    Paragraph {
        objectName: "focusIssuesSaveError"
        visible: !!root.issues && root.issues.failed
        text: root.copy.saveFailed; color: root.hostWidget.accent
    }
}
