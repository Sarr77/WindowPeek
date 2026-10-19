import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: root
  required property var preferences
  readonly property string path: preferences.directory + "/updates.json"
  property double nextCheck: 0
  property double lastCheck: 0
  property double lastLaunch: 0
  property bool startupPending: true
  readonly property int checkInterval: 6 * 60 * 60
  property bool ready: false
  property string status: ""
  readonly property bool checksEnabled: preferences.ready && preferences.hasSavedValues && !preferences.failed && !preferences.readBlocked
    && (preferences.values.checkUpdates === undefined || preferences.values.checkUpdates === true)
  property var manualResult: ({})
  property double manualLastLaunch: 0
  property bool installLaunchPending: false
  property Timer installLaunchReset: Timer { interval: 5000; onTriggered: root.installLaunchPending = false }
  property bool manualReady: false
  property bool choiceChanged: false
  property bool policyRefreshPending: false
  readonly property bool manualBusy: manualCheck.running
  readonly property bool includeUnverified: preferences.values.includeUnverifiedUpdates !== false
  readonly property bool rawAvailable: manualResult.status === "available" && /^[a-f0-9]{40}$/.test(manualResult.commit || "")
    && /^\d+\.\d+\.\d+$/.test(manualResult.version || "")
    && ["verified", "unverified", "unknown"].indexOf(manualResult.verification) >= 0
  readonly property bool filteredRelease: rawAvailable && !includeUnverified && manualResult.verification !== "verified"
  readonly property bool manualAvailable: rawAvailable && !filteredRelease
  onIncludeUnverifiedChanged: {
    if (!manualReady || !preferences.ready || !preferences.hasSavedValues) return;
    if (manualBusy) policyRefreshPending = true;
    else checkNow();
  }
  onManualBusyChanged: {
    if (!manualBusy && policyRefreshPending) {
      policyRefreshPending = false;
      Qt.callLater(checkNow);
    }
  }
  readonly property string skippedVersion: preferences.values && typeof preferences.values.skippedUpdateVersion === "string"
    ? preferences.values.skippedUpdateVersion : ""
  readonly property string manualStage: manualResult.verification === "verified" ? "verified" : "early"
  // A skipped early release must be offered again if this exact commit gains catalog approval.
  readonly property string skippedStage: preferences.values && preferences.values.skippedUpdateStage === "early"
    ? "early" : "verified"
  readonly property bool manualSkipped: manualAvailable && skippedVersion === manualResult.version
    && skippedStage === manualStage
  readonly property bool installing: manualResult.installing === true
  readonly property bool offerAvailable: checksEnabled && manualAvailable && !manualSkipped && !installing
    && manualResult.installError !== "local-changes"
  // The exact checked commit is revalidated by the worker before installation.
  readonly property bool manualBlocked: manualResult.status === "local-changes" || manualResult.status === "ahead"
  readonly property bool manualCanUpdate: runtimeAvailable && manualAvailable && !manualBlocked && !manualBusy && !installing && !installLaunchPending
    && manualResult.installError !== "local-changes"
  readonly property string workerPath: decodeURIComponent(Qt.resolvedUrl("../update.py").toString().replace(/^file:\/\//, ""))
  property var startManualCheck: function(force) {
    manualCheck.command = ["python3", "-I", "-B", workerPath, "--check-manual"].concat(force ? ["--force"] : []);
    manualCheck.running = true;
  }
  property var startExactInstall: function(commit, version, verification) {
    Quickshell.execDetached(["python3", "-I", "-B", workerPath, "--install-commit", commit,
        "--install-version", version, "--expected-verification", verification]);
  }
  property Process manualCheck: Process {
    onExited: function(code) {
      manualState.reload();
      if (code !== 0) root.manualResult = {status: "failed"};
    }
  }
  property SafeFile manualState: SafeFile {
    path: preferences.directory + "/manual-updates.json"
    maxBytes: 65536; watchChanges: true
    onLoaded: function(content) {
      try { var value = JSON.parse(content); root.manualResult = value && typeof value === "object" ? value : {}; }
      catch (error) { root.manualResult = {}; }
      root.manualReady = true;
    }
    onLoadFailed: function(reason) {
      root.manualResult = {};
      root.manualReady = true;
    }
  }
  function checkManual(widgets, now) {
    if (!checksEnabled || !manualReady || !runtimeAvailable || manualBusy) return;
    if (widgets.some(function(widget) { return widget.opened || widget.hoverOpened || widget.actionBusy; })) return;
    var last = timestamp(manualResult.lastCheck);
    if (manualResult.status === "local-changes" && !manualResult.reason) last = 0;
    if ((last > 0 && now >= last && now < last + checkInterval)
        || (now >= manualLastLaunch && now - manualLastLaunch < 300)) return;
    manualLastLaunch = now;
    startManualCheck(false);
  }
  function checkNow() {
    if (!runtimeAvailable || manualBusy) return false;
    choiceChanged = false;
    manualLastLaunch = Date.now() / 1000;
    startManualCheck(true);
    return true;
  }
  function openManualUpdate(commit, version, verification) {
    if (!manualCanUpdate) { choiceChanged = true; return false; }
    if (manualResult.commit !== commit || manualResult.version !== version
        || manualResult.verification !== verification) { choiceChanged = true; return false; }
    choiceChanged = false;
    installLaunchPending = true;
    installLaunchReset.restart();
    startExactInstall(commit, version, verification);
    return true;
  }
  onInstallingChanged: if (installing) { installLaunchReset.stop(); installLaunchPending = false; }
  function changesUrl() {
    if (!manualAvailable) return "https://github.com/Sarr77/WindowPeek/releases";
    return /^[a-f0-9]{40}$/.test(manualResult.installedCommit || "")
      ? "https://github.com/Sarr77/WindowPeek/compare/" + manualResult.installedCommit + "..." + manualResult.commit
      : "https://github.com/Sarr77/WindowPeek/commit/" + manualResult.commit;
  }
  property bool runtimeAvailable: Quickshell.env("QT_QPA_PLATFORM") !== "offscreen"
  property var launch: function(startup) {
    var command = ["python3", "-I", "-B", decodeURIComponent(Qt.resolvedUrl("../update.py").toString().replace(/^file:\/\//, ""))];
    if (startup) command.push("--startup");
    Quickshell.execDetached(command);
  }
  readonly property bool available: !!source.repository && !!source.latestRelease
  property var source: ({})
  property SafeFile releaseSource: SafeFile {
    path: decodeURIComponent(Qt.resolvedUrl("../release.json").toString().replace(/^file:\/\//, ""))
    maxBytes: 16384
    onLoaded: function(content) { try { root.source = JSON.parse(content); } catch (error) { root.source = {}; } }
    onLoadFailed: root.source = {}
  }
  readonly property bool enabled: available && preferences.ready && preferences.hasSavedValues && !preferences.failed && !preferences.readBlocked
    && (preferences.values.autoUpdates === undefined || preferences.values.autoUpdates === true)
  property SafeFile state: SafeFile {
    path: root.path
    maxBytes: 65536; watchChanges: true
    onLoaded: function(content) {
      try {
        var value = JSON.parse(content);
        root.nextCheck = root.timestamp(value.nextCheck);
        root.lastCheck = root.timestamp(value.lastCheck);
        root.status = value.status || "";
      } catch (error) { root.nextCheck = 0; root.lastCheck = 0; root.status = ""; }
      root.ready = true;
    }
    onLoadFailed: function(reason) {
      if (reason !== "missing") { root.nextCheck = 0; root.lastCheck = 0; root.status = ""; }
      root.ready = true;
    }
  }
  function timestamp(value) {
    return typeof value === "number" && Number.isFinite(value) && value > 0 ? value : 0;
  }
  function checkedToday(now) {
    if (!(lastCheck > 0 && lastCheck <= now)) return false;
    var checked = new Date(lastCheck * 1000), current = new Date(now * 1000);
    return checked.getFullYear() === current.getFullYear() && checked.getMonth() === current.getMonth()
      && checked.getDate() === current.getDate();
  }
  function dueAt(now) {
    // Derive from the recorded attempt to migrate the old 24-hour schedule.
    if (lastCheck > 0 && lastCheck <= now) return lastCheck + checkInterval;
    return nextCheck > now && nextCheck <= now + checkInterval ? nextCheck : 0;
  }
  function check(widgets, now) {
    if (now === undefined) now = Date.now() / 1000;
    if (!runtimeAvailable || installing) return;
    checkManual(widgets, now);
  }
}
