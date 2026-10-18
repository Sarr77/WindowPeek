// Fit the captured image, not its letterboxed viewport. Keep unknown sources
// at the familiar placeholder size until the compositor supplies a frame.
function fit(sourceWidth, sourceHeight, maximumWidth, maximumHeight, fallbackHeight, enabled) {
    var width = Math.max(1, maximumWidth), height = Math.max(1, maximumHeight);
    if (!enabled || !Number.isFinite(sourceWidth) || !Number.isFinite(sourceHeight)
        || sourceWidth <= 0 || sourceHeight <= 0)
        return {width:width, height:Math.min(height,Math.max(1,fallbackHeight))};
    var factor = Math.min(width/sourceWidth,height/sourceHeight);
    return {width:Math.max(1,sourceWidth*factor),height:Math.max(1,sourceHeight*factor)};
}
