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
var hintLimit = 100;
function hints(settings) {
    var mode = ["auto", "on", "off"].indexOf(settings.hintsMode) >= 0 ? settings.hintsMode : "auto";
    var used = Number.isFinite(settings.hintsUsed) ? Math.max(0, Math.min(hintLimit, Math.floor(settings.hintsUsed))) : 0;
    return { mode: mode, used: used, remaining: hintLimit - used, enabled: mode === "on" || (mode === "auto" && used < hintLimit) };
}
function hoverDelay(value) {
    return typeof value === "number" && Number.isFinite(value)
        ? Math.max(0, Math.min(2000, Math.round(value))) : 400;
}
function panelStyle(value) {
    return value === "glass" || value === "wallpaper" ? value : "solid";
}
function backgroundTransparency(value, fallback) {
    return typeof value === "number" && Number.isFinite(value)
        ? Math.max(0, Math.min(100, Math.round(value))) : fallback;
}
function transparencyTheme(theme) {
    return typeof theme === "string" && /^[a-z0-9][a-z0-9._-]{0,99}$/.test(theme)
        && ["constructor", "prototype"].indexOf(theme) < 0 ? theme : "";
}
function wallpaperRule(settings, theme) {
    settings = settings || {};
    var base = backgroundTransparency(settings.wallpaperTransparency, 70);
    var map = settings.wallpaperThemeTransparencies;
    var entry = transparencyTheme(theme) && map && !Array.isArray(map)
        && Object.prototype.hasOwnProperty.call(map, theme) ? map[theme] : null;
    var value = entry ? backgroundTransparency(entry.value, null) : null;
    var defaultValue = entry ? backgroundTransparency(entry.defaultValue, null) : null;
    return value !== null && defaultValue !== null
        ? {value: value, defaultValue: defaultValue, initialized: true}
        : {value: base, defaultValue: base, initialized: false};
}
function setWallpaperTransparency(settings, theme, value, defaultValue) {
    if (!transparencyTheme(theme)) return {};
    var map = {}, existing = settings && settings.wallpaperThemeTransparencies;
    Object.keys(existing || {}).forEach(function(key) {
        if (transparencyTheme(key)) {
            var rule = wallpaperRule(settings, key);
            if (rule.initialized) map[key] = {value: rule.value, defaultValue: rule.defaultValue};
        }
    });
    var current = wallpaperRule(settings, theme);
    map[theme] = {value: backgroundTransparency(value, current.value),
        defaultValue: backgroundTransparency(defaultValue, current.defaultValue)};
    return {wallpaperThemeTransparencies: map};
}
