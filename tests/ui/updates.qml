import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Ui as Ui
import qs.Commons
import qs.Commons as Commons
import "WindowPeek" as Plugin
import "WindowPeek/src/I18n.js" as I18n
import "WindowPeek/src/UpdateWords.js" as UpdateCopy

ShellRoot {
    id: test
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    property int step: 0
    property int launches: 0
    property int manualChecks: 0
    property int terminals: 0
    property bool startupLaunch: false
    property bool waiting: false
    // Helpers pump Qt's event loop; the repeating driver must never begin the
    // next scenario before the current handler has returned.
    property bool runningStep: false
    TestCase { id: asyncWait; when:false }
    function flush() {
        waiting=true;
        for (var i=0;host.runtime.preferences.saving && i<2000;i++) asyncWait.wait(1);
        waiting=false;
        check(!host.runtime.preferences.saving,"async save completed");
    }
    function check(value, message) { if (!value) throw new Error(message); }
    function screenshot(suffix) {
        var path = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
        if (!path) return;
        var captured = false;
        window.contentItem.grabToImage(function(result) { result.saveToFile(path + suffix); captured = true; });
        test.waiting = true;
        for (var i=0; i<200 && !captured; i++) asyncWait.wait(5);
        test.waiting = false;
        check(captured, "screenshot completed before navigating");
    }
    function find(item, name) {
        if (item.objectName === name) return item;
        var children = item.children || [];
        for (var i = 0; i < children.length; i++) {
            var result = find(children[i], name);
            if (result) return result;
        }
        return null;
    }
    function scheduler() {
        var updates = host.runtime.updates;
        var prefs = host.runtime.preferences;
        updates.runtimeAvailable = true;
        updates.manualReady = true;
        updates.startManualCheck = function(force) { test.manualChecks++; };
        updates.manualResult = {}; updates.manualLastLaunch = 0;
        var quiet = {opened:false, hoverOpened:false, actionBusy:false};
        try {
            check(updates.checksEnabled, "saved default enables update checks");
            ["opened", "hoverOpened", "actionBusy"].forEach(function(key) {
                var busy = {opened:false, hoverOpened:false, actionBusy:false}; busy[key] = true;
                updates.check([quiet, busy], 1000);
                check(test.manualChecks === 0, key + " on another monitor defers the check");
            });
            var payload = prefs.lastPayload;
            prefs.lastPayload = "";
            updates.check([quiet], 1000);
            check(!updates.checksEnabled && test.manualChecks === 0, "unsaved preferences cannot start a worker");
            prefs.lastPayload = payload;
            prefs.failed = true; updates.check([quiet], 1000);
            check(test.manualChecks === 0, "failed save blocks the worker");
            prefs.failed = false; prefs.readBlocked = true; updates.check([quiet], 1000);
            check(test.manualChecks === 0, "unreadable preferences block the worker");
            prefs.readBlocked = false;
            updates.check([quiet], 1000); updates.check([quiet], 1000);
            check(test.manualChecks === 1, "monitor timers share one launch throttle");
            updates.check([quiet], 1299);
            check(test.manualChecks === 1, "worker startup is not retried every tick");
            updates.check([quiet], 1300);
            check(test.manualChecks === 2, "worker startup can be retried");
            updates.manualResult = {status:"current",lastCheck:1000}; updates.manualLastLaunch = 0;
            updates.check([quiet], 1001);
            check(test.manualChecks === 2, "cached result prevents another check");
            updates.check([quiet], 22599);
            check(test.manualChecks === 2, "six-hour deadline has not arrived");
            updates.check([quiet], 22600);
            check(test.manualChecks === 3, "check becomes due after six hours");
            host.persistSettings({checkUpdates:false}); test.flush();
            updates.check([quiet], 200000);
            check(!updates.checksEnabled && test.manualChecks === 3, "saved opt-out blocks scheduled checks");
            updates.checkNow(); check(test.manualChecks === 4, "explicit check works despite opt-out");
            host.persistSettings({checkUpdates:true}); test.flush();
        } finally { updates.runtimeAvailable = false; }
    }
    function settle() { waiting=true; asyncWait.wait(40); waiting=false; }
    function click(item, x) { events.mouseClick(item, x === undefined ? item.width/2 : x, item.height/2, Qt.LeftButton, Qt.NoModifier, 0); settle(); }
    function assertFits() {
        settle();
        var scroll=find(panel,"editorScroll");
        check(scroll.contentHeight <= scroll.height + 0.01,
            "Updates fits without scrolling: " + scroll.contentHeight + " / " + scroll.height + " " + host.language);
    }
    function localizedLayouts() {
        var updates = host.runtime.updates;
        updates.manualResult = {status:"available", version:"1.0.1", commit:"a".repeat(40),
            verification:"unverified", lastCheck:Date.UTC(2026,9,19,12,0)/1000};
        panel.showUpdates(); settle();
        var action = find(panel,"primaryUpdateAction");
        var changes = find(panel,"viewUpdateChanges");
        var verification = find(panel,"manualUpdateVerification");
        var confirmation = find(panel,"updateConfirmation");
        for (var i = 0; i < I18n.languages.length; ++i) {
            var locale = I18n.languages[i].code;
            host.persistSettings({language:locale}); flush(); settle();
            var copy = UpdateCopy.words(locale);
            check(action.text === copy.install && changes.text === copy.changes,
                locale + " renders translated update actions");
            check(verification.children.some(function(child) { return child.text === copy.unverified; }),
                locale + " renders the early-release source label");
            check(action.contentItem.implicitWidth + action.leftPadding + action.rightPadding <= action.width + 1,
                locale + " install label fits the button");
            check(changes.contentItem.implicitWidth + changes.leftPadding + changes.rightPadding <= changes.width + 1,
                locale + " changes label fits the button: " + JSON.stringify({text:changes.text,
                    width:changes.width,implicit:changes.implicitWidth,label:changes.contentItem.implicitWidth,
                    grid:changes.parent.columns,primary:action.implicitWidth}));
            check(find(panel,"editorScroll").contentHeight > 0,
                locale + " update page stays scrollable");
            click(action);
            check(confirmation.opened && confirmation.question === copy.ready.replace("{version}","1.0.1"),
                locale + " renders the exact-version confirmation");
            check(confirmation.explanation === copy.askInstall,
                locale + " renders the localized installation question");
            if (locale === "en") check(confirmation.explanation.indexOf("Ready to install?") === 0,
                "English prompt asks whether the user is ready to install");
            var decisions=find(confirmation,"installDecisionActions");
            var later=find(confirmation,"cancelUpdateOff");
            var skip=find(confirmation,"skipUpdateVersion");
            var install=find(confirmation,"confirmUpdateOff");
            var link=find(confirmation,"viewInstallChanges");
            check(link.enabled && link.contentItem.font.underline,
                locale + " shows View changes as a usable underlined link");
            [later,skip,install].forEach(function(button) {
                check(button.visible && button.contentItem.implicitWidth + button.leftPadding
                    + button.rightPadding <= button.width + 1,
                    locale + " decision button fits: " + button.text);
            });
            if (decisions.columns===3) check(later.y===skip.y && skip.y===install.y,
                locale + " keeps Later, Skip version and Install now on one row");
            check(confirmation.popupInputItem.height <= confirmation.height + 1,
                locale + " confirmation fits the panel");
            click(find(panel,"cancelUpdateOff"));
        }
        host.persistSettings({language:"en"}); flush();
        updates.manualResult = {status:"current"};
        panel.back();
    }
    function manualUpdates() {
        var updates = host.runtime.updates;
        updates.runtimeAvailable=true; updates.manualReady=true;
        updates.startManualCheck=function(force) { test.manualChecks++; };
        updates.startExactInstall=function(commit, version, verification) {
            check(commit==="a".repeat(40) && version==="0.7.3" && verification==="unverified",
                "installer receives the exact displayed choice");
            test.terminals++;
        };
        test.manualChecks=0;
        updates.manualResult={}; updates.manualLastLaunch=0;
        updates.checkManual([{opened:true}],1000);
        check(test.manualChecks===0,"manual checks wait for idle");
        updates.checkManual([{opened:false}],1000); updates.checkManual([{opened:false}],1001);
        check(test.manualChecks===1,"checker shared across monitors");
        updates.manualResult={status:"current",lastCheck:1000};
        updates.checkManual([{opened:false}],22599);
        check(test.manualChecks===1,"manual cache lasts six hours");
        updates.checkManual([{opened:false}],22600);
        check(test.manualChecks===2,"cache expires");
        host.persistSettings({checkUpdates:false}); flush();
        updates.checkManual([{opened:false}],50000);
        check(test.manualChecks===2,"notification opt-out stops background metadata checks");
        panel.showSettings(); panel.showUpdates(); settle();
        var action=find(panel,"primaryUpdateAction");
        var history=find(panel,"viewUpdateChanges");
        check(action.text==="Check now" && action.visible,"one primary action checks the current version");
        check(action.fontSize===history.fontSize,"primary action and history use the same readable font size");
        check(!action.textOnly && !history.textOnly && action.width===history.width && action.height===history.height,
            "check and history are equally sized bordered buttons");
        check(updates.changesUrl()==="https://github.com/Sarr77/WindowPeek/releases",
            "version history opens published releases");
        click(action);
        check(test.manualChecks===3 && test.terminals===0,"explicit check works with notifications off and installs nothing");
        stableCheckLayout();
        updates.manualResult={status:"available",version:"0.7.3",commit:"a".repeat(40),installedCommit:"b".repeat(40),
            verification:"unverified",lastCheck:Date.UTC(2026,8,28,10,30)/1000}; settle();
        check(action.text==="Install now" && action.enabled,"same primary action offers the exact update");
        check(find(panel,"manualUpdateVerification").children.some(function(c) {
            return c.text && c.text.indexOf("Early WindowPeek GitHub release")>=0;
        }),"early release has a neutral source label");
        var early=find(panel,"includeUnverifiedUpdatesToggle");
        check(early.checked && early.text==="Early GitHub releases","early releases are enabled by default");
        var beforePolicyChange=test.manualChecks;
        click(early); flush(); settle();
        check(!updates.manualAvailable && updates.filteredRelease && !updates.offerAvailable
            && action.text==="Check now" && find(panel,"manualUpdateStatus").text==="No newer Omarchy-verified release yet"
            && test.manualChecks===beforePolicyChange+1,
            "opt-out hides the amber offer from installation and notices");
        updates.manualResult={status:"available",version:"0.7.2",commit:"d".repeat(40),verification:"verified",
            releaseId:10,releaseTag:"v0.7.2",catalogRelease:true}; settle();
        check(updates.manualAvailable && action.text==="Install now",
            "verified catalog release remains available while newer early release is hidden");
        click(early); flush(); settle();
        check(test.manualChecks===beforePolicyChange+2,"restoring early releases refreshes discovery");
        updates.manualResult={status:"available",version:"0.7.3",commit:"a".repeat(40),installedCommit:"b".repeat(40),
            verification:"unverified",lastCheck:Date.UTC(2026,8,28,10,30)/1000}; settle();
        check(updates.manualAvailable && action.text==="Install now","re-enabling restores the same cached offer");
        assertFits(); screenshot(".available.png");
        click(action); check(find(panel,"updateConfirmation").opened && test.terminals===0,
            "one click asks before installation");
        check(String(find(panel,"installVerificationDot").color).toLowerCase().indexOf("edb65c")>=0,
            "unverified confirmation uses an amber dot");
        screenshot(".install-prompt-amber.png");
        var modalLater=find(panel,"cancelUpdateOff"), modalSkipButton=find(panel,"skipUpdateVersion");
        var modalInstall=find(panel,"confirmUpdateOff"), modalChanges=find(panel,"viewInstallChanges");
        check(modalLater.activeFocus,"confirmation starts at Later");
        events.keyClick(Qt.Key_Tab,Qt.NoModifier,0);
        check(modalSkipButton.activeFocus,"Tab reaches Skip version");
        events.keyClick(Qt.Key_Tab,Qt.NoModifier,0);
        check(modalInstall.activeFocus,"Tab reaches Install now");
        events.keyClick(Qt.Key_Tab,Qt.NoModifier,0);
        check(modalChanges.activeFocus,"Tab reaches View changes");
        events.keyClick(Qt.Key_Backtab,Qt.ShiftModifier,0);
        check(modalInstall.activeFocus,"Shift+Tab returns to Install now");
        check(find(panel,"updateConfirmation").installCommit==="a".repeat(40),
            "confirmation freezes the displayed commit");
        var offeredChanges=find(panel,"updateConfirmation").installChangesUrl;
        updates.manualResult={status:"available",version:"0.7.4",commit:"c".repeat(40),verification:"unverified"};
        check(find(panel,"updateConfirmation").installChangesUrl===offeredChanges,
            "the prompt's change link stays on the confirmed commit");
        click(find(panel,"confirmUpdateOff"));
        check(test.terminals===0 && panel.mode==="updates" && updates.choiceChanged,
            "a changed result cannot replace the confirmed commit and explains the change");
        assertFits();
        updates.manualResult={status:"available",version:"0.7.3",commit:"a".repeat(40),installedCommit:"b".repeat(40),
            verification:"unverified",lastCheck:Date.UTC(2026,8,28,10,30)/1000}; settle();
        click(action); click(find(panel,"confirmUpdateOff"));
        check(test.terminals===1,"confirmation starts the exact installer once");
        updates.installLaunchPending=false;
        check(updates.changesUrl().indexOf("/compare/")>=0,"changes link points to checked comparison");
        panel.back(); panel.mode="windows"; panel.searchField.text="Editor"; settle();
        var notice=find(panel,"availableUpdateButton");
        check(!notice.visible,"notification opt-out hides available badge without losing manual results");
        host.persistSettings({checkUpdates:true}); flush(); settle();
        check(notice.visible,"available update appears in expanded list");
        panel.expanded=false; check(!notice.visible,"compact panel stays uncluttered"); panel.expanded=true;
        click(notice); check(panel.mode==="updates","update notice opens shared page");
        panel.back(); settle();
        check(panel.mode==="windows" && panel.searchField.text==="Editor","Back restores search");
        panel.showSettings(); find(panel,"settingsControlsSection").expanded=true;
        find(panel,"updatesEntry").clicked(); settle();
        check(panel.mode==="updates","Settings entry opens same page");
        panel.back(); check(panel.mode==="settings" && find(panel,"settingsControlsSection").expanded,"Back preserves Settings section");
        panel.showUpdates(); settle();
        action=find(panel,"primaryUpdateAction");
        updates.manualResult={status:"available",version:"0.7.3",commit:"a".repeat(40),verification:"verified",
            installError:"local-changes"}; settle();
        check(action.text==="Check now" && action.enabled,
            "a local edit after discovery offers recheck instead of a disabled installer");
        var beforeRecheck=test.manualChecks;
        click(action); check(test.manualChecks===beforeRecheck+1,"recheck remains available after a local edit");
        updates.manualResult={status:"available",commit:"bad"};
        check(!updates.manualAvailable && !updates.openManualUpdate(),"invalid state cannot install");
        updates.manualResult={status:"local-changes",reason:"development"}; settle();
        check(action.visible && action.enabled && action.text==="Check now"
            && find(panel,"manualUpdateStatus").text.indexOf("Local development")===0,
            "development copy retains an enabled Check now action");
        var beforeCheck=test.manualChecks, beforeTerminal=test.terminals;
        click(action);
        check(test.manualChecks===beforeCheck+1 && test.terminals===beforeTerminal,
            "development Check now checks without starting an installation");
        check(find(panel,"viewUpdateChanges").visible && !find(panel,"viewUpdateChanges").textOnly,"development copy retains bordered history action");
        assertFits(); screenshot(".development.png");
        check(!updates.openManualUpdate(),"development copy remains protected");
        updates.manualResult={status:"ahead"}; check(!updates.openManualUpdate(),"ahead copy remains protected");
        [{},{status:"current"},{status:"failed"}].forEach(function(result) {
            updates.manualResult=result; settle();
            check(action.visible && action.text==="Check now","no update result presents Check now");
            check(!updates.manualCanUpdate,"installation requires a checked available commit");
        });
        updates.manualResult={status:"no-verified"}; settle();
        check(find(panel,"manualUpdateStatus").text==="No newer Omarchy-verified release yet"
            && !updates.manualCanUpdate,"no catalog-matched release is not offered for installation");
        updates.manualResult={status:"available",version:"0.7.3",commit:"a".repeat(40),verification:"unknown",lastCheck:Date.UTC(2026,8,28,10,30)/1000};
        host.persistSettings({language:"pl"}); flush(); settle();
        check(find(panel,"manualUpdateVerification").children.some(function(c) {
            return c.text && c.text.indexOf("Wczesne wydanie WindowPeek na GitHubie")>=0;
        }),"release source label is translated into Polish");
        assertFits(); screenshot(".available-pl.png");
        host.persistSettings({language:"en",autoUpdates:true,checkUpdates:true}); flush();
    }
    function footerAndFocus() {
        var updates=host.runtime.updates;
        updates.manualResult={status:"current"};
        panel.mode="windows"; settle();
        var toggle=find(panel,"updateSwitch"), credit=find(panel,"authorCredit");
        check(toggle.checked && host.autoUpdates,"notifications and auto-install retain enabled defaults");
        var checks=test.manualChecks, terminals=test.terminals;
        click(credit); check(panel.mode==="windows" && find(panel,"projectSupport").opened,"version opens project support, not duplicate Updates");
        click(panel,2);
        click(toggle, toggle.width-5); flush();
        var dialog=find(panel,"updateConfirmation"), primaryOff=find(panel,"cancelUpdateOff"), confirmOff=find(panel,"confirmUpdateOff");
        check(dialog.opened && dialog.notificationMode && toggle.checked,"footer asks before disabling notifications");
        check(confirmOff.width<primaryOff.width && confirmOff.fontSize===primaryOff.fontSize,
            "Turn off is narrower without shrinking its text");
        check(!find(panel,"panelHeader").enabled && !find(panel,"panelFooter").enabled,"confirmation blocks background controls");
        screenshot(".notification-off.png");
        click(primaryOff); flush();
        check(panel.mode==="updates" && toggle.checked && host.autoUpdates,"Open Updates navigates without changing either preference");
        panel.back(Qt.MouseFocusReason); settle();
        check(panel.mode==="windows","Back restores footer confirmation origin");
        click(toggle); events.keyClick(Qt.Key_Escape,Qt.NoModifier,0); settle();
        check(!dialog.opened && toggle.checked && toggle.keyboardFocusVisible,"Escape keeps notifications and returns keyboard focus: "
            + JSON.stringify({opened:dialog.opened,checked:toggle.checked,active:toggle.activeFocus,visual:toggle.visualFocus,
                pointer:toggle.pointerFocus,reason:toggle.focusReason,focused:window.activeFocusItem ? window.activeFocusItem.objectName : "none"}));
        click(toggle); click(panel,2);
        events.mouseMove(credit,credit.width/2,credit.height/2,0,Qt.NoButton,Qt.NoModifier); settle();
        check(!dialog.opened && toggle.checked && !toggle.hot,"mouse close leaves no stale footer focus");
        click(toggle); click(panel,panel.width-2);
        check(!dialog.opened && toggle.checked,"outside dismissal keeps notifications enabled");
        click(toggle); click(confirmOff); flush();
        check(!toggle.checked && host.autoUpdates && panel.mode==="windows","label toggles notifications only");
        click(toggle, 5); flush();
        check(toggle.checked && host.autoUpdates && !dialog.opened,"track enables immediately without a popup");
        check(test.manualChecks===checks && test.terminals===terminals,"footer toggle never starts a worker or terminal");
        find(panel,"hintsToggle").forceActiveFocus(Qt.OtherFocusReason);
        events.keyClick(Qt.Key_Tab,Qt.NoModifier,0);
        check(toggle.keyboardFocusVisible,"Tab visibly focuses notification toggle");
        var query = panel.searchField.text;
        events.keyClick(Qt.Key_Space,Qt.NoModifier,0); settle();
        check(panel.searchField.activeFocus && !dialog.opened,"space from the main-list footer continues typing");
        panel.searchField.text = query;
        toggle.forceActiveFocus(Qt.TabFocusReason);
        events.keyClick(Qt.Key_Return,Qt.NoModifier,0); settle();
        check(dialog.opened && toggle.checked,"Enter requests the same opt-out confirmation");
        events.keyClick(Qt.Key_Tab,Qt.NoModifier,0);
        events.keyClick(Qt.Key_Space,Qt.NoModifier,0); flush();
        check(!toggle.checked && toggle.keyboardFocusVisible,"notification toggle works with keyboard " + JSON.stringify({checked:toggle.checked, focus:toggle.activeFocus, visual:toggle.visualFocus, pointer:toggle.pointerFocus, key:toggle.keyboardFocusVisible}));
        click(toggle); flush(); events.mouseMove(credit,credit.width/2,credit.height/2,0,Qt.NoButton,Qt.NoModifier);
        check(toggle.checked && !toggle.hot,"mouse use clears old keyboard highlighting");
        panel.showSettings(); panel.showUpdates(); settle();
        var primary=find(panel,"primaryUpdateAction"), notifications=find(panel,"manualUpdateChecksToggle");
        check(!primary.hot,"opening Updates does not highlight primary action");
        click(notifications); flush(); check(!toggle.checked,"page and footer share notification setting");
        click(toggle); flush(); check(notifications.checked,"footer changes update page immediately");
        events.mouseMove(credit,credit.width/2,credit.height/2,0,Qt.NoButton,Qt.NoModifier);
        check(!primary.hot,"version hover cannot highlight primary action");
        find(panel,"viewUpdateChanges").forceActiveFocus(Qt.OtherFocusReason);
        events.keyClick(Qt.Key_Backtab,Qt.ShiftModifier,0);
        check(primary.keyboardFocusVisible,"primary action has a visible keyboard cue");
        checks=test.manualChecks;
        events.keyClick(Qt.Key_Return,Qt.NoModifier,0);
        check(test.manualChecks===checks+1,"keyboard checks once");
        click(primary); events.mouseMove(credit,credit.width/2,credit.height/2,0,Qt.NoButton,Qt.NoModifier);
        check(!primary.hot,"keyboard then mouse leaves no stale highlight");
    }
    function footerNavigation() {
        var toggle=find(panel,"updateSwitch"), dialog=find(panel,"updateConfirmation");
        panel.mode="labels"; settle();
        var editor=find(panel,"labelsEditor");
        editor.setStyle("custom");editor.setText("panelTitle","Unsaved title");
        var draft=JSON.stringify(editor.draft());
        click(toggle);click(find(panel,"cancelUpdateOff"));
        check(panel.mode==="updates" && !dialog.opened,"footer route works from a nested editor");
        panel.back(Qt.MouseFocusReason);settle();
        check(panel.mode==="labels" && find(panel,"labelsEditor")===editor
            && JSON.stringify(editor.draft())===draft,"Updates preserves the exact editor instance and unsaved draft: "
            + JSON.stringify({mode:panel.mode,origin:panel.updatesReturnMode,same:find(panel,"labelsEditor")===editor,
                expected:draft,actual:find(panel,"labelsEditor") ? JSON.stringify(find(panel,"labelsEditor").draft()) : "missing"}));
        editor.cancel(Qt.MouseFocusReason);settle();
        panel.mode="support";settle();
        find(panel,"supportSection0").expanded=true;
        click(toggle);click(find(panel,"cancelUpdateOff"));panel.back(Qt.MouseFocusReason);settle();
        check(panel.mode==="support" && find(panel,"supportSection0").expanded,"help expansion survives visiting Updates");
        panel.showSettings();panel.showUpdates();settle();
        click(toggle);click(find(panel,"cancelUpdateOff"));
        check(panel.mode==="updates" && !dialog.opened && toggle.checked,"Open Updates while already there closes the popup without changing state");
        click(toggle);host.persistSettings({checkUpdates:false});flush();click(find(panel,"confirmUpdateOff"));flush();
        check(!toggle.checked,"confirmation cannot re-enable another monitor's opt-out");
        click(toggle);flush();
        host.runtime.preferences.readBlocked=true;
        click(toggle);click(find(panel,"confirmUpdateOff"));flush();
        check(toggle.checked,"failed notification save preserves the original setting");
        host.runtime.preferences.readBlocked=false;
    }
    function skippedVersion() {
        var updates=host.runtime.updates;
        updates.manualResult={status:"available",version:"0.7.3",commit:"a".repeat(40),verification:"verified"};
        panel.showUpdates(); settle();
        var badge=find(host,"windowPeekUpdateBadge"), badgeDot=find(host,"windowPeekVerificationDot");
        var pageDot=find(panel,"manualUpdateVerificationDot");
        host.visible=true; settle();
        screenshot(".bar-green.png");
        check(badge && badge.visible && badgeDot && pageDot
            && String(badgeDot.color).toLowerCase().indexOf("92d992")>=0
            && String(pageDot.color).toLowerCase().indexOf("92d992")>=0,
            "verified update uses green dots: " + JSON.stringify({bar:String(badgeDot.color),page:String(pageDot.color)}));
        var badgePresses=0;
        badge.pressed.connect(function(code) { if (code===Qt.LeftButton) badgePresses++; });
        click(badge); host.visible=false; settle();
        check(badgePresses===1,"real pointer click reaches the bar update badge");
        var skip=find(panel,"skipUpdateVersionAction");
        check(skip.visible && updates.offerAvailable,"verified offer is initially visible");
        click(skip); flush();
        check(updates.manualSkipped && !updates.offerAvailable && skip.text==="Show this version again",
            "Skip version hides the alert but keeps the update available in Settings");
        click(skip); flush();
        check(!updates.manualSkipped && updates.offerAvailable,"user can restore the skipped version");
        panel.mode="windows"; settle();
        check(panel.openInstallPrompt(true),"offer opens confirmation");
        check(find(panel,"updateConfirmation").opened,"verified offer opens modal");
        check(String(find(panel,"installVerificationDot").color).toLowerCase().indexOf("92d992")>=0,
            "verified confirmation uses a green dot");
        screenshot(".install-prompt-green.png");
        var modalSkip=find(panel,"skipUpdateVersion");
        check(modalSkip.visible && modalSkip.width>0 && modalSkip.height>0,
            "modal skip has an actual hit target " + JSON.stringify({visible:modalSkip.visible,w:modalSkip.width,h:modalSkip.height}));
        settle();
        click(modalSkip); flush();
        check(updates.manualSkipped && !updates.offerAvailable,"Skip version in the modal hides the alert "
            + JSON.stringify({skipped:updates.manualSkipped,offer:updates.offerAvailable,
                saved:host.runtime.preferences.values.skippedUpdateVersion,
                result:updates.manualResult.version,open:find(panel,"updateConfirmation").opened}));
        updates.manualResult={status:"available",version:"0.7.4",commit:"b".repeat(40),verification:"unknown"};
        check(updates.offerAvailable,"a newer version is offered despite the old skip");
        host.visible=true; settle(); screenshot(".bar-amber.png"); host.visible=false; settle();
        panel.showUpdates(); settle();
        pageDot=find(panel,"manualUpdateVerificationDot");
        check(String(badgeDot.color).toLowerCase().indexOf("edb65c")>=0
            && String(pageDot.color).toLowerCase().indexOf("edb65c")>=0,
            "unknown verification uses amber dots: " + JSON.stringify({bar:String(badgeDot.color),page:String(pageDot.color)}));
        host.persistSettings({skippedUpdateVersion:""}); flush();
    }
    function earlyReleaseBecomesVerified() {
        var updates=host.runtime.updates;
        var early={status:"available",version:"1.0.1",commit:"c".repeat(40),verification:"unverified"};
        host.persistSettings({skippedUpdateVersion:"",skippedUpdateStage:"",
            promptedUpdateVersion:"",promptedUpdateStage:""}); flush();
        updates.manualResult=early;
        panel.showUpdates(); settle();
        var skip=find(panel,"skipUpdateVersionAction");
        check(updates.offerAvailable && updates.manualStage==="early","early release is initially offered");
        click(skip); flush();
        check(updates.manualSkipped && !updates.offerAvailable
            && host.runtime.preferences.values.skippedUpdateStage==="early",
            "skipping the early release hides its reminder");
        updates.manualResult={status:"available",version:"1.0.1",commit:"c".repeat(40),verification:"unknown"}; settle();
        check(updates.manualSkipped && !updates.offerAvailable,"unknown and unverified are the same early stage");
        updates.manualResult={status:"available",version:"1.0.1",commit:"c".repeat(40),verification:"verified"}; settle();
        check(!updates.manualSkipped && updates.offerAvailable && updates.manualStage==="verified",
            "the same version and commit reappear after catalog verification");
        host.visible=true; settle();
        var badge=find(host,"windowPeekUpdateBadge"), dot=find(host,"windowPeekVerificationDot");
        check(badge.visible && String(dot.color).toLowerCase().indexOf("92d992")>=0,
            "the skipped early release returns as a green bar badge");
        host.visible=false; settle();
        updates.manualResult=early; settle();
        click(skip); flush();
        check(!updates.manualSkipped && updates.offerAvailable,"the early skip can be reversed from Updates");
        panel.mode="windows"; settle();
        check(panel.openInstallPrompt(false),"the early stage prompts once"); flush();
        check(host.runtime.preferences.values.promptedUpdateStage==="early",
            "the prompt remembers the early stage");
        click(find(panel,"skipUpdateVersion")); flush();
        check(updates.manualSkipped && !updates.offerAvailable && !panel.openInstallPrompt(false),
            "modal skip and prompt memory suppress the early offer");
        updates.manualResult={status:"available",version:"1.0.1",commit:"c".repeat(40),verification:"verified"}; settle();
        check(!updates.manualSkipped && updates.offerAvailable && panel.openInstallPrompt(false),
            "catalog approval reopens the prompt for the same skipped release"); flush();
        check(find(panel,"updateConfirmation").installVerification==="verified"
            && host.runtime.preferences.values.promptedUpdateStage==="verified",
            "the second prompt is green and is remembered separately");
        click(find(panel,"cancelUpdateOff"));
        check(!panel.openInstallPrompt(false),"Later does not reopen the verified prompt on every visit");
        host.persistSettings({skippedUpdateVersion:"",skippedUpdateStage:"",
            promptedUpdateVersion:"",promptedUpdateStage:""}); flush();
        updates.manualResult={status:"current"};
    }
    function stableCheckLayout() {
        var updates=host.runtime.updates, start=updates.startManualCheck;
        var button=find(panel,"primaryUpdateAction"), status=find(panel,"manualUpdateStatus"), toggle=find(panel,"manualUpdateChecksToggle");
        waiting=true;
        try {
            asyncWait.wait(30);
            var before={height:status.height,buttonY:button.y,toggleY:toggle.y};
            var previous=JSON.stringify(updates.manualResult);
            updates.startManualCheck=function(force) {
                updates.manualCheck.command=["python3","-c",
                    "import pathlib,sys,time; time.sleep(0.4); pathlib.Path(sys.argv[1]).write_text(sys.argv[2])",
                    updates.manualState.path,previous];
                updates.manualCheck.running=true;
            };
            button.clicked(); asyncWait.wait(50);
            check(updates.manualBusy && !button.enabled && button.text==="Check now","checking does not flash the button label");
            check(status.text==="Checking…" && status.height===before.height,"checking uses reserved status height");
            check(button.y===before.buttonY && toggle.y===before.toggleY,"controls stay put while checking");
            for(var i=0;i<200 && updates.manualBusy;i++) asyncWait.wait(5);
            check(status.text==="Checking…","fast result remains legible");
            for(var i=0;i<200 && !button.enabled;i++) asyncWait.wait(5);
            check(button.y===before.buttonY && toggle.y===before.toggleY,
                "same result preserves layout: " + JSON.stringify({before:before,after:{buttonY:button.y,toggleY:toggle.y},
                    result:updates.manualResult,status:status.text,path:updates.manualState.path}));
        } finally { updates.startManualCheck=start; waiting=false; }
    }
    QtObject {
        id: shell
        function updateEntryInline(id, values) { return true; }
    }
    Ui.PluginBarApi {
        id: bar
        pluginId: "sarr.windowpeek"; moduleName: "sarr.windowpeek"; shell: shell
        position: "top"; barSize: 26; fontFamily: "monospace"; barForeground: "#c0caf5"
        layoutConfig: ({left:[{id:"sarr.windowpeek", language:"en"}], center:[], right:[]})
        _moduleWidgets: function() { return [host]; }
    }
    TestEvent { id: events }
    Window {
        id: window
        visible: true; width: 500 * test.scale; height: 540 * test.scale; color: Commons.Color.popups.background
        Rectangle { anchors.fill: parent; color: Commons.Color.popups.background }
        Plugin.Widget { id: host; bar: bar; visible: false }
        Plugin.PanelContent {
            id: panel; x:16*test.scale; y:16*test.scale; width: window.width / test.scale - 32; height: window.height / test.scale - 32
            scale: test.scale; transformOrigin: Item.TopLeft; hostWidget: host
        }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (test.runningStep || test.waiting || host.runtime.preferences.saving || !host.settingsReady || !host.runtime.updates.ready || !host.updatesAvailable) return;
            test.runningStep = true;
            try {
                switch (test.step++) {
                case 0:
                    Commons.Color.shellValues={}; Commons.Color.foreground="#c0caf5"; Commons.Color.background="#1a1b26"; Commons.Color.accent="#d898f5";
                    test.scheduler(); panel.begin(); break;
                case 1: test.manualUpdates(); break;
                case 2: test.footerAndFocus(); break;
                case 3: test.footerNavigation(); test.skippedVersion(); break;
                case 4: test.earlyReleaseBecomesVerified(); break;
                case 5: test.localizedLayouts(); break;
                case 6: console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.callLater(Qt.quit); break;
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.callLater(Qt.quit); }
            finally { test.runningStep = false; }
        }
    }
}
