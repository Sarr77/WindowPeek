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
  property bool manualReady: false
  property bool manualLaunchFailed: false
  readonly property bool manualBusy: manualCheck.running
  readonly property bool manualAvailable: manualResult.status === "available" && /^[a-f0-9]{40}$/.test(manualResult.commit || "")
    && /^\d+\.\d+\.\d+$/.test(manualResult.version || "")
  // Native Omarchy checks the repository itself. A successful metadata check is
  // not a prerequisite for an explicit update; known unsafe copies stay blocked.
  readonly property bool manualBlocked: manualResult.status === "local-changes" || manualResult.status === "ahead"
  readonly property bool manualCanUpdate: runtimeAvailable && !manualBlocked && !manualBusy && !terminal.running
    && (manualResult.status !== "available" || manualAvailable)
  readonly property string workerPath: decodeURIComponent(Qt.resolvedUrl("update.py").toString().replace(/^file:\/\//, ""))
  property var startManualCheck: function(force) {
    manualCheck.command = ["python3", "-I", "-B", workerPath, "--check-manual"].concat(force ? ["--force"] : []);
    manualCheck.running = true;
  }
  property var startTerminal: function() {
    terminal.command = ["omarchy", "launch", "terminal", "python3", "-I", "-B", workerPath, "--manual-update"];
    terminal.running = true;
  }
  property Process manualCheck: Process {
    onExited: function(code) {
      manualState.reload();
      if (code !== 0) root.manualResult = {status: "failed"};
    }
  }
  property Process terminal: Process {
    onExited: function(code) { root.manualLaunchFailed = code !== 0; }
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
      if (reason !== "missing") root.manualResult = {};
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
    manualLastLaunch = Date.now() / 1000;
    startManualCheck(true);
    return true;
  }
  function openManualUpdate() {
    if (!manualCanUpdate) return false;
    manualLaunchFailed = false;
    startTerminal();
    return true;
  }
  function changesUrl() {
    if (!manualAvailable) return "https://github.com/Sarr77/WindowPeek/commits/main/";
    return /^[a-f0-9]{40}$/.test(manualResult.installedCommit || "")
      ? "https://github.com/Sarr77/WindowPeek/compare/" + manualResult.installedCommit + "..." + manualResult.commit
      : "https://github.com/Sarr77/WindowPeek/commit/" + manualResult.commit;
  }
  property bool runtimeAvailable: Quickshell.env("QT_QPA_PLATFORM") !== "offscreen"
  property var launch: function(startup) {
    var command = ["python3", "-I", "-B", decodeURIComponent(Qt.resolvedUrl("update.py").toString().replace(/^file:\/\//, ""))];
    if (startup) command.push("--startup");
    Quickshell.execDetached(command);
  }
  readonly property bool available: !!source.repository && !!source.latestRelease
  property var source: ({})
  property SafeFile releaseSource: SafeFile {
    path: decodeURIComponent(Qt.resolvedUrl("release.json").toString().replace(/^file:\/\//, ""))
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
    if (!runtimeAvailable || manualBusy || terminal.running
        || widgets.some(function(widget) { return widget.opened || widget.hoverOpened || widget.actionBusy; })) return;
    if (!enabled || !ready) { checkManual(widgets, now); return; }
    var startup = startupPending && !checkedToday(now);
    startupPending = false;
    if ((!startup && now < dueAt(now)) || (now >= lastLaunch && now - lastLaunch < 300)) {
      checkManual(widgets, now);
      return;
    }
    lastLaunch = now;
    // A detached worker can finish its atomic install even when the shell reloads.
    launch(startup);
  }
}
