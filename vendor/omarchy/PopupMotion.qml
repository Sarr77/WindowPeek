// Copyright (c) 2026 Sarr. MIT; see ../../LICENSE.
import QtQuick
import Quickshell

// Follow the presenting window when available, instead of a separate animation
// timer whose ticks can miss that window's next frame on mixed-refresh outputs.
QtObject {
    id: root
    property real targetValue: 0
    property real value: 0
    property bool animated: true
    property bool paused: false
    property int duration: 140
    property var frameWindow: null
    property bool initialized: false
    property bool frameRunning: false
    property real startValue: 0
    readonly property bool useFrameClock: !!frameWindow && frameWindow.visible
    readonly property bool running: frameRunning || transition.running
    onTargetValueChanged: update()
    onAnimatedChanged: update()
    onPausedChanged: update()
    onUseFrameClockChanged: update()
    onFrameWindowChanged: update()
    Component.onCompleted: { value = targetValue; initialized = true; }
    function requestFrame() {
        var window = frameWindow;
        if (frameRunning && window && window.visible) window.update();
    }
    function update() {
        if (!initialized) return;
        transition.stop();
        frameRunning = false;
        if (paused && animated) return;
        if (!animated || duration <= 0 || value === targetValue) value = targetValue;
        else if (useFrameClock) {
            startValue = value;
            elapsed.restart();
            frameRunning = true;
            requestFrame();
        } else {
            transition.from = value;
            transition.to = targetValue;
            transition.start();
        }
    }
    function advanceFrame() {
        if (!frameRunning) return;
        var progress = Math.min(1, elapsed.elapsed() * 1000 / Math.max(1, duration));
        var remaining = 1 - progress;
        value = startValue + (targetValue - startValue) * (1 - remaining * remaining * remaining);
        if (progress >= 1) frameRunning = false;
    }
    property ElapsedTimer elapsed: ElapsedTimer {}
    property Connections frameEvents: Connections {
        target: root.frameWindow
        enabled: root.frameRunning
        function onAfterAnimating() { root.advanceFrame(); }
        function onFrameSwapped() { root.requestFrame(); }
    }
    property NumberAnimation transition: NumberAnimation {
        target: root; property: "value"
        duration: root.duration; easing.type: Easing.OutCubic
    }
}
