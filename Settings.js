function merge(current, values, id) {
    var result = { id: id };
    Object.keys(current || {}).forEach(function(key) { if (key !== "id") result[key] = current[key]; });
    Object.keys(values || {}).forEach(function(key) { if (key !== "id") result[key] = values[key]; });
    return result;
}
function revision(settings) {
    var value = settings && settings._windowpeekRevision;
    return Number.isSafeInteger(value) && value > 0 ? value : 0;
}
function restore(saved, inline, id) {
    return revision(saved) > revision(inline) ? merge(inline, saved, id) : merge(saved, inline, id);
}
function stamp(settings, saved) {
    var result = merge(settings, {}, settings.id);
    result._windowpeekRevision = Math.max(Date.now(), revision(saved) + 1);
    return result;
}
function initial(layout, id, fallback) {
    if (!layout) return fallback;
    var sections = ["left", "center", "right"];
    for (var i = 0; i < sections.length; i++) {
        var entries = layout[sections[i]];
        if (!Array.isArray(entries)) continue;
        for (var j = 0; j < entries.length; j++)
            if (entries[j] && entries[j].id === id) return JSON.parse(JSON.stringify(entries[j]));
    }
    return fallback;
}
var hintLimit = 200;
function hints(settings) {
    var mode = ["auto", "on", "off"].indexOf(settings.hintsMode) >= 0 ? settings.hintsMode : "auto";
    var used = Number.isFinite(settings.hintsUsed) ? Math.max(0, Math.min(hintLimit, Math.floor(settings.hintsUsed))) : 0;
    return { mode: mode, used: used, remaining: hintLimit - used, enabled: mode === "on" || (mode === "auto" && used < hintLimit) };
}
function hoverDelay(value) {
    return typeof value === "number" && Number.isFinite(value)
        ? Math.max(0, Math.min(2000, Math.round(value))) : 400;
}
