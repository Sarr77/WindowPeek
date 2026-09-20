import QtQuick
import Quickshell
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property int commands: 0
    property int completed: 0
    property int token: 0
    property var releasePanel: null
    function check(value, message) { if (!value) throw new Error(message); }
    FakeHost { id: host }
    QtObject {
        id: state
        property int revision: 0
        property var snapshot: host.snapshot
        signal refreshed(int revision)
        signal failed()
        function refresh() { Qt.callLater(function() { state.revision++; state.refreshed(state.revision); }); }
    }
    Plugin.WindowActions {
        id: actions; state: state; supported: true
        execute: function(command, token) { test.commands++; test.token = token; }
        onCompleted: test.completed++
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0:
                    test.check(actions.focus("0x2", null), "focus accepted");
                    test.check(!actions.move("0x1", "4"), "concurrent operation rejected"); break;
                case 1:
                    test.check(test.commands === 1 && actions.busy, "exactly one command after fresh snapshot");
                    actions.receive(test.token - 1, 0, "ok");
                    test.check(actions.job.phase === "apply", "stale response ignored");
                    actions.receive(test.token, 0, "ok"); break;
                case 2:
                    test.check(actions.busy && test.completed === 0, "dispatch response is not completion");
                    var next = JSON.parse(JSON.stringify(state.snapshot)); next.activeAddress = "0x2"; state.snapshot = next; state.refresh(); break;
                case 3:
                    test.check(!actions.busy && test.completed === 1, "focus confirmed by compositor state");
                    actions.move("0x1", "4"); break;
                case 4:
                    actions.receive(test.token, 0, "Lua error: groupLocked");
                    test.check(!actions.busy && actions.error === "groupLocked", "locked group is reported without retry");
                    actions.focus("0xff", null); break;
                case 5:
                    test.check(!actions.busy && actions.error === "windowClosed", "closed target cannot dispatch");
                    test.check(test.commands === 2, "no retarget or retry");
                    actions.move("0x1", "4"); break;
                case 6:
                    actions.receive(test.token, 0, "ok");
                    var moved = JSON.parse(JSON.stringify(state.snapshot));
                    moved.clients[0].workspace = { id: 4, name: "4" }; moved.clients[0].grouped = [];
                    state.snapshot = moved; state.refresh(); break;
                case 7:
                    test.check(!actions.busy && test.completed === 2, "move confirmed at explicit destination");
                    actions.focus("0x1", null); break;
                case 8:
                    state.failed();
                    test.check(!actions.busy && actions.error === "unavailable", "connection failure clears pending action");
                    actions.focus("0x1", function(ready) { test.releasePanel = ready; }); break;
                case 9:
                    test.check(actions.job.phase === "prepare" && !!test.releasePanel, "focus waits for panel release");
                    var count = test.commands;
                    test.releasePanel(); test.releasePanel();
                    test.check(test.commands === count + 1, "surface release dispatches exactly once");
                    actions.receive(test.token, 0, "ok"); break;
                case 10:
                    state.failed();
                    var beforeBring = JSON.parse(JSON.stringify(state.snapshot)); beforeBring.activeAddress = "0x3";
                    state.snapshot = beforeBring;
                    test.releasePanel = null;
                    test.check(actions.bring("0x2", "TEST-B", function(ready) { test.releasePanel = ready; }), "bring accepted");
                    break;
                case 11:
                    test.check(actions.job.phase === "prepare" && !!test.releasePanel, "bring waits for panel release");
                    test.releasePanel();
                    actions.receive(test.token, 0, "ok");
                    var brought = JSON.parse(JSON.stringify(state.snapshot));
                    brought.clients[1].workspace = { id: 4, name: "4" }; brought.clients[1].monitor = 8;
                    state.snapshot = brought; state.refresh(); break;
                case 12:
                    test.check(actions.busy && test.completed === 2, "bring requires focus as well as destination");
                    var activated = JSON.parse(JSON.stringify(state.snapshot)); activated.activeAddress = "0x2";
                    state.snapshot = activated; state.refresh(); break;
                case 13:
                    test.check(!actions.busy && test.completed === 3, "bring verifies workspace, monitor and active address");
                    actions.bring("0x2", "disconnected", null); break;
                case 14:
                    test.check(!actions.busy && actions.error === "destinationChanged", "bring refuses a missing monitor");
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
