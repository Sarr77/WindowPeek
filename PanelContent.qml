pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import qs.Ui as Ui
import qs.Commons
import "vendor/omarchy" as Choice
import "WindowModel.js" as Model
import "WindowListModel.js" as ListData
import "WindowCommands.js" as Commands
import "I18n.js" as I18n
import "WindowPreview.js" as Preview
import "Labels.js" as Labels
import "Settings.js" as Settings

FocusScope {
    id: root
    property var hostWidget: null
    property Item previewBoundsItem: root
    property real scrollbarGutter: Style.spacing.popupPadding
    property real maximumHeight: Infinity
    readonly property var words: hostWidget ? hostWidget.words : I18n.words("en")
    readonly property color accent: hostWidget ? hostWidget.accent : Color.accent
    readonly property bool rtl: hostWidget && hostWidget.language === "ar"
    readonly property bool compact: hostWidget && hostWidget.appearance.tooltipStyle === "compact"
    property alias searchField: search
    // A preview popup can own the active window while the source keeps local
    // focus. Follow that control so typing and successive arrows stay together.
    readonly property Item previewKeyTarget: !expanded ? root
        : search.focus ? search : list.focusedAction || root
    property string mode: "windows"
    property string settingsReturnMode: ""
    property real settingsScrollY: 0
    property bool opened: false
    property bool expanded: true
    property real expansion: expanded ? 1 : 0
    property bool showHint: !!hostWidget && hostWidget.hints.enabled
    property string orderAddress: ""
    readonly property bool controlHeld: shortcutModifiers.known && shortcutModifiers.controlDown
    readonly property var shortcutModifierState: shortcutModifiers
    readonly property bool shortcutsAvailable: opened && mode === "windows" && !busy
        && !confirmation.opened && !!hostWidget && !hostWidget.moveMenuOpen
    readonly property var shortcutAddresses: list.shortcutAddresses
    readonly property bool interacting: list.interacting
    readonly property bool backgroundToggleAllowed: opened && mode === "windows" && !busy && !interacting && !confirmation.opened
    readonly property real listContentHeight: list.contentHeight
    readonly property var preview: Preview.arrange(view, orderAddress)
    property alias contentY: list.contentY
    function resetScroll() { list.cancelFlick(); list.contentY = 0; }
    property string selectedAddress: ""
    property string moveAddress: ""
    property string destination: ""
    readonly property var inventory: hostWidget ? hostWidget.inventory : Model.normalize(null)
    readonly property var view: Model.search(inventory, search.text, { includeSpecial: hostWidget && hostWidget.includeSpecial })
    readonly property var matches: preview.sections.reduce(function(all, section) { return all.concat(section.windows); }, [])
    readonly property var rows: ListData.rows(preview)
    readonly property var destinations: hostWidget ? Commands.destinations(hostWidget.snapshot, moveAddress, hostWidget.includeSpecial) : []
    readonly property var moveWindow: inventory.windows.find(function(window) { return window.address === root.moveAddress; })
    readonly property bool canMoveToScratchpad: !!moveWindow && !!moveWindow.workspace
        && moveWindow.workspace.name !== "special:scratchpad" && !busy
    readonly property bool busy: hostWidget && hostWidget.actionBusy
    readonly property bool editing: mode === "appearance" || mode === "scaling" || mode === "labels"
    readonly property real listChromeHeight: header.implicitHeight + list.anchors.topMargin
        + list.anchors.bottomMargin + footer.implicitHeight
    implicitHeight: mode === "windows" ? listChromeHeight
            + list.fittedHeight(Style.space(420), Math.max(0, maximumHeight - listChromeHeight), Style.space(44))
        : mode === "move" ? header.implicitHeight + Style.space(24) + footer.implicitHeight
            + Math.max(moveForm.implicitHeight, destinationPicker.popupOpen
                ? destinationPicker.y + destinationPicker.height + Style.space(4) + destinationPicker.preferredPopupHeight : 0)
        : mode === "settings" ? Style.space(640)
        : Style.space(540)
    signal closeRequested()
    signal backgroundClicked()
    ShortcutModifiers { id: shortcutModifiers; active: root.shortcutsAvailable }
    property var activateWindow: function(address, bringHere) {
        if (!opened || !hostWidget || busy || !matches.some(function(window) { return window.address === address; })) return;
        if (bringHere) hostWidget.bringWindow(address); else hostWidget.focusWindow(address);
    }

    onMatchesChanged: {
        if (selectedAddress && !matches.some(function(window) { return window.address === root.selectedAddress; })) selectedAddress = "";
    }
    onDestinationsChanged: {
        if (destination && !destinations.some(function(item) { return item.value === root.destination; })) destination = "";
    }
    function begin(takeFocus) {
        if (takeFocus === undefined) takeFocus = true;
        opened = true;
        shortcutModifiers.reset();
        if (!takeFocus) { search.focus = false; focus = false; }
        mode = "windows"; search.text = ""; selectedAddress = "";
        var first = inventory.windows.find(function(window) { return window.active; });
        orderAddress = first ? first.address : "";
        list.cancelFlick(); list.positionViewAtBeginning();
        Qt.callLater(function() {
            var active = root.matches.find(function(window) { return window.active; });
            root.selectedAddress = active ? active.address : root.matches.length ? root.matches[0].address : "";
            list.positionViewAtBeginning();
            if (takeFocus && root.mode === "windows") search.forceActiveFocus();
        });
    }
    function promote() {
        opened = true;
        Qt.callLater(function() { if (root.mode === "windows") search.forceActiveFocus(); });
    }
    function demote() {
        list.cancelFlick();
        search.focus = false;
        focus = false;
        if (search.text) {
            search.text = "";
            list.positionViewAtBeginning();
        }
    }
    function dismiss() {
        opened = false;
        list.cancelFlick();
        appearance.closePickers(); settingsContent.closePickers(); destinationPicker.close();
        labelsEditor.closePickers();
        confirmation.opened = false;
        if (hostWidget) { hostWidget.cancelAppearance(); hostWidget.cancelLabels(); }
        mode = "windows";
    }
    function showSettings() {
        settingsReturnMode = ""; settingsScrollY = 0;
        mode = "settings"; editorScroll.cancelFlick(); editorScroll.contentY = 0;
        settingsContent.begin();
        Qt.callLater(function() { settingsContent.focusLanguage(); });
    }
    function returnToSettings() {
        mode = "settings";
        Qt.callLater(function() {
            editorColumn.forceLayout();
            editorScroll.cancelFlick();
            editorScroll.contentY = Math.min(settingsScrollY, Math.max(0, editorScroll.contentHeight - editorScroll.height));
            if (settingsReturnMode) settingsContent.focusEditor(settingsReturnMode);
            else settingsContent.focusLanguage();
        });
    }
    function back() {
        var returnToSettings = editing;
        if (editing && hostWidget) { hostWidget.cancelAppearance(); hostWidget.cancelLabels(); }
        appearance.closePickers(); destinationPicker.close(); settingsContent.closePickers();
        labelsEditor.closePickers();
        if (returnToSettings) root.returnToSettings();
        else { mode = "windows"; search.forceActiveFocus(); }
    }
    function navigateBack() {
        if (confirmation.opened) confirmation.cancel();
        else if (mode === "windows") closeRequested();
        else back();
    }
    function openMove(address) {
        if (!hostWidget || busy || !inventory.windows.some(function(window) { return window.address === address; })) return;
        if (hostWidget.windowPreview) hostWidget.windowPreview.dismiss();
        moveAddress = address; destination = ""; hostWidget.clearError(); mode = "move";
        editorScroll.contentY = 0;
        Qt.callLater(function() { if (root.opened && root.mode === "move") destinationPicker.open(); });
    }
    function moveToScratchpad() {
        if (!canMoveToScratchpad) return;
        destinationPicker.close();
        hostWidget.moveWindow(moveAddress, "special:scratchpad");
    }
    function moveSelection(delta) {
        if (!matches.length) { selectedAddress = ""; return; }
        var index = matches.findIndex(function(window) { return window.address === root.selectedAddress; });
        index = index < 0 ? (delta > 0 ? 0 : matches.length - 1) : Math.max(0, Math.min(matches.length - 1, index + delta));
        selectedAddress = matches[index].address;
        var row = rows.findIndex(function(item) { return item.kind === "window" && item.address === root.selectedAddress; });
        list.ensureRowVisible(row);
    }
    function handleSearchKey(event) {
        updateControl(event, true);
        if (handleWindowShortcut(event)) return;
        var towardMove = event.key === (rtl ? Qt.Key_Left : Qt.Key_Right);
        var atTextEdge = search.cursorPosition === (rtl ? 0 : search.text.length);
        if (towardMove && event.modifiers === Qt.NoModifier && atTextEdge && !search.selectedText) {
            // At the text edge, continue into the selected row's action column.
            // Inside the query or with a selection, keep normal text editing.
            event.accepted = list.focusAction(selectedAddress, true);
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
            moveSelection(event.key === Qt.Key_Down ? 1 : -1); event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (selectedAddress && hostWidget && !busy) {
                if (event.modifiers & Qt.ShiftModifier) openMove(selectedAddress);
                else hostWidget.focusWindow(selectedAddress);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) { closeRequested(); event.accepted = true; }
    }
    function handleWindowShortcut(event) {
        if (!opened || mode !== "windows" || confirmation.opened
                || !hostWidget || hostWidget.moveMenuOpen) return false;
        var modifiers = event.modifiers & ~Qt.KeypadModifier;
        if (modifiers !== Qt.ControlModifier || event.key < Qt.Key_0 || event.key > Qt.Key_9) return false;
        event.accepted = true;
        if (busy || event.isAutoRepeat) return true;
        var index = event.key === Qt.Key_0 ? 9 : event.key - Qt.Key_1;
        var address = list.visibleWindowAddresses()[index];
        if (address) hostWidget.focusWindow(address);
        return true;
    }
    function updateControl(event, pressed) {
        shortcutModifiers.key(event, pressed);
    }
    function ensureVisible(item) {
        editorColumn.forceLayout();
        editorScroll.cancelFlick();
        reveal(item, editorScroll);
    }
    function reveal(item, viewport) {
        var top = item.mapToItem(viewport.contentItem, 0, 0).y;
        var next = viewport.contentY;
        if (top < next || item.height > viewport.height) next = top;
        else if (top + item.height > next + viewport.height) next = top + item.height - viewport.height;
        viewport.contentY = Math.max(0, Math.min(next, Math.max(0, viewport.contentHeight - viewport.height)));
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() {
            var focused = root.Window.window ? root.Window.window.activeFocusItem : null;
            for (var item = focused; item; item = item.parent) {
                if (list.visible && item === list.contentItem) { root.reveal(focused, list); return; }
                if (editorScroll.visible && item === editorScroll.contentItem) { root.reveal(focused, editorScroll); return; }
            }
        }
    }
    Keys.onEscapePressed: function(event) { if (mode === "windows") closeRequested(); else back(); event.accepted = true; }
    Keys.onPressed: function(event) { updateControl(event, true); handleWindowShortcut(event); }
    Keys.onReleased: function(event) { updateControl(event, false); }
    Connections { target: root.hostWidget; function onMoveCompleted() { if (root.mode === "move") root.back(); } }
    LayoutMirroring.enabled: rtl
    LayoutMirroring.childrenInherit: true

    Column {
        id: header; objectName: "panelHeader"; width: parent.width; spacing: Style.space(10) * root.expansion
        Item {
            width: parent.width; height: Style.space(29)
            Text {
                width: parent.width - Math.max(settingsButton.width, countBadge.width) - Style.space(8)
                text: root.mode === "windows" ? (root.hostWidget ? root.hostWidget.textTemplates.panelTitle : "WindowPeek")
                    : root.mode === "move" ? root.words.moveTo : root.mode === "labels" ? I18n.words(root.hostWidget.language).labels : root.words.settings
                textFormat: Text.PlainText; elide: Text.ElideRight
                color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            LabelButton {
                id: settingsButton; objectName: "settingsButton"
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width * 0.4)
                opacity: root.expansion; enabled: root.expanded
                label: root.mode === "windows" ? root.words.settings : root.words.back
                accent: root.accent; focusable: true
                onClicked: root.mode === "windows" ? root.showSettings() : root.back()
                TextMetrics {
                    id: headerActionMetrics
                    text: settingsButton.text
                    font.family: settingsButton.fontFamily
                    font.pixelSize: settingsButton.fontSize
                    font.bold: settingsButton.selected
                }
            }
            Rectangle {
                id: countBadge
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(countText.implicitWidth + Style.space(16), parent.width * 0.4)
                height: Style.space(27); radius: Style.space(5)
                color: Qt.alpha(root.accent, 0.09); opacity: 1 - root.expansion
                Text {
                    id: countText; anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - Style.space(16)); elide: Text.ElideRight
                    text: root.hostWidget ? Labels.render(root.hostWidget.textTemplates.windowCount, {count: root.matches.length}) : String(root.matches.length)
                    textFormat: Text.PlainText; color: root.accent
                    font.family: Style.font.family; font.pixelSize: Style.font.caption
                }
            }
        }
        Item {
            width: parent.width
            height: search.implicitHeight * root.expansion
            visible: root.mode === "windows"
            clip: true
            Ui.TextField {
                id: search; objectName: "windowSearch"
                opacity: root.expansion; enabled: root.expanded; width: parent.width
                placeholderText: root.words.searchWindows; accent: root.accent
                Accessible.name: root.words.searchWindows
                onTextEdited: {
                    if (!root.matches.some(function(window) { return window.address === root.selectedAddress; }))
                        root.selectedAddress = root.matches.length ? root.matches[0].address : "";
                    list.cancelFlick(); list.positionViewAtBeginning();
                }
                Keys.onPressed: function(event) { root.handleSearchKey(event); }
                Keys.onReleased: function(event) { root.updateControl(event, false); }
            }
        }
    }

    WindowList {
        id: list
        hostWidget: root.hostWidget
        rows: root.rows
        expanded: root.expanded; expansion: root.expansion
        opened: root.opened; selectedAddress: root.selectedAddress
        showShortcuts: root.controlHeld && root.shortcutsAvailable
        previewBoundsItem: root.previewBoundsItem
        scrollbarGutter: root.scrollbarGutter
        anchors.top: header.bottom; anchors.topMargin: Style.space(10)
        anchors.bottom: footer.top; anchors.bottomMargin: Style.space(12)
        visible: root.mode === "windows" && root.matches.length > 0
        onFocusRequested: function(address) { root.activateWindow(address, false); }
        onBringRequested: function(address) { root.activateWindow(address, true); }
        onMoveRequested: function(address) { root.openMove(address); }
        onActionFocused: function(address) { root.selectedAddress = address; }
        onNavigateRequested: function(address, delta, moveAction) {
            root.selectedAddress = address;
            root.moveSelection(delta);
            list.focusAction(root.selectedAddress, moveAction);
        }
        onBackgroundClicked: root.backgroundClicked()
    }

    Text {
        anchors.centerIn: list; width: root.width - Style.space(28)
        visible: root.mode === "windows" && root.matches.length === 0
        text: root.inventory.status !== "ready" ? root.words.unavailable
            : root.inventory.windows.length ? root.words.noMatches : root.words.emptyWindows
        textFormat: Text.PlainText; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
        color: Qt.alpha(Color.popups.text, 0.7); font.pixelSize: Style.font.body; font.family: Style.font.family
    }

    Item {
        id: settingsBranding; objectName: "settingsBranding"
        x: editorScroll.x; y: editorScroll.y
        width: editorScroll.width; height: editorScroll.height
        visible: root.mode === "settings"
        clip: true
        // Keep the mark stationary; content covers it as sections expand or scroll.
        Item {
            id: uncoveredSettings; objectName: "uncoveredSettings"
            y: Math.max(0, settingsContent.height - editorScroll.contentY + Style.space(16))
            width: parent.width; height: Math.max(0, parent.height - y)
            visible: height > 0
            clip: true
            Choice.OmarchyLogo {
                objectName: "settingsOmarchyLogo"
                anchors.horizontalCenter: parent.horizontalCenter
                y: settingsBranding.height - height - Style.space(48) - parent.y
                width: Math.min(parent.width * 0.72, Style.space(324))
                height: width * 285 / 1215
                color: Qt.alpha(root.accent, 0.16)
            }
        }
    }

    Flickable {
        id: editorScroll; objectName: "editorScroll"
        anchors.top: header.bottom; anchors.topMargin: Style.space(12)
        anchors.bottom: footer.top; anchors.bottomMargin: Style.space(12)
        width: parent.width; clip: true
        visible: root.mode !== "windows"
        contentHeight: editorColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        QQC.ScrollBar.vertical: ScrollHandle {
            parent: root
            visible: editorScroll.visible && size < 1 && policy !== QQC.ScrollBar.AlwaysOff
            x: root.rtl ? -(root.scrollbarGutter + width) / 2 : root.width + (root.scrollbarGutter - width) / 2
            y: editorScroll.y; height: editorScroll.height; accent: root.accent
        }
        Column {
            id: editorColumn; width: parent.width; spacing: Style.space(12)
            SettingsContent {
                id: settingsContent
                visible: root.mode === "settings"; width: parent.width
                hostWidget: root.hostWidget
                onOpenEditor: function(mode) {
                    root.settingsReturnMode = mode;
                    root.settingsScrollY = editorScroll.contentY;
                    closePickers();
                    root.mode = mode;
                    editorScroll.cancelFlick();
                    editorScroll.contentY = 0;
                }
                onEnsureVisible: function(item) { root.ensureVisible(item); }
            }
            Loader {
                id: appearance
                width: parent.width
                active: root.mode === "appearance"; visible: active
                onLoaded: item.begin()
                function closePickers() { if (item && item.closePickers) item.closePickers(); }
                sourceComponent: AppearanceEditor {
                    hostWidget: root.hostWidget
                    onFinished: root.returnToSettings()
                    onEnsureVisible: function(item) { root.ensureVisible(item); }
                }
            }
            Loader {
                id: scaling
                width: parent.width
                active: root.mode === "scaling"; visible: active
                onLoaded: item.begin()
                function closePickers() { if (item && item.closePickers) item.closePickers(); }
                sourceComponent: ScalingEditor {
                    hostWidget: root.hostWidget
                    onFinished: root.returnToSettings()
                    onEnsureVisible: function(item) { root.ensureVisible(item); }
                }
            }
            Loader {
                id: labelsEditor
                width: parent.width
                active: root.mode === "labels"; visible: active
                onLoaded: item.begin()
                function closePickers() { if (item && item.closePickers) item.closePickers(); }
                sourceComponent: LabelsEditor {
                    objectName: "labelsEditor"
                    hostWidget: root.hostWidget
                    onFinished: root.returnToSettings()
                    onEnsureVisible: function(item) { root.ensureVisible(item); }
                }
            }
            Column {
                id: moveForm
                width: parent.width; visible: root.mode === "move"; spacing: Style.space(12)
                Text {
                    width: parent.width; text: root.moveWindow ? root.moveWindow.app + "\n" + root.moveWindow.title : root.words.windowClosed
                    textFormat: Text.PlainText; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                    color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body
                }
                Text {
                    objectName: "moveSource"
                    readonly property var workspace: root.moveWindow ? root.moveWindow.workspace : null
                    width: parent.width
                    text: I18n.format(root.words.moveFrom, {workspace: I18n.workspaceTitle(workspace ? workspace.name : "", root.words)})
                        + (workspace && workspace.monitor ? " · " + workspace.monitor.name : "")
                    textFormat: Text.PlainText; wrapMode: Text.Wrap
                    color: Qt.alpha(Color.popups.text, 0.7)
                    font.family: Style.font.family; font.pixelSize: Style.font.caption
                }
                LabelButton {
                    objectName: "moveToScratchpad"
                    width: parent.width
                    label: root.words.moveToScratchpad
                    accent: root.accent; bordered: true; focusable: true
                    enabled: root.canMoveToScratchpad
                    onClicked: root.moveToScratchpad()
                }
                Choice.SearchableDropdown {
                    id: destinationPicker; objectName: "destinationPicker"
                    width: parent.width; label: root.words.moveTo; accent: root.accent
                    uiScale: root.hostWidget ? root.hostWidget.uiScale : 1
                    value: root.destination
                    options: root.destinations.map(function(item) {
                        return {value: item.value, label: I18n.workspaceTitle(item.name, root.words), description: item.monitor};
                    })
                    placeholderText: root.words.moveTo; emptyText: root.words.noMatches
                    onChanged: function(value) { root.destination = value; }
                }
                LabelButton {
                    objectName: "confirmMove"; width: parent.width; label: root.words.moveNow
                    accent: root.accent; bordered: true; focusable: true
                    enabled: !!root.moveWindow && !!root.destination && !root.busy
                    onClicked: root.hostWidget.moveWindow(root.moveAddress, root.destination)
                }
                Text {
                    width: parent.width; text: root.words.moveHint
                    textFormat: Text.PlainText; wrapMode: Text.Wrap
                    color: Qt.alpha(Color.popups.text, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption
                }
            }
        }
    }
    Column {
        id: footer; objectName: "panelFooter"; width: parent.width; anchors.bottom: parent.bottom; spacing: Style.space(9)
        Rectangle { width: parent.width; height: 1; color: Qt.alpha(Color.popups.text, 0.1) }
        Text {
            width: parent.width; visible: !!root.hostWidget && (!!root.hostWidget.actionError || root.hostWidget.saveFailed)
            text: root.hostWidget && root.hostWidget.saveFailed ? root.words.settingsError
                : root.hostWidget ? (root.words[root.hostWidget.actionError] || root.words.actionFailed) : ""
            textFormat: Text.PlainText; wrapMode: Text.Wrap; color: Color.urgent; font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
        Item {
            width: parent.width
            height: Style.space(26) * root.expansion + (root.showHint ? hoverHint.implicitHeight : 0) * (1 - root.expansion)
            Text {
                id: hoverHint
                width: parent.width; opacity: root.showHint ? 1 - root.expansion : 0
                text: root.words.focusHint + "\n" + root.words.chooseMoveHint + "\n" + root.words.bringHint + "\n" + root.words.openSearchHint
                textFormat: Text.PlainText; wrapMode: Text.Wrap
                color: Qt.alpha(Color.popups.text, 0.6)
                font.family: Style.font.family; font.pixelSize: Style.font.caption
            }
            Row {
                objectName: "footerTools"
                opacity: root.expansion; visible: root.expansion > 0; enabled: root.expanded
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(10)
                HintsToggle {
                    objectName: "hintsToggle"; words: root.words; focusable: true; accent: root.accent
                    hintsEnabled: root.hostWidget ? root.hostWidget.hints.enabled : true
                    automatic: root.hostWidget ? root.hostWidget.hints.mode === "auto" : true
                    remaining: root.hostWidget ? root.hostWidget.hints.remaining : Settings.hintLimit
                    onClicked: if (root.hostWidget) root.hostWidget.toggleHints()
                }
                UpdateSwitch {
                    id: updateSwitch; objectName: "updateSwitch"; text: root.words.autoUpdates; accent: root.accent
                    checked: root.hostWidget && root.hostWidget.autoUpdates && root.hostWidget.updatesAvailable
                    onClicked: {
                        if (!root.hostWidget || !root.hostWidget.updatesAvailable) return;
                        if (root.hostWidget.autoUpdates) confirmation.open(); else root.hostWidget.toggleUpdates();
                    }
                    PanelHint {
                        hostWidget: root.hostWidget; alwaysAvailable: true; requested: updateSwitch.pointerHovered
                        text: root.hostWidget && root.hostWidget.updatesAvailable ? root.words.autoUpdatesHint : root.words.updatesUnavailable
                    }
                }
            }
            AuthorCredit {
                objectName: "authorCredit"
                opacity: root.expansion; visible: root.expansion > 0
                anchors.right: parent.right
                // Align the footer text with the header label inside its button.
                anchors.rightMargin: Math.max(0, Math.round((settingsButton.width - headerActionMetrics.advanceWidth) / 2))
                anchors.verticalCenter: parent.verticalCenter
                text: "by Sarr"
            }
        }
    }
    BackMouseArea {
        enabled: root.opened
        z: 5
        onClicked: root.navigateBack()
    }
    UpdateConfirmation {
        id: confirmation; anchors.fill: parent; z: 10; words: root.words; rtl: root.rtl; accent: root.accent
        onCanceled: updateSwitch.forceActiveFocus()
        onConfirmed: { if (root.hostWidget) root.hostWidget.persistSettings({ autoUpdates: false }); updateSwitch.forceActiveFocus(); }
    }
}
