import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "FocusIncident.js" as Policy
import "FocusInterruptions.js" as Interruptions
import "FocusWatch.js" as Watch
import "ShortcutBindings.js" as Bindings
import "FocusRecoveryText.js" as Texts
import "FocusIssues.js" as Issues

QtObject {
    id: root
    required property var state
    property var panel: null
    property var session: null
    property var guard: Policy.protection()
    property var interruptions: Interruptions.history()
    property bool interrupted: false
    property bool suggested: false
    property bool manualFailed: false
    property bool temporaryFailed: false
    property int recoveryAttempts: 0
    property string lastBackendFailure: ""
    property double lastBackendFailureAt: 0
    readonly property bool protectionFailed: manualFailed || temporaryFailed
    readonly property bool retrying: backendRetry.running
    property int revision: 0
    property FocusIssues issues: FocusIssues { onChanged: root.applyIgnoreChoices() }
    property string incidentAppKey: ""
    property var offered: null
    property var stoppedOffer: null
    // Explicit, in-memory consent when no source window can be identified.
    // Closing a panel does not end it; restarting the bar does.
    property bool sessionProtection: false
    property bool sessionProtectionStopped: false
    readonly property bool offeringStopped: !!offered && offered === stoppedOffer
    property string protectionApp: ""
    property var incidentContext: null
    readonly property string contextApp: incidentContext ? incidentContext.app : ""
    onGrantedChanged: if (!granted) protectionApp = ""
    property var sources: []
    property real sourcesAt: 0
    property var dismissed: ({})
    property bool pendingApproval: false
    property double approvalStarted: 0
    onPendingApprovalChanged: if (!pendingApproval) approvalTimeout.stop()
    property bool observerFailed: false
    property bool observerStopping: false
    property string message: ""
    property string language: "en"
    readonly property var copy: Texts.words(language)
    readonly property string backend: "native-window:1"
    readonly property bool windowGranted: { revision; return guard.grant !== null; }
    readonly property bool granted: windowGranted || sessionProtection
    readonly property bool manualEnabled: !!panel && !!panel.hostWidget && panel.hostWidget.keepSearchFocus === true
    readonly property bool backendAvailable: Hyprland.usingLua && Quickshell.env("QT_QPA_PLATFORM") !== "offscreen"
    readonly property bool manualRequested: manualEnabled && !manualFailed && backendAvailable
    readonly property bool requested: manualRequested || (granted && !temporaryFailed)
    // Detection pauses around preview mapping. Approved protection yields only
    // for actual preview interaction, handled by WindowPanel, not its visibility.
    readonly property bool protecting: { revision; return manualRequested
        ? protectionEligible && panel.body.mode === "windows"
        : !temporaryFailed && (sessionProtection ? protectionEligible : guard.active); }
    readonly property bool tracking: !!panel && panel.opened && !granted && !manualEnabled
        && backendAvailable;
    readonly property bool watching: tracking && !observerFailed
    // Compact keyboard readiness supports shortcuts/type-to-search. Losing it
    // while browsing is not an interrupted search and must not create an incident.
    readonly property bool searchEligible: !!panel && panel.opened
        && panel.body.expanded && panel.body.mode === "windows" && !panel.body.busy && !panel.body.interacting
        && !panel.body.currentPopup && !panel.body.recoveryOpen
        && !panel.destinationMenu.opened && !panel.childPreviewVisible
    readonly property bool eligible: searchEligible && !panel.opening
    readonly property bool protectionEligible: !!panel && panel.opened && !panel.opening
        && !panel.body.busy && !panel.body.interacting && !panel.body.currentPopup
        && !panel.body.recoveryOpen && !panel.destinationMenu.opened
    // Showing a passive thumbnail must not release search's keyboard hold.
    // WindowPanel handles actual pointer interaction with the preview separately.
    readonly property bool nativeActive: !!panel && panel.surface.nativeActive
    readonly property string identity: Date.now().toString(36) + ":" + Math.random().toString(36).slice(2)
    property int sequence: 0
    property string owner: ""
    signal notification(string text)
    function diagnosticStatus() {
        // No titles, search text or source identifiers in the support IPC.
        return {watching: watching, tracking: tracking, suggested: suggested, interrupted: interrupted,
            sessionProtection: sessionProtection, sessionProtectionStopped: sessionProtectionStopped,
            manualEnabled: manualEnabled, manualFailed: manualFailed, temporaryFailed: temporaryFailed,
            retrying: retrying, recoveryAttempts: recoveryAttempts, lastBackendFailure: lastBackendFailure, lastBackendFailureAt: lastBackendFailureAt,
            eligible: eligible, observerFailed: observerFailed,
            observerRunning: observer.running, sourceCount: sources.length,
            phase: session ? session.phase : "closed", acquired: !!session && session.acquired,
            lossRecorded: !!session && session.lostAt !== null,
            settling: !!session && Date.now() < session.quietUntil};
    }
    function attach(value) {
        if (panel === value) return;
        detach(panel);
        backendRetry.stop(); recoveryAttempts = 0;
        manualFailed = false; temporaryFailed = false; interrupted = false; incidentAppKey = "";
        panel = value; observerFailed = false; message = "";
        language = value.hostWidget ? value.hostWidget.language : "en";
        owner = identity + ":" + (++sequence);
        suggested = panel.body.expanded && !issues.muted("") && Interruptions.suggested(interruptions, Date.now());
        session = Policy.session(owner, Date.now());
        Policy.focus(session, owner, nativeActive, Date.now(), eligible);
        state.refresh();
        if (tracking) Hyprland.dispatch(Bindings.dispatch(Watch.install(owner)));
        if (watching) startObserver();
    }
    function detach(value) {
        if (panel !== value) return;
        backendRetry.stop();
        stopObserver();
        if (owner && Hyprland.usingLua) Hyprland.dispatch(Bindings.dispatch(Watch.release(owner)));
        Policy.end(session); session = null; owner = "";
        offered = null; pendingApproval = false; interrupted = false;
        panel = null; guard.active = false; revision++;
    }
    function suspend() { Policy.suspend(session, owner, Date.now()); }
    function startObserver() {
        if (!watching || !owner || observer.running || observerStopping) return;
        observer.running = true;
    }
    function stopObserver() {
        if (observer.running) { observerStopping = true; observer.running = false; }
        sources = []; sourcesAt = 0;
    }
    onManualEnabledChanged: {
        backendRetry.stop(); recoveryAttempts = 0; temporaryFailed = false;
        if (manualEnabled) {
            sessionProtection = false; sessionProtectionStopped = false;
            // A durable, deliberate choice replaces any dormant source-specific grant.
            Policy.stopProtection(guard, "user"); Policy.takeNotice(guard); revision++;
            offered = null; stoppedOffer = null; pendingApproval = false;
            interruptions = Interruptions.history(); suggested = false; interrupted = false;
        } else manualFailed = false;
    }
    onTrackingChanged: {
        if (!owner || !Hyprland.usingLua) return;
        Hyprland.dispatch(Bindings.dispatch(tracking ? Watch.install(owner) : Watch.release(owner)));
    }
    function dismissSuggestion() {
        Interruptions.dismiss(interruptions, Date.now()); suggested = false; interrupted = false;
    }
    onWatchingChanged: if (watching) startObserver(); else stopObserver()
    onEligibleChanged: {
        if (!eligible) suspend();
        reconcile();
    }
    onProtectionEligibleChanged: reconcile()
    onNativeActiveChanged: {
        if (!session) return;
        if (nativeActive && tracking && session.phase === "dismissed") {
            session.phase = "observing"; session.incident = null;
        }
        if (nativeActive) incidentAppKey = "";
        Policy.focus(session, owner, nativeActive, Date.now(), eligible);
        if (!nativeActive && eligible) state.refresh();
    }
    function sourceSnapshot() {
        return {at: Math.min(sourcesAt, state.observedAt), sources: sources,
            clients: state.snapshot ? state.snapshot.clients : []};
    }
    function receive(line) {
        var event;
        if (line.length > 131072) return;
        try { event = JSON.parse(line); } catch (_) { return; }
        if (!event || !watching || observerStopping || !session) return;
        if (event.kind === "sources" && Array.isArray(event.sources) && event.sources.length <= 256) {
            sources = event.sources; sourcesAt = event.at;
            finishApproval();
        } else if (event.kind === "geometry") {
            // Buffer tentative geometry. Attribution is validated against fresh
            // XRes + compositor identities before offering or approving anything.
            event.atRisk = true;
            Policy.geometry(session, owner, event);
        } else if (event.kind === "forget") {
            Policy.forgetSource(session, owner, event.id);
            if (offered && offered.source.id === event.id) { offered = null; pendingApproval = false; }
            if (stoppedOffer && stoppedOffer.source.id === event.id) stoppedOffer = null;
            state.refresh();
        } else if (event.kind === "unavailable") observerFailed = true;
    }
    function inspect() {
        if (!session || offered || granted || manualEnabled || !watching || !eligible || !issues.ready) return;
        var now = Date.now(), snapshot = sourceSnapshot();
        if (!snapshot.at || now - snapshot.at > 500) return;
        var incident = Policy.inspect(session, owner, now, true);
        if (!incident) return;
        var source = Policy.candidateSource(snapshot, incident.source, now);
        if (!source) { Policy.revoke(session, owner); return; }
        var client = snapshot.clients.find(function(c) { return c.address === source.address; });
        incidentAppKey = Issues.appKey(Issues.clean(client.initialClass || client.class, 256));
        issues.record(client, now);
        if (issues.muted(incidentAppKey)) {
            interrupted = false; suggested = false; Policy.revoke(session, owner); return;
        }
        if (dismissed[source.stableId]) { Policy.revoke(session, owner); return; }
        offered = {source: source, app: client.app || client.class || "X11", klass: client.class || "", appKey: incidentAppKey};
        incidentContext = offered;
    }
    function restoreStoppedOffer() {
        if (!stoppedOffer || offered || granted || manualEnabled || !session || !panel || !panel.opened) return;
        if (issues.muted(stoppedOffer.appKey)) { stoppedOffer = null; return; }
        var source = stoppedOffer.source;
        if (!state.snapshot || !state.snapshot.clients.some(function(c) {
            return c.stableId === source.stableId && c.address === source.address && c.pid === source.pid;
        })) return;
        // Keep access to a previously reviewed incident, not permission to act.
        // Approval still waits for fresh XRes and compositor identity samples.
        offered = stoppedOffer;
        incidentAppKey = offered.appKey || "";
        session.phase = "offered"; session.incident = {source:source.id}; session.consent = false;
    }
    function applyIgnoreChoices() {
        if (!issues.muted(incidentAppKey)) return;
        stoppedOffer = null; sessionProtectionStopped = false;
        interrupted = false; suggested = false;
        if (offered) { Policy.decide(session, owner, "dismiss", false); offered = null; pendingApproval = false; }
    }
    function ignore(scope, done) {
        var key = offered ? offered.appKey : incidentAppKey;
        if (scope === "app" && !key) { if (done) done(false); return false; }
        return issues.choose(scope, true, key, function(ok) {
            if (!ok) message = copy.saveFailed;
            else {
                stoppedOffer = null; sessionProtectionStopped = false;
                interrupted = false; suggested = false;
                Policy.decide(session, owner, "dismiss", false); offered = null; pendingApproval = false;
            }
            if (done) done(ok);
        });
    }
    function decline() {
        stoppedOffer = null; sessionProtectionStopped = false;
        interrupted = false;
        if (offered) dismissed[offered.source.stableId] = true;
        Policy.decide(session, owner, "dismiss", false);
        offered = null; pendingApproval = false;
    }
    function enableSessionProtection() {
        if (!panel || !panel.opened || !backendAvailable || manualEnabled || granted) return;
        if (offered) { approve(); return; }
        sessionProtectionStopped = false;
        temporaryFailed = false; recoveryAttempts = 0; backendRetry.stop();
        message = ""; protectionApp = "";
        sessionProtection = true;
        interrupted = false; suggested = false;
        panel.body.recoveryOpen = false;
    }
    function approve() {
        if (!offered || !panel || !panel.opened || pendingApproval) return;
        approvalStarted = Date.now();
        pendingApproval = true; message = ""; approvalTimeout.restart(); state.refresh();
    }
    function finishApproval() {
        if (!pendingApproval) return;
        if (!offered || !panel || !panel.opened) { pendingApproval = false; return; }
        var now = Date.now();
        // The compositor reader and XRes observer update independently. A fresh
        // compositor reply is not proof that the older XRes sample is invalid.
        // Wait for both post-click samples without weakening identity checks.
        if (sourcesAt < approvalStarted || now - sourcesAt > 500) return;
        if (state.observedAt < approvalStarted || now - state.observedAt > 500) {
            if (!state.busy) state.refresh();
            return;
        }
        pendingApproval = false;
        var source = Policy.candidateSource(sourceSnapshot(), offered.source.id, now);
        if (!source || source.stableId !== offered.source.stableId
                || source.address !== offered.source.address || source.pid !== offered.source.pid
                || !Policy.decide(session, owner, "allow-for-window", true, guard, source, backend)) {
            message = copy.changed; return;
        }
        protectionApp = offered.app || offered.klass || "";
        incidentContext = offered; stoppedOffer = null; sessionProtectionStopped = false;
        offered = null; interrupted = false; suggested = false;
        panel.body.recoveryOpen = false;
        revision++; reconcile();
    }
    property Timer approvalTimeout: Timer {
        interval: 2500
        onTriggered: {
            if (!root.pendingApproval) return;
            root.pendingApproval = false;
            root.message = root.copy.changed;
        }
    }
    function retryProtection(explicit) {
        backendRetry.stop();
        if (!panel || !panel.opened || (!manualEnabled && !granted)) return;
        if (explicit === true) recoveryAttempts = 0;
        manualFailed = false; temporaryFailed = false;
        state.refresh(); reconcile();
    }
    property Timer backendRetry: Timer {
        interval: 500
        onTriggered: root.retryProtection(false)
    }
    function stop(reason, detail) {
        if (reason === "backend-unavailable") {
            if ((!manualEnabled && !granted) || protectionFailed) return;
            lastBackendFailure = detail || "backend-unavailable";
            lastBackendFailureAt = Date.now();
            manualFailed = manualEnabled; temporaryFailed = granted;
            guard.active = false; revision++;
            // Preserve the user's setting or approved window lifetime. Retry a
            // transient backend failure twice per opening, never in a tight loop.
            if (panel && panel.opened && recoveryAttempts < 2) {
                recoveryAttempts++; backendRetry.restart();
            } else notification(copy.recoveryUnavailable);
            return;
        }
        backendRetry.stop(); temporaryFailed = false; recoveryAttempts = 0;
        if (sessionProtection) {
            sessionProtection = false;
            sessionProtectionStopped = !reason || reason === "user";
            if (sessionProtectionStopped) notification(copy.stopped);
        }
        if ((!reason || reason === "user") && guard.grant && incidentContext
                && incidentContext.source.stableId === guard.grant.stableId) stoppedOffer = incidentContext;
        Policy.stopProtection(guard, reason || "user"); revision++;
        restoreStoppedOffer();
        deliverNotice();
    }
    function reconcile() {
        if (!guard.grant) return;
        Policy.reconcileProtection(guard, {at:state.observedAt, complete:!!state.snapshot, pending:state.busy,
            clients:state.snapshot ? state.snapshot.clients : []}, Date.now(), protectionEligible && !temporaryFailed, backend);
        revision++; deliverNotice();
    }
    function deliverNotice() {
        var notice = Policy.takeNotice(guard);
        if (!notice) return;
        var text = notice.reason === "window-closed" ? copy.ended
            : notice.reason === "backend-unavailable" ? copy.failed : copy.stopped;
        // Let the panel release its native lease and return the content first.
        Qt.callLater(function() { root.notification(text); });
    }
    property Process observer: Process {
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("tools/focus_observer.py").toString().replace(/^file:\/\//, ""))]
        stdinEnabled: true
        stdout: SplitParser { onRead: function(line) { root.receive(line); } }
        stderr: StdioCollector { }
        onExited: function(code) {
            var expected = root.observerStopping;
            root.observerStopping = false;
            if (!expected && root.watching) root.observerFailed = true;
            else Qt.callLater(root.startObserver);
        }
    }
    property Timer tick: Timer {
        interval: 100; repeat: true; running: root.tracking
        onTriggered: {
            if (observer.running) observer.write("ping\n");
            var now = Date.now();
            // Resolve available attribution before deciding whether this loss is muted.
            root.inspect();
            var muted = root.issues.muted(root.incidentAppKey);
            if (Interruptions.observe(root.interruptions, root.session, root.owner, now, root.eligible) && !muted)
                root.interrupted = true;
            root.suggested = root.panel.body.expanded && !muted && Interruptions.suggested(root.interruptions, now);
            if (muted) root.interrupted = false;
        }
    }
    property Timer watchLease: Timer {
        interval: 250; repeat: true; running: root.tracking && root.owner !== ""
        onTriggered: {
            Hyprland.dispatch(Bindings.dispatch(Watch.renew(root.owner)));
            if (root.session && root.session.lostAt !== null && !root.state.busy) root.state.refresh();
        }
    }
    property Timer guardPoll: Timer {
        interval: root.panel && root.panel.opened ? 250 : 1000; repeat: true; running: root.windowGranted || root.incidentContext !== null
        onTriggered: { if (!root.state.busy) root.state.refresh(); root.reconcile(); }
    }
    property Connections observations: Connections {
        target: root.state
        function onRefreshed() {
            var alive = {};
            for (var client of root.state.snapshot.clients || []) alive[client.stableId] = true;
            for (var id of Object.keys(root.dismissed)) if (!alive[id]) delete root.dismissed[id];
            if (root.incidentContext) {
                var source = root.incidentContext.source;
                var aliveSource = root.state.snapshot.clients.some(function(c) {
                    return c.stableId === source.stableId && c.address === source.address && c.pid === source.pid;
                });
                if (!aliveSource) {
                    if (root.offeringStopped) { root.offered = null; root.pendingApproval = false; Policy.revoke(root.session, root.owner); }
                    root.stoppedOffer = null; root.incidentContext = null;
                }
            }
            root.restoreStoppedOffer(); root.finishApproval(); root.reconcile(); root.inspect();
        }
        function onFailed() { root.pendingApproval = false; root.message = root.copy.changed; root.reconcile(); }
    }
    property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (/^(workspace|activespecial|openwindow|closewindow|movewindow|monitor|configreloaded)/.test(event.name)) root.suspend();
            if (event.name === "configreloaded") {
                root.stopObserver();
                if (root.tracking && root.owner) Hyprland.dispatch(Bindings.dispatch(Watch.install(root.owner)));
                if (root.watching) root.startObserver();
            }
            if (event.name !== "custom" || !root.owner) return;
            var prefix = "windowpeek-focus-reason," + root.owner + ",";
            // Merely moving the pointer (including to another monitor) is not
            // an intentional transfer of search's keyboard focus. Actual outside
            // clicks, workspace changes and explicit focus commands still suspend.
            if (event.data.indexOf(prefix) === 0
                    && ["1", "5"].indexOf(event.data.slice(prefix.length)) < 0) root.suspend();
        }
    }
    Component.onDestruction: { stopObserver(); if (owner && Hyprland.usingLua) Hyprland.dispatch(Bindings.dispatch(Watch.release(owner))); Policy.end(session); }
}
