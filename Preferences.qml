import QtQuick
import Quickshell
import Quickshell.Io

// The bar's inline entry is a host-owned placement, removed when disabled.
// Keep only WindowPeek preferences in an independent, durable user file.
QtObject {
  id: root
  readonly property string directory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/windowpeek"
  readonly property string path: directory + "/preferences.json"
  property var values: ({})
  property bool ready: false
  property bool failed: false
  property bool readBlocked: false
  property string lastPayload: ""
  readonly property bool hasSavedValues: lastPayload !== ""
  property bool writeSucceeded: false

  function load(raw) {
    if (ready) return;
    try {
      var data = JSON.parse(raw);
      if (!data || data.version !== 1 || !data.settings || typeof data.settings !== "object" || Array.isArray(data.settings)) throw new Error("invalid preferences");
      values = data.settings;
      lastPayload = JSON.stringify({version:1,settings:values},null,2) + "\n";
    } catch (e) { failed = true; readBlocked = true; }
    ready = true;
  }
  function save(settings) {
    if (!ready || readBlocked) return false;
    var next = JSON.parse(JSON.stringify(settings));
    delete next.id;
    var payload = JSON.stringify({version:1,settings:next},null,2) + "\n";
    // A failed FileView write can leave its cache ahead of the file on disk.
    // Reload it before retrying, and require an actual successful save signal.
    if (failed) { file.reload(); file.waitForJob(); }
    if (payload === lastPayload) { failed = false; return true; }
    failed = false;
    writeSucceeded = false;
    file.setText(payload);
    file.waitForJob();
    if (!writeSucceeded) { failed = true; return false; }
    values = next; lastPayload = payload;
    return true;
  }
  property Process prepare: Process {
    command: ["mkdir", "-p", "-m", "700", root.directory]
    running: true
    onExited: function(code) {
      if (code !== 0) { root.failed = true; root.readBlocked = true; root.ready = true; return; }
      root.file.path = root.path;
    }
  }
  property FileView file: FileView {
    path: ""
    atomicWrites: true
    blockWrites: true
    printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: function(error) {
      if (!path || root.ready) return;
      if (error !== FileViewError.FileNotFound) { root.failed = true; root.readBlocked = true; }
      root.ready = true;
    }
    onSaveFailed: root.failed = true
    onSaved: root.writeSucceeded = true
  }
}
