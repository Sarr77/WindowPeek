import QtQuick

// Keep static SVG/raster support while decoding GIF frames only during display.
Item {
    id: root
    property url source: ""
    property bool playing: false
    property bool suspended: false
    property bool loopAnimation: true
    property real loopDelay: 4.2
    property size sourceSize: Qt.size(1600, 400)
    readonly property bool animated: /\.gif$/i.test(String(source))
    readonly property int status: image.item ? image.item.status : Image.Null
    readonly property int currentFrame: animated && image.item ? image.item.currentFrame : 0
    readonly property bool finished: animated && image.item ? image.item.finished : false
    readonly property bool animating: animated && image.item ? image.item.playing && !image.item.paused : false
    readonly property bool waitingForLoop: animated && image.item ? image.item.waitingForLoop : false
    Loader {
        id: image; anchors.fill: parent
        active: String(root.source) !== ""
        sourceComponent: root.animated ? motion : still
    }
    Component {
        id: still
        Image { source: root.source; sourceSize: root.sourceSize; asynchronous: true; fillMode: Image.PreserveAspectFit }
    }
    Component {
        id: motion
        AnimatedImage {
            id: movie
            property bool finished: false
            property bool syncing: false
            property bool waitingForLoop: false
            property real remainingPause: 0
            property double pauseStarted: 0
            function pausePlayback() {
                if (root.suspended && loopPause.running) {
                    remainingPause = Math.max(1, remainingPause - (Date.now() - pauseStarted));
                    loopPause.stop();
                } else if (!root.suspended && waitingForLoop && !loopPause.running) {
                    pauseStarted = Date.now(); loopPause.start();
                }
                paused = root.suspended || finished || waitingForLoop;
            }
            function waitForLoop() {
                waitingForLoop = true; remainingPause = root.loopDelay * 1000;
                pausePlayback();
            }
            source: root.source; sourceSize: root.sourceSize
            cache: false; playing: false; fillMode: Image.PreserveAspectFit
            function restartPlayback() {
                syncing = true;
                loopPause.stop(); waitingForLoop = false;
                playing = false; paused = false; finished = false;
                if (root.playing && status === Image.Ready) playing = true;
                // Starting QMovie may advance its internal frame. Rewind after
                // starting so reopening never skips the first visible frame.
                currentFrame = 0;
                syncing = false;
                pausePlayback();
            }
            onStatusChanged: if (status === Image.Ready) restartPlayback()
            onSourceChanged: restartPlayback()
            onCurrentFrameChanged: {
                if (!syncing && root.playing && frameCount > 0 && currentFrame === frameCount - 1) {
                    if (!root.loopAnimation) { finished = true; paused = true; }
                    else if (root.loopDelay > 0 && frameCount > 1) { waitForLoop(); }
                }
            }
            Timer {
                id: loopPause
                interval: Math.max(1, movie.remainingPause)
                onTriggered: {
                    movie.waitingForLoop = false;
                    movie.pausePlayback();
                }
            }
            // Honor the user's loop choice even for a GIF encoded to play once.
            onPlayingChanged: if (!playing && !syncing && !finished && root.playing
                    && root.loopAnimation && status === Image.Ready && frameCount > 1) {
                Qt.callLater(function() {
                    if (movie && !movie.playing && root.playing && root.loopAnimation) movie.restartPlayback();
                });
            }
            Component.onCompleted: restartPlayback()
            Connections {
                target: root
                function onPlayingChanged() { movie.restartPlayback(); }
                function onSuspendedChanged() { movie.pausePlayback(); }
                function onLoopDelayChanged() {
                    if (movie.waitingForLoop) {
                        loopPause.stop(); movie.remainingPause = root.loopDelay * 1000;
                        movie.pausePlayback();
                    }
                }
                function onLoopAnimationChanged() { movie.restartPlayback(); }
            }
        }
    }
}
