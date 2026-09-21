import QtQuick
import QtQuick.Window

// Separate client so the preview's render loop cannot wake the source itself.
Window {
    id: source
    visible: true; width: 640; height: 400
    title: Qt.application.arguments[Qt.application.arguments.length - 1]
    color: "#28b4c8"
    onFrameSwapped: console.warn("SOURCE_FRAME " + Date.now())
    Text { x: 24; y: 24; text: "Fictional animated window"; color: "white"; font.pixelSize: 20 }
    Rectangle {
        y: source.height / 2; width: 40; height: 40; radius: 20; color: "#ff8844"
        SequentialAnimation on x {
            running: true; loops: Animation.Infinite
            NumberAnimation { from: 0; to: source.width - 40; duration: 1600 }
            NumberAnimation { from: source.width - 40; to: 0; duration: 1600 }
        }
    }
}
