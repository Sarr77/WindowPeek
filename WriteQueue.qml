import QtQuick

// Serial atomic FileView writes. A successful enqueue is not a durable save:
// callers publish settings only from the completion callback.
QtObject {
    id: root
    required property var file
    property var jobs: []
    property var active: null
    property bool recovering: false
    property bool needsReload: false
    property string committed: ""
    readonly property bool busy: active !== null || jobs.length > 0 || recovering

    function enqueue(payload, done) {
        jobs = jobs.concat([{payload:payload, done:done}]);
        Qt.callLater(root.flush);
    }
    function flush() {
        if (active || recovering || !jobs.length) return;
        if (needsReload) {
            recovering = true;
            file.reload();
            return;
        }
        active = jobs[0]; jobs = jobs.slice(1);
        if (active.payload === committed) complete(true);
        else file.setText(active.payload);
    }
    function complete(ok) {
        if (!active) return;
        var job = active, rejected = ok ? [] : jobs;
        if (ok) committed = job.payload;
        else { jobs = []; needsReload = true; }
        // Keep busy through publication, including synchronous host echoes.
        try {
            job.done(ok);
            for (var pending of rejected) pending.done(false);
        } finally { active = null; Qt.callLater(root.flush); }
    }
    function reloaded() {
        if (!recovering) return;
        recovering = false; needsReload = false;
        Qt.callLater(root.flush);
    }
    property Connections completion: Connections {
        target: root.file
        function onSaved() { root.complete(true); }
        function onSaveFailed() { root.complete(false); }
        function onLoaded() { root.reloaded(); }
        function onLoadFailed() { root.reloaded(); }
    }
}
