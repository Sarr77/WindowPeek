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
import "Shortcuts.js" as Shortcuts

FocusScope {
    id: root
    property var hostWidget: null
    property var recovery: null
    property bool protectionPaused: false
    property alias recoveryOpen: recoveryDialog.opened
    property real reviewScrollY: 0
    property real confirmationEditorScrollY: 0
    property var troubleshootingReturn: ({mode:"windows", review:false, scroll:0})
    onRecoveryOpenChanged: {
        if (recoveryOpen && hostWidget && hostWidget.windowPreview) hostWidget.windowPreview.dismiss();
        else if (!recoveryOpen) restoreSearchView(reviewScrollY);
    }
    function restoreSearchView(scroll) {
        Qt.callLater(function() {
            if (!root.opened || root.mode !== "windows" || root.recoveryOpen) return;
            list.cancelFlick(); list.contentY = Math.max(0, Math.min(scroll, list.contentHeight - list.height));
            search.forceActiveFocus();
        });
    }
    function confirmPermanentProtection() {
        confirmationEditorScrollY = editorScroll.contentY;
        recoveryDialog.openPermanent();
    }
    function restoreAfterReview() {
        if (mode === "windows") restoreSearchView(reviewScrollY);
        else Qt.callLater(function() {
            editorScroll.cancelFlick();
            editorScroll.contentY = Math.max(0, Math.min(root.confirmationEditorScrollY, editorScroll.contentHeight-editorScroll.height));
        });
    }
    function openRecovery(scroll) {
        reviewScrollY = typeof scroll === "number" ? scroll : list.contentY;
        recoveryDialog.open();
    }
    function rememberTroubleshootingOrigin() {
        troubleshootingReturn = {mode:mode, review:recoveryOpen,
            scroll: mode === "windows" ? (recoveryOpen ? reviewScrollY : list.contentY) : editorScroll.contentY};
    }
    readonly property bool recoveryOffered: !!recovery && !!recovery.offered && recovery.panel && recovery.panel.body === root
    // Freeze presentation only. Recovery must still release keyboard ownership
    // immediately; its teardown must not rewrite an already fading notice.
    property var closingFocusNotice: null
    readonly property var liveFocusNotice: {
        var r = recovery;
        if (!r) return {shown:false, text:"", label:"", attention:false};
        var failed = r.protectionFailed === true;
        var stopped = (recoveryOffered && r.offeringStopped === true) || r.sessionProtectionStopped === true;
        var attention = failed || (!stopped && (recoveryOffered || r.suggested || r.interrupted));
        var app = stopped ? (r.offered ? r.offered.app : "") : r.manualEnabled ? r.contextApp : r.protectionApp;
        var appSuffix = app ? " (" + app.replace(/^.*\(([^()]*)\)$/, "$1") + ")" : "";
        return {
            shown: r.granted || stopped || attention,
            text: failed ? (r.retrying ? r.copy.recoveryRetrying : r.copy.recoveryPaused) : stopped ? r.copy.disabled + appSuffix : recoveryOffered ? r.copy.notice : r.manualRequested ? r.copy.manualEnabled + appSuffix
                : r.suggested ? r.copy.repeated : r.interrupted ? r.copy.notice
                : (protectionPaused ? r.copy.paused : r.copy.enabled)
                    + (r.granted ? appSuffix : ""),
            label: failed ? r.copy.retry : attention ? r.copy.review : r.copy.options,
            canDisable: r.manualEnabled === true || r.granted,
            stopLabel: r.copy.stop,
            attention: attention
        };
    }
    readonly property var focusNotice: closingFocusNotice || liveFocusNotice
    function disableProtection(done) {
        if (!recovery) { if (done) done(false); return false; }
        function stopped(ok) { if (ok) recovery.stop("user"); if (done) done(ok); }
        if (recovery.manualEnabled) {
            if (!hostWidget) { stopped(false); return false; }
            return hostWidget.persistSettings({keepSearchFocus:false}, stopped);
        }
        stopped(true);
        return true;
    }
    property real closingHeight: -1
    property var closingExpanded: null
    function prepareClose() {
        if (!closingFocusNotice) closingFocusNotice = liveFocusNotice;
        if (closingHeight < 0) closingHeight = implicitHeight;
        if (closingExpanded === null) closingExpanded = expanded;
        if (recoveryOpen) recoveryDialog.prepareClose();
    }
    function finishDismiss() {
        recoveryOpen = false;
        recoveryDialog.closingPresentation = null;
        mode = "windows";
        closingHeight = -1;
        closingExpanded = null;
    }
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
    readonly property Item previewKeyTarget: search.focus ? search : list.focusedAction || root
    property string mode: "windows"
    property bool settingsVisit: false
    onModeChanged: {
        if (mode === "windows" || mode === "move") settingsVisit = false;
        else if (mode === "settings") settingsVisit = true;
    }
    onOpenedChanged: if (!opened) settingsVisit = false
    property string settingsReturnMode: ""
    property real settingsScrollY: 0
    property real mainScrollY: 0
    property bool opened: false
    property bool expanded: true
    property bool compactPinned: false
    property bool barLabelHovered: false
    property real expansion: expanded ? 1 : 0
    property bool showHint: !!hostWidget && hostWidget.hints.enabled
    property bool outerBackgroundHovered: false
    property bool pointerInsidePanel: contentPointer.hovered
    HoverHandler { id: contentPointer; blocking: false }
    property string orderAddress: ""
    readonly property bool controlHeld: shortcutModifiers.known && shortcutModifiers.controlDown
    readonly property bool quickSelection: quickSelectionTimer.running && shortcutsAvailable
    readonly property var shortcutModifierState: shortcutModifiers
    readonly property bool shortcutsAvailable: opened && mode === "windows" && !busy
        && !confirmation.opened && !recoveryOpen && !!hostWidget && !hostWidget.moveMenuOpen
    readonly property var shortcutAddresses: list.shortcutAddresses
    readonly property bool interacting: list.interacting
    readonly property bool backgroundToggleAllowed: opened && mode === "windows" && !busy && !interacting && !confirmation.opened && !recoveryOpen
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
    readonly property var shortcuts: Shortcuts.normalize(hostWidget ? hostWidget.shortcuts : {})
    readonly property bool editing: mode === "appearance" || mode === "scaling" || mode === "labels" || mode === "shortcuts" || mode === "pictures" || mode === "troubleshooting"
    readonly property bool hoverLogoEnabled: !!hostWidget && hostWidget.hoverLogo !== false
    readonly property real listChromeHeight: header.implicitHeight + list.anchors.topMargin
        + list.anchors.bottomMargin + footer.implicitHeight
    implicitHeight: closingHeight >= 0 ? closingHeight : recoveryOpen ? Math.min(maximumHeight, recoveryDialog.implicitHeight) : mode === "windows" ? listChromeHeight
            + list.fittedHeight(Style.space(420), Math.max(0, maximumHeight - listChromeHeight), Style.space(44))
        : mode === "move" ? header.implicitHeight + Style.space(24) + footer.implicitHeight
            + Math.max(moveForm.implicitHeight, destinationPicker.popupOpen
                ? destinationPicker.y + destinationPicker.height + Style.space(4) + destinationPicker.preferredPopupHeight : 0)
        : mode === "settings" ? Style.space(640)
        : mode === "appearance" || mode === "shortcuts" ? Math.min(maximumHeight, Math.max(Style.space(540),
            header.implicitHeight + editorScroll.anchors.topMargin + editorColumn.implicitHeight
            + editorScroll.anchors.bottomMargin + footer.implicitHeight))
        : Style.space(540)
    signal closeRequested()
    signal backgroundClicked()
    signal expandRequested()
    MouseArea {
        id: emptySpace; anchors.fill: parent; z: -1
        hoverEnabled: true; acceptedButtons: Qt.NoButton
        onWheel: function(wheel) { wheel.accepted = false; }
    }
    PanelHint {
        objectName: "barLabelHint"
        hostWidget: root.hostWidget
        belowAnchor: true; anchorItem: root.previewBoundsItem
        requested: root.opened && !root.recoveryOpen && root.barLabelHovered && !root.busy && !root.interacting
            && !root.hostWidget.moveMenuOpen
        text: root.mode !== "windows" ? root.words.closePanelHint
            : root.hostWidget && root.hostWidget.doubleClickExpand
                ? root.expanded ? root.words.closePanelHint + "\n" + root.words.collapsePanelHint
                    : root.compactPinned ? root.words.unpinBarHint + "\n" + root.words.expandPanelHint
                    : root.hostWidget.pinByTitleClick ? root.words.pinBarHint + "\n" + root.words.expandPanelHint
                    : root.words.expandPanelHint
                : root.expanded ? root.words.closePanelHint : root.words.openSearchHint
    }
    PanelHint {
        objectName: "backgroundInstructions"
        hostWidget: root.hostWidget
        belowAnchor: true
        anchorItem: root.previewBoundsItem
        requested: root.opened && !root.recoveryOpen && root.mode === "windows" && !root.interacting
            && root.pointerInsidePanel
            && !root.busy && (root.hostWidget.openOnHover || root.hostWidget.doubleClickExpand)
            && !root.hostWidget.moveMenuOpen && !hoverLogo.hovered && !list.rowHovered && !root.barLabelHovered
            && !list.scrollbar.hovered && !(root.expanded && (settingsButton.hot || search.hovered
                || hintsToggle.pointerHovered || updateSwitch.pointerHovered))
            && (emptySpace.containsMouse || list.backgroundHovered || root.outerBackgroundHovered)
        text: root.hostWidget && root.hostWidget.doubleClickExpand
            ? (root.expanded ? root.words.collapsePanelHint : root.words.expandPanelHint)
            : (root.expanded ? root.words.collapsePanelClickHint : root.words.expandPanelClickHint)
    }
    // Prepare once per shortcut/language change, outside the resize gesture.
    readonly property var compactKeyBindings: Shortcuts.hoverBindings(root.shortcuts, root.rtl)
    ShortcutModifiers {
        id: shortcutModifiers
        // An inactive compact panel must not consume the other app's navigation keys.
        active: root.shortcutsAvailable && (root.expanded || root.Window.active)
        modifier: root.shortcuts.numbers
        hoverBindings: !root.expanded ? root.compactKeyBindings : []
        onDigitPressed: function(digit) { root.activateWindowDigit(digit); }
        onHoverActionPressed: function(action) { root.handleHoverAction(action); }
    }
    Timer { id: quickSelectionTimer; interval: 5000 }
    function startQuickSelection() { if (shortcutsAvailable && expanded) quickSelectionTimer.restart(); }
    onShortcutsAvailableChanged: if (!shortcutsAvailable) quickSelectionTimer.stop()
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
        finishDismiss();
        quickSelectionTimer.stop();
        if (takeFocus === undefined) takeFocus = true;
        opened = true;
        shortcutModifiers.reset();
        if (!takeFocus) { search.focus = false; focus = false; }
        mode = "windows"; search.text = ""; selectedAddress = "";
        closingFocusNotice = null;
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
        quickSelectionTimer.stop();
        list.cancelFlick();
        search.focus = false;
        focus = false;
        if (search.text) {
            search.text = "";
            list.positionViewAtBeginning();
        }
        Qt.callLater(function() {
            if (root.opened && !root.expanded && root.mode === "windows") search.forceActiveFocus();
        });
    }
    function dismiss() {
        opened = false;
        list.cancelFlick();
        appearance.closePickers(); settingsContent.closePickers(); destinationPicker.close();
        labelsEditor.closePickers();
        confirmation.opened = false;
        if (hostWidget) { hostWidget.cancelAppearance(); hostWidget.cancelLabels(); }
        // Keep the current view until the enclosing surface has finished fading.
    }
    function showSettings() {
        if (mode === "windows") mainScrollY = list.contentY;
        settingsReturnMode = ""; settingsScrollY = 0;
        mode = "settings"; settingsVisit = true; editorScroll.cancelFlick(); editorScroll.contentY = 0;
        settingsContent.begin();
        Qt.callLater(function() { settingsContent.focusLanguage(); });
    }
    function returnToSettings(focusReason) {
        var restoreReason = typeof focusReason === "number" ? focusReason : settingsContent.editorFocusReason;
        mode = "settings";
        Qt.callLater(function() {
            editorColumn.forceLayout();
            editorScroll.cancelFlick();
            editorScroll.contentY = Math.min(settingsScrollY, Math.max(0, editorScroll.contentHeight - editorScroll.height));
            if (settingsReturnMode) settingsContent.focusEditor(settingsReturnMode, restoreReason);
            else settingsContent.focusLanguage();
        });
    }
    function showTroubleshooting() {
        if (mode === "troubleshooting") return;
        rememberTroubleshootingOrigin();
        if (mode === "settings") { settingsReturnMode = "troubleshooting"; settingsScrollY = editorScroll.contentY; }
        if (recovery) recovery.dismissSuggestion();
        recoveryOpen = false;
        if (!expanded) expandRequested();
        mode = "troubleshooting";
        editorScroll.cancelFlick(); editorScroll.contentY = 0;
    }
    function back(focusReason) {
        var returnToSettings = editing;
        if (editing && hostWidget) { hostWidget.cancelAppearance(); hostWidget.cancelLabels(); }
        appearance.closePickers(); destinationPicker.close(); settingsContent.closePickers();
        labelsEditor.closePickers();
        if (mode === "troubleshooting" && troubleshootingReturn.mode !== "settings") {
            var previous = troubleshootingReturn;
            mode = previous.mode;
            if (previous.review) openRecovery(previous.scroll);
            else if (mode === "windows") restoreSearchView(previous.scroll);
            else editorScroll.contentY = previous.scroll;
        } else if (returnToSettings) root.returnToSettings(focusReason);
        else { mode = "windows"; restoreSearchView(mainScrollY); }
    }
    function findOpenPopup(item) {
        if (!item || item.visible === false) return null;
        if (item.activePopup) return findOpenPopup(item.activePopup.contentItem) || item.activePopup;
        var children = item.children || [];
        for (var i = children.length - 1; i >= 0; i--) {
            var popup = findOpenPopup(children[i]);
            if (popup) return popup;
        }
        return item.popupOpen === true && typeof item.close === "function" ? item : null;
    }
    readonly property var currentPopup: root.mode === "windows" ? null : findOpenPopup(root)
    function navigateBack(position, focusReason) {
        if (confirmation.opened) confirmation.cancel();
        else if (recoveryOpen) { if (recoveryDialog.choosingIgnore) recoveryDialog.activate("back"); else recoveryDialog.cancel(); }
        else if (currentPopup) currentPopup.close();
        else if (mode === "settings" && settingsContent.collapseSection()) return;
        else if (mode === "appearance" && appearance.item && appearance.item.backWithinEditor()) return;
        else if (mode === "windows") closeRequested();
        else back(typeof focusReason === "number" ? focusReason : Qt.MouseFocusReason);
    }
    function openMove(address) {
        if (!hostWidget || busy || !inventory.windows.some(function(window) { return window.address === address; })) return;
        if (!expanded) expandRequested();
        if (hostWidget.windowPreview) hostWidget.windowPreview.dismiss();
        if (mode === "windows") mainScrollY = list.contentY;
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
        if (handleListNavigation(event)) return;
        var towardMove = Shortcuts.matches(event, Shortcuts.actionChord(shortcuts, "moveSide", rtl));
        var atTextEdge = search.cursorPosition === (rtl ? 0 : search.text.length);
        if (towardMove && atTextEdge && !search.selectedText) {
            // At the text edge, continue into the selected row's action column.
            // Inside the query or with a selection, keep normal text editing.
            event.accepted = list.focusAction(selectedAddress, true);
        } else if (Shortcuts.matches(event, shortcuts.next) || Shortcuts.matches(event, shortcuts.previous)) {
            moveSelection(Shortcuts.matches(event, shortcuts.next) ? 1 : -1); event.accepted = true;
        } else if (Shortcuts.matches(event, shortcuts.move)) {
            if (selectedAddress && !busy) openMove(selectedAddress);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (selectedAddress && hostWidget && !busy) {
                hostWidget.focusWindow(selectedAddress);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) { closeRequested(); event.accepted = true; }
    }
    function handleWindowShortcut(event) {
        if (!opened || mode !== "windows" || confirmation.opened
                || !hostWidget || hostWidget.moveMenuOpen) return false;
        var modifiers = Shortcuts.eventMask(event, true);
        if (modifiers !== Shortcuts.mask(shortcuts.numbers) && !(quickSelection && modifiers === Qt.NoModifier)) return false;
        var digit = Shortcuts.digit(event);
        if (digit < 0) {
            if (quickSelection && event.text && event.text.length && modifiers === Qt.NoModifier)
                quickSelectionTimer.stop();
            return false;
        }
        event.accepted = true;
        if (busy || event.isAutoRepeat) return true;
        activateWindowDigit(digit);
        return true;
    }
    function activateWindowDigit(digit) {
        if (!shortcutsAvailable || !hostWidget || digit < 0 || digit > 9) return;
        var index = digit === 0 ? 9 : digit - 1;
        var address = list.visibleWindowAddresses()[index];
        if (address) hostWidget.focusWindow(address);
    }
    function updateControl(event, pressed) {
        shortcutModifiers.key(event, pressed);
    }
    function handleListNavigation(event) {
        if (!shortcutsAvailable) return false;
        if (!expanded) {
            var action = Shortcuts.hoverActions(shortcuts, rtl).find(function(item) { return Shortcuts.matches(event, item.chord); });
            if (!action) return false;
            if (action.repeating || !event.isAutoRepeat) handleHoverAction(action.id);
            event.accepted = true; return true;
        }
        if (Shortcuts.matches(event, shortcuts.move)) {
            if (selectedAddress && !event.isAutoRepeat) openMove(selectedAddress);
            event.accepted = true; return true;
        }
        var names = ["pageUp", "pageDown", "first", "last"];
        var index = names.findIndex(function(id) { return Shortcuts.matches(event, root.shortcuts[id]); });
        if (index < 0) return false;
        // Standard caret navigation in a nonempty query always keeps priority.
        if (search.activeFocus && search.text && !Shortcuts.eventMask(event, true)
                && (event.key === Qt.Key_Home || event.key === Qt.Key_End)) return false;
        var action = list.focusedAction;
        var address = list.pageAddress([Qt.Key_PageUp, Qt.Key_PageDown, Qt.Key_Home, Qt.Key_End][index]);
        if (address) {
            selectedAddress = address;
            if (action) list.focusAction(address, action.objectName === "windowMove");
        }
        event.accepted = true;
        return true;
    }
    function handleHoverAction(action) {
        if (expanded || !shortcutsAvailable) return;
        if (action === "previous" || action === "next") moveSelection(action === "next" ? 1 : -1);
        else if (["pageup","pagedown","first","last"].indexOf(action) >= 0) {
            var key = {pageup:Qt.Key_PageUp,pagedown:Qt.Key_PageDown,first:Qt.Key_Home,last:Qt.Key_End}[action];
            var address = list.pageAddress(key);
            if (address) selectedAddress = address;
        } else if (action === "activate") activateWindow(selectedAddress, false);
        else if (action === "dismiss") closeRequested();
        else if (action === "move") openMove(selectedAddress);
        else if (["windowside","moveside","forward","backward"].indexOf(action) >= 0) {
            expandRequested();
            Qt.callLater(function() {
                if (!root.opened || !root.expanded || root.mode !== "windows") return;
                if (action === "backward") search.forceActiveFocus(Qt.BacktabFocusReason);
                else list.focusAction(root.selectedAddress, action === "moveside");
            });
        }
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
    // Pointer re-entry reactivates the last control, often above the viewport.
    // Reveal only after a keyboard event, never merely after window activation.
    function revealKeyboardFocus() {
        var focused = root.Window.window ? root.Window.window.activeFocusItem : null;
        for (var item = focused; item; item = item.parent) {
            if (list.visible && item === list.contentItem) { root.reveal(focused, list); return; }
            if (editorScroll.visible && item === editorScroll.contentItem) { root.reveal(focused, editorScroll); return; }
        }
    }
    Keys.onShortcutOverride: function(event) {
        Qt.callLater(root.revealKeyboardFocus);
        event.accepted = false;
    }
    Keys.onEscapePressed: function(event) { navigateBack(null, Qt.TabFocusReason); event.accepted = true; }
    Keys.onPressed: function(event) {
        updateControl(event, true);
        if (!handleWindowShortcut(event)) handleListNavigation(event);
    }
    Keys.onReleased: function(event) { updateControl(event, false); }
    Connections { target: root.hostWidget; function onMoveCompleted() { if (root.mode === "move") root.back(); } }
    LayoutMirroring.enabled: rtl
    LayoutMirroring.childrenInherit: true

    Column {
        id: header; objectName: "panelHeader"; visible: !root.recoveryOpen; width: parent.width; spacing: Style.space(10) * root.expansion
        Item {
            width: parent.width; height: Style.space(29)
            ReadableText {
                id: panelTitle; objectName: "panelTitle"
                width: Math.min(implicitWidth, parent.width - Math.max(settingsButton.width, countBadge.width) - Style.space(8))
                text: root.mode === "windows" ? (root.hostWidget ? root.hostWidget.textTemplates.panelTitle : "WindowPeek")
                    : root.mode === "troubleshooting" ? root.words.troubleshooting
                    : root.mode === "pictures" ? root.words.picturesAndGifs
                    : root.mode === "move" ? root.words.moveTo : root.mode === "labels" ? I18n.words(root.hostWidget.language).labels : root.words.settings
                textFormat: Text.PlainText; elide: Text.ElideRight
                textColor: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true
                anchors.verticalCenter: parent.verticalCenter

            }
            LabelButton {
                id: settingsButton; objectName: "settingsButton"
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width * 0.4)
                opacity: root.expansion; enabled: root.expanded
                label: root.mode === "windows" ? root.words.settings : root.words.back
                accent: root.accent; focusable: true
                onClicked: root.mode === "windows" ? root.showSettings() : root.back(activationFocusReason)
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
                ReadableText {
                    id: countText; objectName: "windowCountText"; anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - Style.space(16)); elide: Text.ElideRight
                    text: root.hostWidget ? Labels.render(root.hostWidget.textTemplates.windowCount, {count: root.matches.length}) : String(root.matches.length)
                    textFormat: Text.PlainText; textColor: root.accent
                    font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true
                }
            }
        }
        Item {
            id: protectionNotice
            visible: root.mode === "windows" && root.focusNotice.shown
            width: parent.width; height: visible ? Math.max(statusText.implicitHeight, recoveryButton.implicitHeight) + Style.space(8) : 0
            ReadableText {
                id: statusText; objectName: "focusProtectionStatus"; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - recoveryButton.width - (protectionOff.visible ? protectionOff.width + Style.space(6) : 0) - Style.space(10)
                text: root.focusNotice.text
                textFormat: Text.PlainText; wrapMode: recoveryButton.needsAttention || root.protectionPaused ? Text.Wrap : Text.NoWrap
                elide: Text.ElideRight; textColor: recoveryButton.needsAttention ? Color.popups.text : root.accent
                font.bold: recoveryButton.needsAttention
                font.family: Style.font.family; font.pixelSize: recoveryButton.needsAttention ? Style.font.body : Style.font.caption
            }
            LabelButton {
                id: recoveryButton; objectName: "focusRecoveryNotice"
                anchors.right: protectionOff.visible ? protectionOff.left : parent.right
                anchors.rightMargin: protectionOff.visible ? Style.space(6) : 0; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width * 0.4)
                label: root.focusNotice.label
                // Pending recovery should stand out before hover, independently
                // of the theme's subtle normal-button border.
                readonly property bool needsAttention: root.focusNotice.attention
                readonly property color attentionColor: {
                    var background = root.hostWidget ? root.hostWidget.surfaces.panel : Color.popups.background;
                    return 0.2126 * background.r + 0.7152 * background.g + 0.0722 * background.b > 0.5
                        ? "#98542a" : "#e8ad62";
                }
                accent: needsAttention ? attentionColor : root.accent
                foreground: needsAttention ? attentionColor : Color.foreground
                background: needsAttention ? Qt.alpha(attentionColor, 0.10) : "transparent"
                bordered: true
                borderSpec: needsAttention ? Border.flat(attentionColor, Style.space(2)) : _borderSpec
                onClicked: {
                    if (root.recovery.protectionFailed === true) root.recovery.retryProtection(true);
                    else if (root.recoveryOffered || root.recovery.suggested || root.recovery.interrupted) root.openRecovery();
                    else root.openRecovery();
                }
            }
            LabelButton {
                id: protectionOff; objectName: "turnOffFocusProtection"
                anchors.right: parent.right; anchors.rightMargin: 0; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width * 0.25)
                visible: root.focusNotice.canDisable === true
                label: root.focusNotice.stopLabel || ""; bordered: true; accent: root.accent
                onClicked: root.disableProtection()
            }
        }
        Item {
            width: parent.width
            height: search.implicitHeight * root.expansion
            visible: root.mode === "windows"
            clip: true
            EditField {
                id: search; objectName: "windowSearch"
                blurOnOutsidePress: false
                opacity: root.expansion; enabled: root.opened; width: parent.width
                placeholderText: root.words.searchWindows; accent: root.accent
                Accessible.name: root.words.searchWindows
                onTextEdited: {
                    quickSelectionTimer.stop();
                    // Use the real text input while compact, preserving the first
                    // character, keyboard layout and fast typing through expansion.
                    if (!root.expanded && root.shortcutsAvailable) root.expandRequested();
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
        showShortcuts: (root.controlHeld || root.quickSelection) && root.shortcutsAvailable
        previewBoundsItem: root.previewBoundsItem
        scrollbarGutter: root.scrollbarGutter
        anchors.top: header.bottom; anchors.topMargin: Style.space(10)
        anchors.bottom: footer.top; anchors.bottomMargin: Style.space(12)
        visible: !root.recoveryOpen && root.mode === "windows" && root.matches.length > 0
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

    ReadableText {
        anchors.centerIn: list; width: root.width - Style.space(28)
        visible: !root.recoveryOpen && root.mode === "windows" && root.matches.length === 0
        text: root.inventory.status !== "ready" ? root.words.unavailable
            : root.inventory.windows.length ? root.words.noMatches : root.words.emptyWindows
        textFormat: Text.PlainText; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
        textColor: Qt.alpha(Color.popups.text, 0.7); font.pixelSize: Style.font.body; font.family: Style.font.family
    }

    Item {
        id: settingsBranding; objectName: "settingsBranding"
        z: 1
        x: editorScroll.x; y: editorScroll.y
        width: editorScroll.width; height: editorScroll.height
        visible: !root.recoveryOpen && root.mode === "settings" && !!root.hostWidget && root.hostWidget.settingsLogo
        clip: true
        // Keep the mark stationary; content covers it as sections expand or scroll.
        Item {
            id: uncoveredSettings; objectName: "uncoveredSettings"
            y: Math.max(0, settingsContent.height - editorScroll.contentY + Style.space(16))
            width: parent.width; height: Math.max(0, parent.height - y)
            visible: height > 0
            clip: true
            PanelLogo {
                objectName: "settingsOmarchyLogo"
                sessionActive: root.settingsVisit && root.opened && !!root.hostWidget && root.hostWidget.settingsLogo
                hintAnchor: root.previewBoundsItem
                source: root.hostWidget ? root.hostWidget.settingsLogoImage : ""
                loopAnimation: !root.hostWidget || root.hostWidget.settingsLogoLoop
                loopDelay: root.hostWidget ? root.hostWidget.settingsLogoLoopDelay : 0
                cooldownSlot: "settings"
                cooldown: root.hostWidget ? root.hostWidget.settingsLogoCooldown : 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: settingsBranding.height - height - Style.space(48) - parent.y
                visible: y + height > 0 && y < parent.height
                width: Math.min(parent.width * 0.72, Style.space(324))
                height: width * 285 / 1215
                // Effects stay in the backdrop; its texture can show through the mark.
                hostWidget: root.hostWidget; accent: root.accent
            }
        }
    }

    Flickable {
        id: editorScroll; objectName: "editorScroll"
        anchors.top: header.bottom; anchors.topMargin: Style.space(12)
        anchors.bottom: footer.top; anchors.bottomMargin: Style.space(12)
        // Keep hidden editors ready without relaying every resize frame through them.
        property real preparedWidth: parent.width
        width: visible ? parent.width : preparedWidth; clip: true
        onWidthChanged: if (visible) preparedWidth = width
        Component.onCompleted: preparedWidth = parent.width
        visible: !root.recoveryOpen && root.mode !== "windows"
        contentHeight: editorColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        WheelScroll { view: editorScroll; speed: root.hostWidget ? root.hostWidget.wheelScrollSpeed : 102 }
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
                    if (mode === "troubleshooting") root.rememberTroubleshootingOrigin();
                    root.settingsReturnMode = mode;
                    root.settingsScrollY = editorScroll.contentY;
                    closePickers();
                    root.mode = mode;
                    editorScroll.cancelFlick();
                    editorScroll.contentY = 0;
                }
                onEnsureVisible: function(item) { root.ensureVisible(item); }
            }
            TroubleshootingSettings {
                objectName: "troubleshootingSettings"
                onProtectionRequested: root.confirmPermanentProtection()
                visible: root.mode === "troubleshooting"; width: parent.width
                hostWidget: root.hostWidget
            }
            LogoSettings {
                id: pictures; objectName: "logoSettings"
                visible: root.mode === "pictures"; width: parent.width
                hostWidget: root.hostWidget
            }
            Loader {
                id: appearance
                width: parent.width
                active: root.mode === "appearance"; visible: active
                onLoaded: item.begin()
                function closePickers() { if (item && item.closePickers) item.closePickers(); }
                sourceComponent: AppearanceEditor {
                    hostWidget: root.hostWidget
                    onFinished: function(reason) { root.returnToSettings(reason); }
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
                    onFinished: function(reason) { root.returnToSettings(reason); }
                    onEnsureVisible: function(item) { root.ensureVisible(item); }
                }
            }
            Loader {
                id: shortcutsEditor
                width: parent.width
                active: root.mode === "shortcuts"; visible: active
                onLoaded: item.begin()
                sourceComponent: ShortcutsEditor {
                    hostWidget: root.hostWidget
                    popupParent: root
                    onFinished: function(reason) { root.returnToSettings(reason); }
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
                    onFinished: function(reason) { root.returnToSettings(reason); }
                    onEnsureVisible: function(item) { root.ensureVisible(item); }
                }
            }
            Column {
                id: moveForm
                width: parent.width; visible: root.mode === "move"; spacing: Style.space(12)
                ReadableText {
                    width: parent.width; text: root.moveWindow ? root.moveWindow.app + "\n" + root.moveWindow.title : root.words.windowClosed
                    textFormat: Text.PlainText; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                    textColor: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body
                }
                ReadableText {
                    objectName: "moveSource"
                    readonly property var workspace: root.moveWindow ? root.moveWindow.workspace : null
                    width: parent.width
                    text: I18n.format(root.words.moveFrom, {workspace: I18n.workspaceTitle(workspace ? workspace.name : "", root.words)})
                        + (workspace && workspace.monitor ? " · " + workspace.monitor.name : "")
                    textFormat: Text.PlainText; wrapMode: Text.Wrap
                    textColor: Qt.alpha(Color.popups.text, 0.7)
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
                    hostWidget: root.hostWidget
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
                ReadableText {
                    width: parent.width; text: root.words.moveHint
                    textFormat: Text.PlainText; wrapMode: Text.Wrap
                    textColor: Qt.alpha(Color.popups.text, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption
                }
            }
        }
    }
    Column {
        id: footer; objectName: "panelFooter"; visible: !root.recoveryOpen; width: parent.width; anchors.bottom: parent.bottom; spacing: Style.space(9)
        Rectangle { width: parent.width; height: 1; color: Qt.alpha(Color.popups.text, 0.1) }
        ReadableText {
            width: parent.width; visible: !!root.hostWidget && (!!root.hostWidget.actionError || root.hostWidget.saveFailed)
            text: root.hostWidget && root.hostWidget.saveFailed ? root.words.settingsError
                : root.hostWidget ? (root.words[root.hostWidget.actionError] || root.words.actionFailed) : ""
            textFormat: Text.PlainText; wrapMode: Text.Wrap; textColor: Color.urgent; font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
        Item {
            width: parent.width
            id: footerContent
            // Replace the search field and expanded footer with the mark, keeping
            // the same list viewport without permanent help text.
            readonly property real hoverHeight: root.hoverLogoEnabled
                ? Math.max(Style.space(26 + 10) + search.implicitHeight, Style.space(68)) : 0
            height: Style.space(26) * root.expansion + hoverHeight * (1 - root.expansion)
            Item {
                objectName: "hoverBranding"
                y: 0
                width: parent.width; height: Math.max(0, footerContent.hoverHeight - y)
                visible: root.hoverLogoEnabled && root.mode === "windows" && root.expansion < 1
                opacity: 1 - root.expansion
                PanelLogo {
                    id: hoverLogo
                    objectName: "hoverOmarchyLogo"
                    hintAnchor: root.previewBoundsItem
                    source: root.hostWidget ? root.hostWidget.hoverLogoImage : ""
                    loopAnimation: !root.hostWidget || root.hostWidget.hoverLogoLoop
                    loopDelay: root.hostWidget ? root.hostWidget.hoverLogoLoopDelay : 0
                    cooldownSlot: "hover"
                    cooldown: root.hostWidget ? root.hostWidget.hoverLogoCooldown : 0
                    anchors.centerIn: parent
                    width: Math.max(0, Math.min(parent.width * 0.72, Style.space(324), (parent.height - Style.space(12)) * 1215 / 285))
                    height: width * 285 / 1215
                    hostWidget: root.hostWidget; accent: root.accent
                }
            }
            Row {
                objectName: "footerTools"
                opacity: root.expansion; visible: root.expansion > 0; enabled: root.expanded
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(10)
                HintsToggle {
                    id: hintsToggle
                    objectName: "hintsToggle"; words: root.words; focusable: true; accent: root.accent
                    hintAnchor: root.previewBoundsItem
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
                        hostWidget: root.hostWidget; requested: updateSwitch.pointerHovered
                        belowAnchor: true; anchorItem: root.previewBoundsItem
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
                text: "v" + root.hostWidget.version + " · by Sarr"
            }
        }
    }
    BackMouseArea {
        enabled: root.opened
        z: 5
        onClicked: function(mouse) { root.navigateBack(Qt.point(mouse.x, mouse.y)); }
    }
    BackMouseArea {
        objectName: "overlayBackPointer"
        parent: root.QQC.Overlay.overlay
        visible: enabled
        enabled: root.opened && root.currentPopup !== null
        // Handle outside right clicks before Qt closes a popup on press and
        // lets the same release fall through to its parent settings page.
        z: 1000003
        onClicked: if (root.currentPopup) root.currentPopup.close()
    }
    UpdateConfirmation {
        id: confirmation; anchors.fill: parent; z: 10; words: root.words; rtl: root.rtl; accent: root.accent
        onCanceled: updateSwitch.forceActiveFocus()
        onConfirmed: { if (root.hostWidget) root.hostWidget.persistSettings({ autoUpdates: false }); updateSwitch.forceActiveFocus(); }
    }
    FocusRecoveryDialog {
        id: recoveryDialog; objectName: "focusRecoveryDialog"; anchors.fill: parent; z: 20
        onTroubleshootingRequested: root.showTroubleshooting()
        onPermanentRequested: function(enabled) {
            if (root.hostWidget) root.hostWidget.persistSettings({keepSearchFocus:enabled}, function(ok) {
                if (ok) {
                    if (root.recovery) root.recovery.dismissSuggestion();
                    root.recoveryOpen = false;
                    root.restoreAfterReview();
                } else if (root.recovery) root.recovery.message = recoveryDialog.copy.saveFailed;
            });
        }
        onDisableRequested: root.disableProtection(function(ok) { if (ok) root.recoveryOpen = false; })
        recovery: root.recovery; rtl: root.rtl; accent: root.accent
        onClosed: root.restoreAfterReview()
    }
}
