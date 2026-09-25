import QtQuick
import qs.Ui as Ui
import qs.Commons

FocusScope {
    id: root
    required property var recovery
    property bool opened: false
    property var closingPresentation: null
    function prepareClose() {
        if (!closingPresentation) closingPresentation = {actions:actionItems,
            title:heading.text, paragraphs:paragraphs.model, message:messageText.text};
    }
    property bool rtl: false
    LayoutMirroring.enabled: rtl
    LayoutMirroring.childrenInherit: true
    property color accent: Color.accent
    readonly property var copy: recovery ? recovery.copy : ({})
    property int selectedIndex: 0
    property bool choosingIgnore: false
    property bool confirmingPermanent: false
    property bool confirmationOnly: false
    readonly property bool sourceIdentified: !!recovery && !!recovery.offered
    readonly property bool manualEnabled: !!recovery && recovery.manualEnabled === true
    readonly property bool protectionEnabled: manualEnabled || (!!recovery && recovery.granted)
    readonly property string appName: sourceIdentified ? recovery.offered.app : recovery ? recovery.contextApp || recovery.protectionApp || "" : ""
    readonly property var actionItems: closingPresentation ? closingPresentation.actions : confirmingPermanent ? [
        {id:"cancelPermanentProtection", text:copy.cancel, action:"cancel"},
        {id:"confirmPermanentProtection", text:copy.confirmKeep, action:"confirm-keep"}
    ] : choosingIgnore ? [
        {id:"focusIgnoreBack", text:copy.ignoreBack, action:"back"},
        {id:"focusIgnoreSession", text:copy.ignoreSession, action:"session"},
        {id:"focusIgnoreApp", text:copy.ignoreApp, action:"app"},
        {id:"focusIgnoreAll", text:copy.ignoreAll, action:"all"}
    ] : sourceIdentified ? [
        {id:"declineFocusProtection", text:copy.cancel, action:"cancel"},
        {id:"approveFocusProtection", text:recovery && recovery.pendingApproval ? copy.checking : copy.allow, help:copy.dialogProtection, action:"approve"},
        {id:"keepFocusProtection", text:manualEnabled ? copy.disableKeep : copy.dialogKeep, help:copy.dialogKeepHelp, action:"keep"},
        {id:"focusIgnoreMenu", text:copy.ignoreMenu, action:"ignore"},
        {id:"focusTroubleshootingAction", text:copy.dialogDetails, action:"settings"}
    ] : protectionEnabled ? [
        {id:"declineFocusProtection", text:copy.cancel, action:"cancel"},
        {id:"keepFocusProtection", text:copy.disableKeep, help:manualEnabled ? copy.dialogKeepHelp : recovery.sessionProtection === true ? copy.dialogSessionProtection : copy.dialogProtection, action:"disable"},
        {id:"focusIgnoreMenu", text:copy.ignoreMenu, action:"ignore"},
        {id:"focusTroubleshootingAction", text:copy.dialogDetails, action:"settings"}
    ] : [
        {id:"declineFocusProtection", text:copy.cancel, action:"cancel"},
        {id:"approveFocusProtection", text:copy.allow, help:copy.dialogSessionProtection, action:"approve"},
        {id:"keepFocusProtection", text:manualEnabled ? copy.disableKeep : copy.dialogKeep, help:copy.dialogKeepHelp, action:"keep"},
        {id:"focusIgnoreMenu", text:copy.ignoreMenu, action:"ignore"},
        {id:"focusTroubleshootingAction", text:copy.dialogDetails, action:"settings"}
    ]
    onActionItemsChanged: selectedIndex = Math.min(selectedIndex, actionItems.length - 1)
    function activate(action) {
        if (closingPresentation) return;
        if (action === "cancel") cancel();
        else if (action === "approve" && recovery) {
            if (recovery.offered) recovery.approve();
            else recovery.enableSessionProtection();
        }
        else if (action === "keep") {
            if (manualEnabled) permanentRequested(false);
            else { confirmingPermanent=true; selectedIndex=0; details.contentY=0; }
        }
        else if (action === "confirm-keep") permanentRequested(true);
        else if (action === "disable") disableRequested();
        else if (action === "settings") troubleshootingRequested();
        else if (action === "back" || action === "ignore") { choosingIgnore = action === "ignore"; selectedIndex = 0; details.contentY = 0; }
        else if (recovery) recovery.ignore(action, function(ok) { if (ok) { opened = false; closed(); } });
    }
    implicitHeight: heading.implicitHeight + explanation.implicitHeight + actions.implicitHeight + Style.space(32)
    visible: opened
    signal closed()
    signal troubleshootingRequested()
    signal permanentRequested(bool enabled)
    signal disableRequested()
    Accessible.role: Accessible.Dialog
    Accessible.name: heading.text
    function open() { closingPresentation=null; choosingIgnore = false; confirmingPermanent=false; confirmationOnly=false; selectedIndex = 0; opened = true; details.contentY = 0; forceActiveFocus(); }
    function openPermanent() { open(); confirmingPermanent=true; confirmationOnly=true; }
    function cancel() {
        if (confirmingPermanent) {
            confirmingPermanent=false;
            if (confirmationOnly) { opened=false; closed(); }
            else { selectedIndex=0; details.contentY=0; }
            return;
        }
        if (recovery) { recovery.decline(); recovery.dismissSuggestion(); }
        opened = false; closed();
    }
    Keys.onPressed: function(event) {
        if (!opened) return;
        event.accepted = true;
        if (event.isAutoRepeat) return;
        if (event.key === Qt.Key_Escape) { if (choosingIgnore) activate("back"); else cancel(); }
        else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) selectedIndex = (selectedIndex + (event.key === Qt.Key_Backtab ? actionItems.length - 1 : 1)) % actionItems.length;
        else if (event.key === Qt.Key_PageDown) details.contentY = Math.max(0, Math.min(details.contentHeight - details.height, details.contentY + details.height * 0.8));
        else if (event.key === Qt.Key_PageUp) details.contentY = Math.max(0, details.contentY - details.height * 0.8);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            activate(actionItems[selectedIndex].action);
        }
    }
    // The enclosing panel supplies its wallpaper/glass/solid appearance.
    MouseArea { anchors.fill: parent; onClicked: {} onWheel: function(wheel) { wheel.accepted = true; } }
    ReadableText {
        id: heading; anchors.top: parent.top; width: parent.width
        text: root.closingPresentation ? root.closingPresentation.title : (root.confirmingPermanent ? root.copy.confirmKeepTitle : root.choosingIgnore ? root.copy.ignoreMenu : root.protectionEnabled ? root.copy.activeTitle : root.copy.title) || ""; textFormat: Text.PlainText; wrapMode: Text.Wrap
        font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true; textColor: Color.popups.text
    }
    Flickable {
        id: details; anchors { top: heading.bottom; topMargin: Style.space(16); bottom: actions.top; bottomMargin: Style.space(16); left: parent.left; right: parent.right }
        clip: true; contentHeight: explanation.implicitHeight; boundsBehavior: Flickable.StopAtBounds
        Column {
            id: explanation; width: parent.width; spacing: Style.space(14)
            Repeater {
                id: paragraphs
                model: root.closingPresentation ? root.closingPresentation.paragraphs : root.confirmingPermanent ? [root.copy.confirmKeepBehavior, root.copy.confirmKeepWhere] : root.choosingIgnore ? [root.copy.ignoreHelp] : root.protectionEnabled ? [
                    root.manualEnabled ? root.copy.activeManual : root.recovery.sessionProtection === true ? root.copy.activeSessionTemporary : root.copy.activeTemporary,
                    root.appName ? root.copy.dialogApp.replace("{app}", root.appName) : "",
                    root.copy.dialogCause || ""].filter(function(text) { return !!text; }) : root.sourceIdentified ? [
                    root.copy.dialogApp ? root.copy.dialogApp.replace("{app}", root.recovery && root.recovery.offered ? root.recovery.offered.app : "—") : "",
                    root.copy.dialogCause || ""] : [root.copy.dialogUnknown || "", root.copy.dialogUnknownHelp || ""]
                ReadableText {
                    required property string modelData
                    width: explanation.width; text: modelData; textFormat: Text.PlainText; wrapMode: Text.Wrap
                    font.family: Style.font.family; font.pixelSize: Style.font.body; textColor: Color.popups.text
                }
            }
            ReadableText {
                id: messageText
                width: parent.width; visible: text !== ""; text: root.closingPresentation ? root.closingPresentation.message : root.recovery ? root.recovery.message : ""
                textFormat: Text.PlainText; wrapMode: Text.Wrap; textColor: root.accent
                font.family: Style.font.family; font.pixelSize: Style.font.body
            }
        }
    }
    Column {
        id: actions; anchors { bottom: parent.bottom; left: parent.left; right: parent.right } spacing: Style.space(8)
        Repeater {
            model: root.actionItems
            Column {
                id: choice
                required property var modelData
                required property int index
                width: actions.width; spacing: Style.space(4)
                LabelButton {
                    objectName: choice.modelData.id; width: parent.width; label: choice.modelData.text || ""
                    accent: root.accent; hasCursor: root.selectedIndex === choice.index
                    bordered: choice.modelData.action === "approve" || choice.modelData.action === "keep" || choice.modelData.action === "disable" || choice.modelData.action === "confirm-keep"
                    enabled: !!root.recovery && (choice.modelData.action !== "approve" || ((!!root.recovery.offered || root.recovery.backendAvailable === true) && !root.recovery.pendingApproval))
                        && (choice.modelData.action !== "app" || (!!root.recovery.offered && !!root.recovery.offered.appKey))
                    Accessible.description: choice.modelData.help || ""
                    onClicked: root.activate(choice.modelData.action)
                }
                ReadableText {
                    width: parent.width; visible: text !== ""; text: choice.modelData.help || ""
                    textFormat: Text.PlainText; wrapMode: Text.Wrap
                    font.family: Style.font.family; font.pixelSize: Style.font.body
                    textColor: Qt.alpha(Color.popups.text, 0.8)
                }
            }
        }
    }
    BackMouseArea { enabled: root.opened; onClicked: if (root.choosingIgnore) root.activate("back"); else root.cancel() }
}
