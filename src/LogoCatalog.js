// Stable saved IDs; bundled media are local and never require a runtime download.
var effects = [
    ["beams", "Beams"], ["binarypath", "Binary path"], ["blackhole", "Black hole"],
    ["bouncyballs", "Bouncy balls"], ["bubbles", "Bubbles"], ["burn", "Burn"],
    ["colorshift", "Color shift"], ["crumble", "Crumble"], ["decrypt", "Decrypt"],
    ["errorcorrect", "Error correct"], ["expand", "Expand"], ["fireworks", "Fireworks"],
    ["highlight", "Highlight"], ["laseretch", "Laser etch"], ["matrix", "Matrix"],
    ["middleout", "Middle out"], ["orbittingvolley", "Orbiting volley"], ["overflow", "Overflow"],
    ["pour", "Pour"], ["print", "Print"], ["rain", "Rain"], ["randomsequence", "Random sequence"],
    ["rings", "Rings"], ["scattered", "Scattered"], ["slice", "Slice"], ["slide", "Slide"],
    ["smoke", "Smoke"], ["spotlights", "Spotlights"], ["spray", "Spray"], ["swarm", "Swarm"],
    ["sweep", "Sweep"], ["synthgrid", "Synth grid"], ["thunderstorm", "Thunderstorm"],
    ["unstable", "Unstable"], ["vhstape", "VHS tape"], ["waves", "Waves"], ["wipe", "Wipe"]];
function effect(source) {
    var id = String(source).replace(/^builtin:ttfx-/, "");
    return source === "builtin:ttfx-" + id && effects.some(function(e) { return e[0] === id; }) ? id : "";
}
var randomChoice = "builtin:omarchy-random";
function isRandom(source) { return source === randomChoice; }
// Select a bundled GIF, excluding the previous one. No media scanning/decoding.
function randomSource(previous, sample) {
    var previousIndex = effects.findIndex(function(e) { return "builtin:ttfx-" + e[0] === previous; });
    var count = effects.length - (previousIndex >= 0 ? 1 : 0);
    var value = typeof sample === "number" && isFinite(sample) ? sample : Math.random();
    var index = Math.min(count - 1, Math.floor(Math.max(0, value) * count));
    if (previousIndex >= 0 && index >= previousIndex) index++;
    return "builtin:ttfx-" + effects[index][0];
}
function animated(source) { return isRandom(source) || source === "builtin:omarchy-pixel" || !!effect(source) || /\.gif$/i.test(source); }
function label(source, words, copy) {
    if (isRandom(source)) return copy ? copy.randomGif : "Random GIF";
    if (!source) return "Omarchy";
    if (source === "builtin:omarchy-pixel") return words.animatedOmarchy;
    var id = effect(source);
    if (id) return effects.filter(function(e) { return e[0] === id; })[0][1];
    try { return decodeURIComponent(String(source).split("/").pop()); } catch (_) { return words.chooseLogoImage; }
}
function library(words, query) {
    var items = [{source:"", name:"Omarchy", group:0},
        {source:"builtin:omarchy-pixel", name:words.animatedOmarchy, group:0}];
    effects.forEach(function(e) { items.push({source:"builtin:ttfx-" + e[0], name:e[1], group:1}); });
    var needle = String(query || "").trim().toLocaleLowerCase();
    return items.filter(function(e) { return !needle || (e.name + " " + e.source).toLocaleLowerCase().indexOf(needle) >= 0; });
}
function motion(value) { return ["pulse", "float", "sway", "spin", "fade"].indexOf(value) >= 0 ? value : "none"; }
var reveals = ["none", "pixels", "scatter", "wipe", "blinds", "iris", "dissolve"];
function reveal(value) { return reveals.indexOf(value) >= 0 ? value : "none"; }
function recent(values) {
    if (!Array.isArray(values)) return [];
    return values.filter(function(v, i) {
        return typeof v === "string" && v.length <= 4096 && /^file:\/\/\/[^\r\n\x00]+$/.test(v)
            && values.indexOf(v) === i;
    }).slice(0, 12);
}
function remember(values, source) { return recent([source].concat(recent(values))); }
function finite(value, fallback, low, high) {
    return typeof value === "number" && isFinite(value) ? Math.max(low, Math.min(high, value)) : fallback;
}
function defaultOpacity(source) { return isRandom(source) || !!effect(source) || /\.gif$/i.test(source) ? 50 : 100; }
// null follows the source default; numbers are the user's explicit override.
function opacitySetting(value) { return finite(value,null,0,100); }
function opacity(value, source) { return finite(value,defaultOpacity(source),0,100); }
// Independent factors multiply: 250% width at 25% zoom is only 62.5% of
// the baseline. Keep a broad finite storage range; gestures cap visible bounds.
var layoutScaleMin = 0.01;
var layoutScaleMax = 10000;
function layout(value) {
    var v = value && typeof value === "object" ? value : {};
    return {zoom:finite(v.zoom,100,layoutScaleMin,layoutScaleMax), width:finite(v.width,100,layoutScaleMin,layoutScaleMax), height:finite(v.height,100,layoutScaleMin,layoutScaleMax),
        x:finite(v.x,0,-100,100), y:finite(v.y,0,-100,100)};
}
// Shipped artwork presets; resetting never takes a new snapshot of user edits.
function artworkDefaults(target) {
    var hover = target === "hover", prefix = (hover ? "hover" : "settings") + "Logo";
    var fields = {Image:hover ? "builtin:omarchy-pixel" : randomChoice, ThemeColors:true, Opacity:null, Motion:"none", Reveal:"none",
        Layout:layout({}), Loop:true, LoopDelay:4.2, Cooldown:hover ? 60 : 0, CooldownUnit:"min"};
    var values = {};
    Object.keys(fields).forEach(function(key) { values[prefix + key] = fields[key]; });
    return values;
}
