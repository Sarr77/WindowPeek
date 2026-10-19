import QtQuick
import qs.Commons
import qs.Commons as Commons
import "UpdateWords.js" as Copy

Column {
    id: root
    required property var hostWidget
    readonly property var updates: hostWidget ? hostWidget.runtime.updates : null
    readonly property var copy: Copy.words(hostWidget ? hostWidget.language : "en")
    readonly property var result: updates ? updates.manualResult : ({})
    readonly property color accent: hostWidget ? hostWidget.accent : Commons.Color.accent
    readonly property int descriptionFontSize: Style.font.title
    readonly property bool checking: !!updates && (updates.manualBusy || minimumCheck.running)
    readonly property bool available: !!updates && updates.manualAvailable
    readonly property bool skipped: !!updates && updates.manualSkipped
    readonly property bool installing: !!updates && updates.installing
    readonly property bool needsRecheck: result.installError === "local-changes"
    readonly property bool blocked: !!updates && updates.manualBlocked
    spacing: Style.space(10)
    signal installRequested()
    function focusFirst(reason) { (primaryButton.enabled ? primaryButton : changesButton)
        .forceActiveFocus(reason === undefined ? Qt.OtherFocusReason : reason); }
    // Stabilize fast feedback without delaying the asynchronous worker.
    Timer { id: minimumCheck; interval: 700 }
    Connections {
        target: root.updates
        function onManualBusyChanged() { if (root.updates.manualBusy) minimumCheck.restart(); }
    }
    Component.onCompleted: if (updates && updates.manualBusy) minimumCheck.start()
    function statusText() {
        if (updates && updates.filteredRelease) return copy.noVerified;
        switch (result.status) {
        case "available": return available ? (skipped ? copy.skipped : copy.available) + " · v" + result.version : copy.failed;
        case "current": return copy.current;
        case "no-verified": return copy.noVerified;
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
            width: parent.width; text: root.installing ? root.copy.installing : root.checking ? root.copy.checking : root.statusText()
            height: Math.max(implicitHeight, statusMeasure.implicitHeight)
            font.family: Style.font.family; font.pixelSize: root.descriptionFontSize
            textColor: Commons.Color.popups.text; textFormat: Text.PlainText; wrapMode: Text.Wrap
        }
        Text {
            id: statusMeasure; visible: false
            width: root.width; text: root.statusText(); font: statusLabel.font
            textFormat: Text.PlainText; wrapMode: Text.Wrap
        }
        Item {
            objectName: "manualUpdateVerification"
            visible: root.available; width: parent.width; height: verificationText.implicitHeight
            Rectangle {
                objectName: "manualUpdateVerificationDot"
                width: Style.space(8); height: width; radius: width / 2
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                color: root.result.verification === "verified" ? "#92D992" : "#EDB65C"
            }
            ReadableText {
                id: verificationText
                anchors.left: parent.left; anchors.leftMargin: Style.space(16)
                width: parent.width - Style.space(16)
                text: root.result.verification === "verified" ? root.copy.verified
                    : root.result.verification === "unverified" ? root.copy.unverified : root.copy.unknown
                font.family: Style.font.family; font.pixelSize: root.descriptionFontSize
                textColor: Commons.Color.popups.text; textFormat: Text.PlainText; wrapMode: Text.Wrap
            }
        }
        ReadableText {
            objectName: "manualUpdateTime"
            visible: !!root.result.lastCheck; width: parent.width
            text: (root.result.status === "failed" || root.blocked ? root.copy.attempted : root.copy.checked)
                + ": " + Qt.formatDateTime(new Date((root.result.lastCheck || 0) * 1000), "yyyy-MM-dd HH:mm")
            font.family: Style.font.family; font.pixelSize: root.descriptionFontSize
            textColor: Commons.Color.popups.text; textFormat: Text.PlainText; wrapMode: Text.Wrap
        }
    }
    ReadableText {
        visible: !!root.result.installError; width: parent.width
        text: root.result.installError === "restart-pending" ? root.copy.restartPending
            : root.needsRecheck ? root.copy.installLocal : root.copy.installFailed
        font.family: Style.font.family; font.pixelSize: root.descriptionFontSize
        textColor: root.result.installError === "restart-pending" ? Commons.Color.popups.text : Commons.Color.urgent
        textFormat: Text.PlainText; wrapMode: Text.Wrap
    }
    ReadableText {
        visible: !!root.updates && root.updates.choiceChanged
        width: parent.width; text: root.copy.choiceChanged
        font.family: Style.font.family; font.pixelSize: root.descriptionFontSize
        textColor: Commons.Color.popups.text; textFormat: Text.PlainText; wrapMode: Text.Wrap
    }
    Column {
        width: parent.width; spacing: Style.space(8)
        Grid {
            id: actionGrid
            width: parent.width
            columns: Math.max(primaryButton.implicitWidth, changesButton.implicitWidth) * 2
                + columnSpacing > width ? 1 : 2
            columnSpacing: Style.space(16); rowSpacing: Style.space(8)
            ActionButton {
                id: primaryButton; objectName: "primaryUpdateAction"
                width: actionGrid.columns === 1 ? actionGrid.width : Math.max(0, (actionGrid.width - actionGrid.columnSpacing) / 2)
                text: root.installing ? root.copy.refresh : root.needsRecheck ? root.copy.check
                    : root.available ? root.copy.install : root.copy.check
                fontSize: root.descriptionFontSize; accent: root.accent
                enabled: !!root.updates && !root.checking
                    && (!root.available || root.installing || root.needsRecheck || root.updates.manualCanUpdate)
                onClicked: if (root.available && !root.installing && !root.needsRecheck) root.installRequested(); else root.updates.checkNow()
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
            textColor: Commons.Color.popups.text; textFormat: Text.PlainText; wrapMode: Text.Wrap
        }
        ActionButton {
            objectName: "skipUpdateVersionAction"
            visible: root.available; enabled: !!root.hostWidget && !root.installing
            text: root.skipped ? root.copy.unskip : root.copy.skip
            textOnly: true; accent: root.accent; fontSize: Style.font.caption
            onClicked: if (root.hostWidget)
                root.hostWidget.persistSettings({skippedUpdateVersion: root.skipped ? "" : root.result.version,
                    skippedUpdateStage: root.skipped ? "" : root.updates.manualStage})
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
            textColor: Commons.Color.popups.text; textFormat: Text.PlainText; wrapMode: Text.Wrap
        }
    }
    Column {
        width: parent.width; spacing: Style.space(4)
        SettingsRow {
            objectName: "manualUpdateChecksToggle"
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            width: parent.width; text: root.hostWidget.words.updateNotifications; description: root.copy.checksHelp
            labelFontSize: root.descriptionFontSize
            descriptionFontSize: root.descriptionFontSize; descriptionColor: Commons.Color.popups.text
            accent: root.accent; isSwitch: true
            checked: root.hostWidget && root.hostWidget.preference("checkUpdates", true) === true
            onClicked: root.hostWidget.persistSettings({checkUpdates: !checked})
        }
        SettingsRow {
            objectName: "includeUnverifiedUpdatesToggle"
            palette: root.hostWidget ? root.hostWidget.surfaces : null
            width: parent.width; text: root.copy.earlyReleases; description: root.copy.earlyReleasesHelp
            labelFontSize: root.descriptionFontSize
            descriptionFontSize: root.descriptionFontSize; descriptionColor: Commons.Color.popups.text
            accent: root.accent; isSwitch: true
            checked: !!root.updates && root.updates.includeUnverified
            onClicked: root.hostWidget.persistSettings({includeUnverifiedUpdates: !checked})
        }
    }
}
