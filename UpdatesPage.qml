import QtQuick
import qs.Commons
import "UpdateWords.js" as Copy

Column {
    id: root
    required property var hostWidget
    readonly property var updates: hostWidget ? hostWidget.runtime.updates : null
    readonly property var copy: Copy.words(hostWidget ? hostWidget.language : "en")
    readonly property var result: updates ? updates.manualResult : ({})
    readonly property color accent: hostWidget ? hostWidget.accent : Color.accent
    readonly property int descriptionFontSize: Style.font.title
    readonly property bool checking: !!updates && (updates.manualBusy || minimumCheck.running)
    readonly property bool available: !!updates && updates.manualAvailable
    readonly property bool blocked: !!updates && updates.manualBlocked
    spacing: Style.space(20)
    signal toggleAutomatic()
    function focusFirst() { (primaryButton.enabled ? primaryButton : changesButton).forceActiveFocus(Qt.OtherFocusReason); }
    function focusAutomatic(reason) { automaticToggle.restoreFocus(reason); }
    // Stabilize fast feedback without delaying the asynchronous worker.
    Timer { id: minimumCheck; interval: 700 }
    Connections {
        target: root.updates
        function onManualBusyChanged() { if (root.updates.manualBusy) minimumCheck.restart(); }
    }
    Component.onCompleted: if (updates && updates.manualBusy) minimumCheck.start()
    function statusText() {
        switch (result.status) {
        case "available": return available ? copy.available + " · v" + result.version : copy.failed;
        case "current": return copy.current;
        case "ahead": return copy.ahead;
        case "local-changes": return result.reason === "development" ? copy.development : copy.local;
        case "failed": return copy.failed;
        default: return copy.unchecked;
        }
    }
    Column {
        width: parent.width; spacing: Style.space(8)
        ReadableText {
            id: statusLabel; objectName: "manualUpdateStatus"
            width: parent.width; text: root.checking ? root.copy.checking : root.statusText()
            height: Math.max(implicitHeight, statusMeasure.implicitHeight)
            font.family: Style.font.family; font.pixelSize: root.descriptionFontSize
            textColor: Color.popups.text; textFormat: Text.PlainText; wrapMode: Text.Wrap
        }
        Text {
            id: statusMeasure; visible: false
            width: root.width; text: root.statusText(); font: statusLabel.font
            textFormat: Text.PlainText; wrapMode: Text.Wrap
        }
        ReadableText {
            objectName: "manualUpdateVerification"
            visible: root.available; width: parent.width
            text: root.result.verification === "verified" ? root.copy.verified
                : root.result.verification === "unverified" ? root.copy.unverified : root.copy.unknown
            font.family: Style.font.family; font.pixelSize: root.descriptionFontSize
            textColor: Color.popups.text; textFormat: Text.PlainText; wrapMode: Text.Wrap
        }
        ReadableText {
            objectName: "manualUpdateTime"
            visible: !!root.result.lastCheck; width: parent.width
            text: (root.result.status === "failed" || root.blocked ? root.copy.attempted : root.copy.checked)
                + ": " + Qt.formatDateTime(new Date((root.result.lastCheck || 0) * 1000), "yyyy-MM-dd HH:mm")
            font.family: Style.font.family; font.pixelSize: root.descriptionFontSize
            textColor: Color.popups.text; textFormat: Text.PlainText; wrapMode: Text.Wrap
        }
    }
    Column {
        width: parent.width; spacing: Style.space(8)
        Row {
            width: parent.width; spacing: Style.space(16)
            ActionButton {
                id: primaryButton; objectName: "primaryUpdateAction"
                width: Math.max(0, (parent.width - parent.spacing) / 2)
                text: root.available ? root.copy.install : root.copy.check
                fontSize: root.descriptionFontSize; accent: root.accent
                enabled: !!root.updates && !root.checking && (!root.available || root.updates.manualCanUpdate)
                onClicked: if (root.available) root.updates.openManualUpdate(); else root.updates.checkNow()
            }
            ActionButton {
                id: changesButton; objectName: "viewUpdateChanges"
                width: primaryButton.width
                text: root.available ? root.copy.changes : root.copy.history
                fontSize: root.descriptionFontSize; accent: root.accent
                enabled: !!root.updates && !BrowserLinks.busy
                onClicked: BrowserLinks.open(root.updates.changesUrl())
                PanelHint {
                    hostWidget: root.hostWidget; anchorItem: changesButton
                    requested: changesButton.hot; text: root.copy.changesHelp
                }
            }
        }
        ReadableText {
            objectName: "manualUpdateHelp"
            visible: root.available; width: parent.width; text: root.copy.explain
            font.family: Style.font.family; font.pixelSize: root.descriptionFontSize
            textColor: Color.popups.text; textFormat: Text.PlainText; wrapMode: Text.Wrap
        }
        ReadableText {
            visible: !!root.updates && root.updates.manualLaunchFailed
            width: parent.width; text: root.copy.launchFailed
            font.family: Style.font.family; font.pixelSize: root.descriptionFontSize
            textColor: Color.popups.text; textFormat: Text.PlainText; wrapMode: Text.Wrap
        }
        EditField {
            visible: BrowserLinks.failed && !!root.updates && BrowserLinks.lastUrl === root.updates.changesUrl()
            width: parent.width; readOnly: true; text: BrowserLinks.lastUrl
            Accessible.name: root.hostWidget.words.browserOpenFailed
        }
        ReadableText {
            visible: BrowserLinks.failed && !!root.updates && BrowserLinks.lastUrl === root.updates.changesUrl()
            width: parent.width; text: root.hostWidget.words.browserOpenFailed
            font.family: Style.font.family; font.pixelSize: root.descriptionFontSize
            textColor: Color.popups.text; textFormat: Text.PlainText; wrapMode: Text.Wrap
        }
    }
    SettingsRow {
        objectName: "manualUpdateChecksToggle"
        palette: root.hostWidget ? root.hostWidget.surfaces : null
        width: parent.width; text: root.hostWidget.words.updateNotifications; description: root.copy.checksHelp
        labelFontSize: root.descriptionFontSize
        descriptionFontSize: root.descriptionFontSize; descriptionColor: Color.popups.text
        accent: root.accent; isSwitch: true
        checked: root.hostWidget && root.hostWidget.preference("checkUpdates", true) === true
        onClicked: root.hostWidget.persistSettings({checkUpdates: !checked})
    }
    SettingsRow {
        id: automaticToggle; objectName: "automaticUpdatesToggle"
        palette: root.hostWidget ? root.hostWidget.surfaces : null
        width: parent.width; text: root.hostWidget.words.autoUpdates
        description: root.hostWidget.updatesAvailable ? root.copy.autoHelp : root.hostWidget.words.updatesUnavailable
        labelFontSize: root.descriptionFontSize
        descriptionFontSize: root.descriptionFontSize; descriptionColor: Color.popups.text
        accent: root.accent; isSwitch: true
        enabled: root.hostWidget.updatesAvailable
        checked: root.hostWidget.autoUpdates && root.hostWidget.updatesAvailable
        onClicked: root.toggleAutomatic()
    }
}
