// Position a scaled dropdown above or below its trigger, within the window.
// Inputs are window pixels except desiredHeight, gap and margin (logical px).
function fit(x, y, width, height, windowWidth, windowHeight, scale, desiredHeight, gap, margin) {
  scale = Number.isFinite(scale) && scale > 0 ? scale : 1;
  if (!(windowWidth > 0 && windowHeight > 0))
    return {x: 0, y: height / scale + gap, width: width / scale, height: desiredHeight};
  var pad = Math.min(margin * scale, Math.min(windowWidth, windowHeight) / 4);
  var gutter = gap * scale;
  var above = Math.max(0, y - gutter - pad);
  var below = Math.max(0, windowHeight - pad - y - height - gutter);
  var wanted = Math.max(1, desiredHeight * scale);
  var placeBelow = below >= wanted || below >= above;
  var popupHeight = Math.max(1, Math.min(wanted, placeBelow ? below : above));
  var popupWidth = Math.max(1, Math.min(width, windowWidth - 2 * pad));
  var left = Math.max(pad, Math.min(x, windowWidth - pad - popupWidth));
  var top = placeBelow ? y + height + gutter : y - gutter - popupHeight;
  top = Math.max(pad, Math.min(top, windowHeight - pad - popupHeight));
  return {x: (left-x)/scale, y: (top-y)/scale, width: popupWidth/scale, height: popupHeight/scale};
}

// Place a preview beside its panel in screen-local pixels. Width includes the
// transparent handoff strips; rowOffset is relative to the panel's top edge.
function beside(bounds, rowOffset, rowHeight, width, height, screen) {
  var x = bounds.x - screen.x + bounds.width;
  if (x + width > screen.width) x = bounds.x - screen.x - width;
  x = Math.max(0, Math.min(x, screen.width - width));
  var top = bounds.y - screen.y;
  var desiredY = top + Math.max(0, rowOffset + rowHeight / 2 - height / 2);
  var y = Math.max(top, Math.min(desiredY, screen.height - height));
  return {x: Math.round(x), y: Math.round(y)};
}
