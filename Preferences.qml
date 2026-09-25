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
  readonly property bool saving: writes.busy
  property var pendingValues: null
  readonly property var requestedValues: pendingValues || values
  property int requestId: 0
  property WriteQueue writes: WriteQueue { file: root.file }

  function load(raw) {
    if (ready) return;
    try {
      var data = JSON.parse(raw);
      if (!data || data.version !== 1 || !data.settings || typeof data.settings !== "object" || Array.isArray(data.settings)) throw new Error("invalid preferences");
      values = data.settings;
      lastPayload = JSON.stringify({version:1,settings:values},null,2) + "\n";
      writes.committed = lastPayload;
    } catch (e) { failed = true; readBlocked = true; }
    ready = true;
  }
  function save(settings, done) {
    if (!ready || readBlocked) { if (done) done(false); return false; }
    var next = JSON.parse(JSON.stringify(settings));
    delete next.id;
    var payload = JSON.stringify({version:1,settings:next},null,2) + "\n";
    var id = ++requestId;
    pendingValues = next;
    writes.enqueue(payload, function(ok) {
      failed = !ok;
      if (ok) { values = next; lastPayload = payload; }
      if (id === requestId) pendingValues = null;
      if (done) done(ok);
    });
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
    blockWrites: false
    printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: function(error) {
      if (!path || root.ready) return;
      if (error !== FileViewError.FileNotFound) { root.failed = true; root.readBlocked = true; }
      root.ready = true;
    }
  }
}
