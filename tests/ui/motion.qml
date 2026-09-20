import QtQuick
import QtQuick.Window
import Quickshell
import "WindowPeek/vendor/omarchy" as Native

ShellRoot {
    id: test
    property int step: 0
    function check(ok, text) { if (!ok) throw new Error(text); }
    Native.PopupMotion { id: motion; duration: 600 }
    Window { visible: true; width:100; height:100; opacity:motion.value }
    Timer {
        interval:100; running:true; repeat:true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0:
                    motion.targetValue = 1;
                    test.check(motion.value === 0, "normal opening starts a fade"); break;
                case 1:
                    test.check(motion.value > 0 && motion.value < 1, "opening renders intermediate values");
                    motion.animated = false;
                    test.check(motion.value === 1, "disabling mid-fade immediately reaches the target");
                    motion.targetValue = 0;
                    test.check(motion.value === 0, "disabled close is synchronous");
                    motion.targetValue = 1;
                    test.check(motion.value === 1, "disabled open is synchronous");
                    motion.animated = true;
                    test.check(motion.value === 1, "reenabling does not replay a finished fade");
                    motion.targetValue = 0; break;
                case 2:
                    test.check(motion.value > 0 && motion.value < 1, "closing animates again");
                    var previous = motion.value;
                    motion.targetValue = 1;
                    test.check(motion.value === previous, "reversing an animation preserves continuity"); break;
                case 3:
                    motion.animated = false;
                    test.check(motion.value === 1, "reversed animation finishes immediately when disabled");
                    motion.targetValue = 0;
                    break;
                case 4:
                    test.check(motion.value === 0 && !motion.transition.running, "stopped animation cannot overwrite a new target");
                    console.info("WINDOWPEEK_TEST_PASS: popup motion"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
