import QtQuick
import QtQuick.Window
import Quickshell
import "WindowPeek/vendor/omarchy" as Native

ShellRoot {
    id: test
    property int step: 0
    property bool frameCase: false
    property real pausedValue: 0
    property int swaps: 0
    property int idleSwaps: 0
    Connections { target: visual; function onFrameSwapped() { test.swaps++; } }
    function check(ok, text) { if (!ok) throw new Error(text); }
    Native.PopupMotion { id: motion; duration: 600; frameWindow: test.frameCase ? visual : null }
    Window { id: visual; visible: true; width:100; height:100; opacity:motion.value }
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
                    if (!frameCase) {
                        frameCase = true;
                        motion.animated = true;
                        step = 0;
                        break;
                    }
                    motion.animated = true; motion.targetValue = 1; break;
                case 5:
                    test.check(motion.value > 0 && motion.value < 1, "frame clock advances");
                    motion.paused = true; pausedValue = motion.value; break;
                case 6:
                    test.check(motion.value === pausedValue && !motion.running, "pause freezes value without repaint requests");
                    motion.paused = false; break;
                case 14:
                    test.check(motion.value === 1 && !motion.running, "frame clock reaches terminal value and stops");
                    idleSwaps = swaps; break;
                case 16:
                    test.check(swaps - idleSwaps <= 1, "finished motion does not continuously request frames");
                    motion.targetValue = 0; break;
                case 17:
                    test.check(motion.value > 0 && motion.value < 1, "closing uses frame clock");
                    visual.visible = false; break;
                case 25:
                    test.check(motion.value === 0 && !motion.running, "hidden window fallback finishes without presentation callbacks");
                    visual.visible = true; motion.targetValue = 1; break;
                case 26:
                    motion.frameWindow = null; break;
                case 34:
                    test.check(motion.value === 1 && !motion.running, "removed window leaves no stalled motion");
                    console.info("WINDOWPEEK_TEST_PASS: popup motion frame clock, idle, hidden and removed window"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
