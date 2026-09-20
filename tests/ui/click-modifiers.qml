import QtQuick
import QtQuick.Window
import Quickshell
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int calls: 0
    property int value: 0
    property string token: ""
    function check(ok, message) { if (!ok) throw new Error(message); }
    function reply(bits, token) { area.receive("custom", "windowpeek-click," + token + "," + bits); }
    Window {
        visible: true; width: 100; height: 100
        Plugin.WindowClickArea {
            id: area; anchors.fill: parent; address: "0x1"
            function query(token) { test.token = token; }
            onActivated: function(address, modifiers) {
                test.check(address === "0x1", "captured address");
                test.calls++; test.value = modifiers;
            }
        }
    }
    Timer {
        interval: 100; running: true
        onTriggered: {
            try {
                area.begin(Qt.NoModifier, true); area.complete();
                test.check(test.calls === 0, "a click waits for compositor state");
                test.reply("10", test.token);
                test.check(test.calls === 1 && test.value === Qt.ControlModifier, "Ctrl missing from Qt is resolved");
                area.begin(Qt.NoModifier, true); test.reply("11", test.token);
                test.check(test.calls === 1, "reply alone does not activate");
                area.complete();
                test.check(test.calls === 2 && test.value === (Qt.ControlModifier | Qt.ShiftModifier), "Ctrl+Shift sampled at press");
                area.begin(Qt.ControlModifier, true); area.complete(); test.reply("00", test.token);
                test.check(test.calls === 3 && test.value === Qt.NoModifier, "stale Qt modifiers are discarded");
                area.begin(Qt.NoModifier, true); var old = test.token; area.cancel();
                area.begin(Qt.NoModifier, true); area.complete();
                test.reply("11", old); test.reply("invalid", test.token);
                test.check(test.calls === 3, "old or malformed replies cannot activate");
                test.reply("10", test.token);
                test.check(test.calls === 4, "current request still succeeds");
                area.begin(Qt.NoModifier, true); area.complete(); area.address = "0x2";
                test.reply("11", test.token);
                test.check(test.calls === 4, "reused delegate cancels the old target");
                area.address = "0x1";
                area.begin(Qt.NoModifier, true); area.complete(); area.enabled = false;
                test.reply("11", test.token);
                test.check(test.calls === 4, "disabled controls ignore late replies");
                area.enabled = true;
                area.begin(Qt.ControlModifier, false); area.complete();
                test.check(test.calls === 5 && test.value === Qt.ControlModifier, "focused Qt input stays synchronous");
                area.begin(Qt.NoModifier, true); area.complete(); timeoutCheck.start();
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); Qt.quit(); }
        }
    }
    Timer {
        id: timeoutCheck; interval: 400
        onTriggered: {
            try {
                test.check(!area.gesture && test.calls === 5, "timeout cancels instead of guessing plain focus");
                test.reply("11", test.token);
                test.check(test.calls === 5, "reply after timeout is ignored");
                console.info("WINDOWPEEK_TEST_PASS");
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); }
            Qt.quit();
        }
    }
}
