import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "WindowModel.js" as Model
import "WindowCommands.js" as Commands

QtObject {
    id: root
    required property var state
    property bool supported: Hyprland.usingLua
    property var job: null
    property string error: ""
    readonly property bool busy: job !== null || runner.running
    property int generation: 0
    property var execute: function(command, token) {
        runner.token = token;
        runner.command = ["hyprctl", "eval", command];
        runner.running = true;
    }
    signal completed(string kind, string address)
    signal failed(string kind, string address)

    function start(kind, address, destination, beforeApply, monitorName) {
        if (busy) return false;
        error = "";
        var id = Model.address(address);
        if (!supported) { error = "unsupported"; return false; }
        if (!id) { error = "windowClosed"; return false; }
        generation++;
        job = { kind: kind, address: id, destination: destination, phase: "read",
            revision: state.revision, beforeApply: beforeApply, monitorName: monitorName };
        deadline.restart();
        state.refresh();
        return true;
    }
    function focus(address, beforeApply) { return start("focus", address, "", beforeApply); }
    function move(address, destination) { return start("move", address, destination, null); }
    function bring(address, monitorName, beforeApply) { return start("bring", address, "", beforeApply, monitorName); }
    function fail(key) {
        if (!job) return;
        var old = job;
        job = null;
        deadline.stop(); poll.stop();
        runner.running = false;
        error = key;
        failed(old.kind, old.address);
    }
    function receive(token, code, output) {
        if (!job || token !== generation || job.phase !== "apply") return;
        if (code !== 0 || output.trim() !== "ok") { fail(Commands.failure(output)); return; }
        job.phase = "verify";
        job.revision = state.revision;
        state.refresh();
        poll.start();
    }
    function apply(token) {
        if (!job || token !== generation || job.phase !== "prepare") return;
        job.phase = "apply";
        execute(job.command, token);
    }
    function observe() {
        if (!job || state.revision <= job.revision) return;
        var win = Commands.client(state.snapshot, job.address);
        if (!win) { fail("windowClosed"); return; }
        if (job.phase === "read") {
            var command;
            if (job.kind === "move" || job.kind === "bring") {
                var plan = job.kind === "bring" ? Commands.bring(state.snapshot, job.address, job.monitorName)
                    : Commands.move(state.snapshot, job.address, job.destination);
                if (!plan) { fail("destinationChanged"); return; }
                command = plan.command;
                job.target = plan.target;
                job.source = plan.source;
                job.targetMonitor = plan.monitor;
            } else command = Commands.focus(job.address);
            job.command = command;
            job.phase = "prepare";
            var token = generation;
            if (job.beforeApply) job.beforeApply(function() { root.apply(token); });
            else apply(token);
        } else if (job.phase === "verify") {
            var done = job.kind === "focus" ? Model.address(state.snapshot.activeAddress) === job.address
                : win.workspace && win.workspace.name === job.target;
            if (job.kind === "bring")
                done = done && win.monitor === job.targetMonitor && Model.address(state.snapshot.activeAddress) === job.address;
            if (done) {
                var old = job;
                job = null; deadline.stop(); poll.stop();
                completed(old.kind, old.address);
            } else if (job.kind !== "focus" && (!win.workspace
                || (win.workspace.name !== job.source && win.workspace.name !== job.target))) fail("windowChanged");
        }
    }
    property Connections observations: Connections {
        target: root.state
        function onRefreshed() { root.observe(); }
        function onFailed() { root.fail("unavailable"); }
    }
    property Process runner: Process {
        property int token: 0
        stdout: StdioCollector { id: response }
        stderr: StdioCollector { }
        onExited: function(code) { root.receive(token, code, response.text); }
    }
    property Timer poll: Timer { interval: 100; repeat: true; onTriggered: root.state.refresh() }
    property Timer deadline: Timer { interval: 3000; onTriggered: root.fail("actionTimeout") }
}
