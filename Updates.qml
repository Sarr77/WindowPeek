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
  property bool runtimeAvailable: Quickshell.env("QT_QPA_PLATFORM") !== "offscreen"
  property var launch: function(startup) {
    var command = ["python3", "-I", "-B", decodeURIComponent(Qt.resolvedUrl("update.py").toString().replace(/^file:\/\//, ""))];
    if (startup) command.push("--startup");
    Quickshell.execDetached(command);
  }
  readonly property bool available: !!source.repository && !!source.latestRelease
  property var source: ({})
  property FileView releaseSource: FileView {
    path: Qt.resolvedUrl("release.json")
    printErrors: false
    onLoaded: { try { root.source = JSON.parse(text()); } catch (error) { root.source = {}; } }
  }
  readonly property bool enabled: available && preferences.ready && preferences.hasSavedValues && !preferences.failed && !preferences.readBlocked
    && (preferences.values.autoUpdates === undefined || preferences.values.autoUpdates === true)
  property FileView state: FileView {
    path: root.path
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var value = JSON.parse(text());
        root.nextCheck = root.timestamp(value.nextCheck);
        root.lastCheck = root.timestamp(value.lastCheck);
        root.status = value.status || "";
      } catch (error) { root.nextCheck = 0; root.lastCheck = 0; root.status = ""; }
      root.ready = true;
    }
    onLoadFailed: root.ready = true
    onFileChanged: reload()
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
    if (!enabled || !ready || !runtimeAvailable) return;
    if (widgets.some(function(widget) { return widget.opened || widget.hoverOpened || widget.actionBusy; })) return;
    if (now === undefined) now = Date.now() / 1000;
    var startup = startupPending && !checkedToday(now);
    startupPending = false;
    if ((!startup && now < dueAt(now)) || (now >= lastLaunch && now - lastLaunch < 300)) return;
    lastLaunch = now;
    // A detached worker can finish its atomic install even when the shell reloads.
    launch(startup);
  }
}
