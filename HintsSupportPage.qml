import QtQuick
import qs.Commons
import "I18n.js" as I18n

Column {
    id: root
    required property var hostWidget
    readonly property var words: I18n.words(hostWidget ? hostWidget.language : "en")
    readonly property color accent: hostWidget ? hostWidget.accent : Color.accent
    readonly property string issuesUrl: "https://github.com/Sarr77/WindowPeek/issues"
    spacing: Style.space(20)
    signal troubleshootingRequested()
    function focusTroubleshooting(reason) {
        troubleshootingEntry.restoreFocus(typeof reason === "number" ? reason : Qt.OtherFocusReason);
    }
    function focusFirst() { reportButton.forceActiveFocus(); }

    ReadableText {
        objectName: "hintsSupportIntro"
        width: parent.width; text: root.words.hintsSupportHelp
        textFormat: Text.PlainText; wrapMode: Text.Wrap
        textColor: Color.popups.text; lineHeight: 1.2
        font.family: Style.font.family; font.pixelSize: Style.font.body + Style.space(1)
    }
    SettingsRow {
        id: reportButton; objectName: "reportIssueButton"
        width: parent.width; text: root.words.reportIssue
        description: root.words.reportIssueDescription
        externalLink: true
        accent: root.accent; bordered: true
        palette: root.hostWidget ? root.hostWidget.surfaces : null
        enabled: !BrowserLinks.busy
        onClicked: BrowserLinks.open(root.issuesUrl)
    }
    EditField {
        objectName: "supportLinkError"
        visible: BrowserLinks.failed && BrowserLinks.lastUrl === root.issuesUrl
        width: parent.width; readOnly: true; text: root.issuesUrl
        Accessible.name: root.words.browserOpenFailed
    }
    ReadableText {
        visible: BrowserLinks.failed && BrowserLinks.lastUrl === root.issuesUrl
        width: parent.width; text: root.words.browserOpenFailed
        textFormat: Text.PlainText; wrapMode: Text.Wrap
        textColor: Color.popups.text
        font.family: Style.font.family; font.pixelSize: Style.font.body
    }
    SettingsRow {
        id: troubleshootingEntry; objectName: "troubleshootingEntry"
        width: parent.width; text: root.words.troubleshooting
        description: root.words.troubleshootingSummary
        accent: root.accent; bordered: true
        palette: root.hostWidget ? root.hostWidget.surfaces : null
        onClicked: root.troubleshootingRequested()
    }
    ControlsHelp {
        objectName: "controlsHelp"
        width: parent.width; language: root.hostWidget ? root.hostWidget.language : "en"
        accent: root.accent
        doubleClickExpand: !!root.hostWidget && root.hostWidget.doubleClickExpand
        hostWidget: root.hostWidget
        shortcuts: root.hostWidget ? root.hostWidget.shortcuts : ({})
    }
}
