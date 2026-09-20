// Copyright (c) 2026 Sarr. MIT; see ../../LICENSE.
import QtQuick

// A standalone animation can be finished synchronously when motion is disabled.
QtObject {
    id: root
    property real targetValue: 0
    property real value: 0
    property bool animated: true
    property int duration: 140
    property bool initialized: false
    onTargetValueChanged: update()
    onAnimatedChanged: update()
    Component.onCompleted: { value = targetValue; initialized = true; }
    function update() {
        if (!initialized) return;
        transition.stop();
        if (!animated || value === targetValue) value = targetValue;
        else {
            transition.from = value;
            transition.to = targetValue;
            transition.start();
        }
    }
    property NumberAnimation transition: NumberAnimation {
        target: root; property: "value"
        duration: root.duration; easing.type: Easing.OutCubic
    }
}
