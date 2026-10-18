// Automatic is a conservative estimate over a small wallpaper crop, not a
// per-pixel accessibility guarantee. Explicit choices always take precedence.
function mode(value) { return value === "on" || value === "off" ? value : "auto"; }
function luminance(c) {
    function linear(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }
    return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b);
}
function blend(front, back) {
    var a = front.a === undefined ? 1 : front.a;
    return {r:front.r*a+back.r*(1-a),g:front.g*a+back.g*(1-a),b:front.b*a+back.b*(1-a),a:1};
}
function contrast(a, b) { var x=luminance(a),y=luminance(b); return (Math.max(x,y)+0.05)/(Math.min(x,y)+0.05); }
function backgrounds(host, backing) {
    var tint = host.surfaces ? host.surfaces.panel : {r:0.1,g:0.1,b:0.1,a:1};
    var samples = host.textShadowSamples || [];
    var amount = (host.panelStyle === "glass" ? host.glassTransparency : host.wallpaperTransparency) / 100;
    if (!Number.isFinite(amount)) amount = 0;
    // Glass can show arbitrary applications: check light and dark extremes,
    // without capturing their pixels. Missing wallpaper data uses the theme tint.
    if (host.panelStyle === "glass") samples = [[0,0,0],[255,255,255]];
    if (!samples.length) samples = [[tint.r*255,tint.g*255,tint.b*255]];
    var brightness = host.panelStyle === "wallpaper" && host.surfaces ? host.surfaces.wallpaperBrightness || 0 : 0;
    return samples.map(function(sample) {
        function channel(i, t) { return Math.max(0,Math.min(1,sample[i]/255+brightness))*amount+t*(1-amount); }
        var bg = {r:channel(0,tint.r),g:channel(1,tint.g),b:channel(2,tint.b),a:1};
        if (backing) bg = blend(backing,bg);
        return bg;
    });
}
function score(host, text, backing) {
    var ratios = backgrounds(host, backing).map(function(bg) { return contrast(blend(text,bg),bg); }).sort(function(a,b){return a-b;});
    return ratios[Math.max(0, Math.ceil(ratios.length * 0.2) - 1)];
}
function needed(host, text, backing) {
    if (!host) return false;
    var selected=mode(host.textShadowMode);
    if (selected !== "auto") return selected === "on";
    return (host.panelStyle === "wallpaper" || host.panelStyle === "glass") && score(host,text,backing)<4.5;
}
function ink(host, original, themeText, backing) {
    if (!host || !needed(host, original, backing)
            || (host.panelStyle !== "wallpaper" && host.panelStyle !== "glass")) return original;
    // A shadow cannot repair a nearly transparent or mid-tone letter core.
    // Preserve strong color roles. A weak mid-tone uses solid theme text, so
    // small glyphs do not become hollow green letters inside a pale outline.
    // Only rendering changes; no saved color is rewritten.
    var solid={r:original.r,g:original.g,b:original.b,a:1};
    var lightness=luminance(solid);
    if (score(host,solid,backing)>=4.5 || lightness>=0.4 || lightness<=0.06) return solid;
    var theme={r:themeText.r,g:themeText.g,b:themeText.b,a:1};
    return theme;
}

function decision(host, original, theme, backing) {
    if (host && host.textReadability) return host.textReadability.result(original,theme,backing);
    return {active:needed(host,original,backing),ink:ink(host,original,theme,backing)};
}

function halo(color) {
    return luminance(color) > 0.18 ? Qt.rgba(0,0,0,0.8) : Qt.rgba(1,1,1,0.8);
}
function hostFor(item) {
    for (; item; item=item.parent)
        if ("hostWidget" in item && item.hostWidget) return item.hostWidget;
    return null;
}
function backingFor(item) {
    for (; item; item=item.parent)
        if ("readabilityBackground" in item) return item.readabilityBackground;
    return "transparent";
}
function textItems(item) {
    var result=[];
    for (var child of item.children || []) {
        if ("styleColor" in child && "text" in child && !("shadowActive" in child)) result.push(child);
        else result=result.concat(textItems(child));
    }
    return result;
}
