// Color math and validation shared by the QML picker and tests.
var tokyoNightAccent = "#D898F5";

function hex(value) {
  var text = String(value || "").trim().replace(/^#/, "");
  if (/^[0-9a-f]{3}$/i.test(text)) text = text.split("").map(function(c) { return c + c; }).join("");
  return /^[0-9a-f]{6}$/i.test(text) ? "#" + text.toUpperCase() : "";
}

function scale(value) {
  if (typeof value !== "number" || !Number.isFinite(value)) return 1;
  return Math.round(Math.max(0.8, Math.min(2, value)) * 100) / 100;
}

function merge(current, values) {
  var result = {};
  Object.keys(current || {}).forEach(function(key) { result[key] = current[key]; });
  Object.keys(values || {}).forEach(function(key) { result[key] = values[key]; });
  // A color-only change applies globally; an empty value uses the theme accent.
  if (values && Object.prototype.hasOwnProperty.call(values, "accentColor")
      && !Object.prototype.hasOwnProperty.call(values, "colorMode")) {
    result.colorMode = hex(values.accentColor) ? "custom" : "theme";
    result.colorScope = "all";
  }
  return normalize(result);
}

function normalize(settings) {
  settings = settings || {};
  var legacy = !validMode(settings.colorMode);
  var accent = hex(settings.accentColor);
  var mode = legacy ? (accent ? "custom" : (Object.prototype.hasOwnProperty.call(settings, "accentColor") ? "theme" : "adaptive")) : settings.colorMode;
  var rules = {};
  var source = settings.themeColors;
  if (source && typeof source === "object" && !Array.isArray(source)) {
    Object.keys(source).slice(0, 100).forEach(function(key) {
      if (themeId(key) !== key || !key) return;
      var rule = source[key];
      if (!rule || !validMode(rule.mode)) return;
      var color = hex(rule.color);
      if (rule.mode !== "custom" || color) rules[key] = {mode: rule.mode, color: color};
    });
  }
  var presets = [], ids = Object.create(null), names = Object.create(null);
  if (Array.isArray(settings.colorPresets)) settings.colorPresets.slice(0, 24).forEach(function(p) {
    if (!p || typeof p.id !== "string" || !/^preset-[a-zA-Z0-9-]{1,64}$/.test(p.id)) return;
    var name = presetName(p.name), color = hex(p.color);
    if (!name || !color || ids[p.id] || names[name.toLowerCase()]) return;
    ids[p.id] = true; names[name.toLowerCase()] = true;
    presets.push({id: p.id, name: name, color: color});
  });
  return { accentColor: accent,
    colorMode: mode === "custom" && !accent ? "adaptive" : mode,
    colorScope: legacy ? (mode === "adaptive" ? "theme" : "all") : (settings.colorScope === "all" ? "all" : "theme"),
    themeColors: rules, colorPresets: presets,
    tooltipStyle: settings && settings.tooltipStyle === "compact" ? "compact" : "panel",
    uiScale: scale(settings && settings.uiScale), barScale: scale(settings && settings.barScale) };
}

function validMode(mode) { return mode === "adaptive" || mode === "theme" || mode === "custom"; }
function themeId(value) {
  var id = String(value || "").trim().toLowerCase();
  return /^[a-z0-9][a-z0-9._-]{0,99}$/.test(id) && id !== "constructor" && id !== "prototype" ? id : "";
}
function presetName(value) {
  return typeof value === "string" ? value.replace(/[\x00-\x1f\x7f]/g, " ").replace(/\s+/g, " ").trim().slice(0, 40) : "";
}
function ruleFor(settings, theme) {
  var prefs = normalize(settings), id = themeId(theme);
  if (prefs.colorScope === "all") return {mode: prefs.colorMode, color: prefs.accentColor};
  return id && Object.prototype.hasOwnProperty.call(prefs.themeColors, id)
    ? prefs.themeColors[id] : {mode: "adaptive", color: ""};
}
function resolve(settings, theme, themeAccent) {
  var rule = ruleFor(settings, theme);
  if (rule.mode === "custom" && rule.color) return rule.color;
  if (rule.mode === "adaptive" && themeId(theme) === "tokyo-night") return tokyoNightAccent;
  return hex(themeAccent) || "#7AA2F7";
}
function setRule(settings, theme, scope, mode, color) {
  var result = normalize(settings), id = themeId(theme), value = hex(color);
  if (!validMode(mode) || (mode === "custom" && !value)) return result;
  if (scope === "theme" && !id) return result;
  result.colorScope = scope === "all" ? "all" : "theme";
  if (result.colorScope === "all") { result.colorMode = mode; result.accentColor = value; }
  else result.themeColors[id] = {mode: mode, color: value};
  return result;
}
function restoreColor(settings, savedSettings, theme) {
  var result = normalize(settings), saved = normalize(savedSettings), id = themeId(theme);
  result.colorMode = saved.colorMode;
  result.colorScope = saved.colorScope;
  result.accentColor = saved.accentColor;
  if (id) {
    if (Object.prototype.hasOwnProperty.call(saved.themeColors, id)) result.themeColors[id] = saved.themeColors[id];
    else delete result.themeColors[id];
  }
  return result;
}
function upsertPreset(settings, id, name, color) {
  var result = normalize(settings), label = presetName(name), value = hex(color);
  if (!label || !value || result.colorPresets.some(function(p) { return p.id !== id && p.name.toLowerCase() === label.toLowerCase(); })) return null;
  var index = result.colorPresets.findIndex(function(p) { return p.id === id; });
  if (id && index < 0) return null;
  if (index < 0) {
    if (result.colorPresets.length >= 24) return null;
    var n = 1;
    while (result.colorPresets.some(function(p) { return p.id === "preset-" + n; })) n++;
    result.colorPresets.push({id: "preset-" + n, name: label, color: value});
  } else result.colorPresets[index] = {id: id, name: label, color: value};
  return result;
}
function removePreset(settings, id) {
  var result = normalize(settings);
  result.colorPresets = result.colorPresets.filter(function(p) { return p.id !== id; });
  return result;
}

function fromHsv(h, s, v) {
  if (![h, s, v].every(function(n) { return typeof n === "number" && Number.isFinite(n); })) return "";
  h = ((h % 1) + 1) % 1;
  s = Math.max(0, Math.min(1, s)); v = Math.max(0, Math.min(1, v));
  var c = v * s, x = c * (1 - Math.abs((h * 6) % 2 - 1)), m = v - c;
  var rgb = [[c,x,0],[x,c,0],[0,c,x],[0,x,c],[x,0,c],[c,0,x]][Math.floor(h * 6)];
  return "#" + rgb.map(function(n) { return Math.round((n + m) * 255).toString(16).padStart(2, "0"); }).join("").toUpperCase();
}

function toHsv(value) {
  var normalized = hex(value);
  if (!normalized) return null;
  var r = parseInt(normalized.slice(1,3),16)/255;
  var g = parseInt(normalized.slice(3,5),16)/255;
  var b = parseInt(normalized.slice(5,7),16)/255;
  var max = Math.max(r,g,b), min = Math.min(r,g,b), delta = max-min, h = 0;
  if (delta) {
    if (max === r) h = ((g-b)/delta) % 6;
    else if (max === g) h = (b-r)/delta + 2;
    else h = (r-g)/delta + 4;
    h /= 6;
    if (h < 0) h += 1;
  }
  return {h:h, s:max === 0 ? 0 : delta/max, v:max};
}
