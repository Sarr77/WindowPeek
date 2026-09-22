// One canonical vocabulary for preferences, the recorder, Qt events and Hyprland.
var modifiers = ["Ctrl", "Alt", "Shift", "Super"];
var masks = {Ctrl:0x04000000, Alt:0x08000000, Shift:0x02000000, Super:0x10000000};
var defaults = {open:"Alt+Super+P", numbers:"Ctrl", privacy:"Shift", moveMouse:"Ctrl", bringMouse:"Ctrl+Shift",
    previous:"Up", next:"Down", windowSide:"Left", moveSide:"Right", pageUp:"PageUp", pageDown:"PageDown",
    first:"Home", last:"End", move:"Shift+Enter"};
var definitions = [
    {id:"open",label:"shortcutOpen",group:"shortcutOpening"},
    {id:"numbers",label:"shortcutNumbers",group:"shortcutOpening",modifier:true,suffix:"1–9 / 0"},
    {id:"privacy",label:"shortcutPrivacy",group:"shortcutOpening",modifier:true},
    {id:"move",label:"shortcutMove",group:"shortcutWindowActions"},
    {id:"previous",label:"shortcutPrevious",group:"shortcutNavigation"},
    {id:"next",label:"shortcutNext",group:"shortcutNavigation"},
    {id:"windowSide",label:"shortcutWindowSide",group:"shortcutNavigation"},
    {id:"moveSide",label:"shortcutMoveSide",group:"shortcutNavigation"},
    {id:"pageUp",label:"shortcutPageUp",group:"shortcutNavigation"},
    {id:"pageDown",label:"shortcutPageDown",group:"shortcutNavigation"},
    {id:"first",label:"shortcutFirst",group:"shortcutNavigation"},
    {id:"last",label:"shortcutLast",group:"shortcutNavigation"},
    {id:"moveMouse",label:"shortcutMoveMouse",group:"shortcutMouse",modifier:true,suffix:"click"},
    {id:"bringMouse",label:"shortcutBringMouse",group:"shortcutMouse",modifier:true,suffix:"click"}
];
var specialKeys = {16777216:"Esc",16777217:"Tab",16777218:"Tab",16777219:"Backspace",
    16777220:"Enter",16777221:"Enter",16777222:"Insert",16777223:"Delete",16777227:"Clear",
    16777232:"Home",16777233:"End",16777234:"Left",16777235:"Up",16777236:"Right",16777237:"Down",
    16777238:"PageUp",16777239:"PageDown",32:"Space",45:"Minus",61:"Equal",43:"Plus",44:"Comma",
    46:"Period",47:"Slash",59:"Semicolon",39:"Apostrophe",91:"BracketLeft",93:"BracketRight",92:"Backslash",96:"Grave"};
var modifierKeys = {16777248:"Shift",16777249:"Ctrl",16777250:"Super",16777251:"Alt"};
function keyName(code) {
    if ((code >= 48 && code <= 57) || (code >= 65 && code <= 90)) return String.fromCharCode(code);
    if (code >= 16777264 && code <= 16777287) return "F" + (code - 16777263);
    return specialKeys[code] || "";
}
function keyChoices() {
    var result = Object.keys(specialKeys).map(function(key) { return specialKeys[key]; });
    for (var i=65;i<=90;i++) result.push(String.fromCharCode(i));
    for (var n=0;n<=9;n++) result.push(String(n));
    for (var f=1;f<=24;f++) result.push("F"+f);
    return result.filter(function(key,index) { return result.indexOf(key) === index; });
}
function normalizeChord(value, modifierOnly) {
    if (typeof value !== "string" || value.length > 80) return "";
    var parts=value.split("+"); var mods=[]; var key="";
    for (var part of parts) {
        if (modifiers.indexOf(part)>=0) { if (mods.indexOf(part)>=0) return ""; mods.push(part); }
        else { if (key || keyChoices().indexOf(part)<0) return ""; key=part; }
    }
    if (modifierOnly ? !!key || !mods.length : !key) return "";
    return modifiers.filter(function(mod) { return mods.indexOf(mod)>=0; }).concat(key ? [key] : []).join("+");
}
function normalize(values) {
    var result={};
    for (var def of definitions) result[def.id]=normalizeChord(values && values[def.id],!!def.modifier) || defaults[def.id];
    return result;
}
function resolve(values) {
    var result=normalize(values);
    return Object.keys(collisions(result)).length ? normalize({}) : result;
}
function mask(chord) {
    return String(chord || "").split("+").reduce(function(value,part) { return value | (masks[part] || 0); },0);
}
function keyPart(chord) { return String(chord || "").split("+").filter(function(part) { return modifiers.indexOf(part)<0; })[0] || ""; }
function display(chord) {
    // Familiar presentation keeps Super first, independent of serialized order.
    return ["Super","Ctrl","Alt","Shift"].filter(function(mod) { return mask(chord)&masks[mod]; })
        .concat(keyPart(chord) ? [keyPart(chord)] : []).join(" + ");
}
function eventMask(event, pressed) {
    var value=event.modifiers & (masks.Ctrl|masks.Alt|masks.Shift|masks.Super);
    var mod=modifierKeys[event.key];
    if (mod) value=pressed ? value|masks[mod] : value&~masks[mod];
    return value;
}
function fromEvent(event, modifierOnly) {
    var held=eventMask(event,true);
    var parts=modifiers.filter(function(mod) { return held&masks[mod]; });
    var key=keyName(event.key);
    if (!modifierOnly) { if (!key) return ""; parts.push(key); }
    return normalizeChord(parts.join("+"),modifierOnly);
}
function matches(event, chord) { return keyName(event.key)===keyPart(chord) && eventMask(event,true)===mask(chord); }
function held(value, chord) { var needed=mask(chord); return needed!==0 && (value&needed)===needed; }
function digit(event) {
    if (event.key>=48 && event.key<=57) return event.key-48;
    if (event.modifiers & 0x20000000) {
        var keys=[16777222,16777233,16777237,16777239,16777234,16777227,16777236,16777232,16777235,16777238];
        var digit=keys.indexOf(event.key);
        if (digit>=0) return digit;
    }
    // Shift/layouts can turn physical number keys into punctuation.
    if (event.nativeScanCode>=10 && event.nativeScanCode<=19) return (event.nativeScanCode-9)%10;
    return -1;
}
function actionChord(values,id,rtl) {
    var config=normalize(values);
    if (rtl && (id==="windowSide" || id==="moveSide")
        && config.windowSide===defaults.windowSide && config.moveSide===defaults.moveSide)
        return id==="windowSide" ? "Right" : "Left";
    return config[id];
}
function mouseAction(values, value) {
    var config=normalize(values);
    // Exact modifier sets make all configured click actions unambiguous.
    var mods=value & (masks.Ctrl|masks.Alt|masks.Shift|masks.Super);
    if (mods===mask(config.bringMouse)) return "bring";
    if (mods===mask(config.moveMouse)) return "move";
    return "focus";
}
function modifierQuery(chord) {
    var names={Ctrl:["Control_L","Control_R"],Alt:["Alt_L","Alt_R"],Shift:["Shift_L","Shift_R"],Super:["Super_L","Super_R"]};
    return modifiers.filter(function(mod) { return mask(chord)&masks[mod]; }).map(function(mod) {
        return "(hl.is_key_down('"+names[mod][0]+"') or hl.is_key_down('"+names[mod][1]+"'))";
    }).join(" and ") || "false";
}
function luaChord(chord) {
    var names={Ctrl:"CTRL",Alt:"ALT",Shift:"SHIFT",Super:"SUPER",Enter:"RETURN",Esc:"ESCAPE",PageUp:"PRIOR",PageDown:"NEXT"};
    return display(chord).split(" + ").map(function(part) { return names[part] || part.toUpperCase(); }).join(" + ");
}
function hyprMask(chord) { var m=mask(chord); return (m&masks.Shift?1:0)|(m&masks.Ctrl?4:0)|(m&masks.Alt?8:0)|(m&masks.Super?64:0); }
function collisions(values) {
    var config=normalize(values); var errors={}; var used={};
    for (var def of definitions) {
        var value=config[def.id], key=keyPart(value);
        if (def.modifier) continue;
        if ((["Esc","Tab","Space","Enter"].indexOf(key)>=0 && !mask(value)) || value === "Shift+Tab") errors[def.id]={type:"reserved"};
        if (def.id==="open" && !mask(value) && !/^F\d+$/.test(key)) errors.open={type:"globalModifier"};
        if (mask(value)===mask(config.numbers) && /^[0-9]$/.test(key)) errors[def.id]={type:"duplicate",other:"numbers"};
        if (def.id!=="open" && /^[0-9]$/.test(key) && !mask(value)) errors[def.id]={type:"quickDigits"};
        if (def.id!=="open" && !mask(value) && (key.length === 1 && !/^[0-9]$/.test(key)
            || ["Minus","Equal","Plus","Comma","Period","Slash","Semicolon","Apostrophe","BracketLeft","BracketRight","Backslash","Grave"].indexOf(key)>=0)) errors[def.id]={type:"text"};
        if (["Backspace","Delete","Insert"].indexOf(key)>=0 && !mask(value)) errors[def.id]={type:"reserved"};
        {
            if (used[value]) { errors[def.id]={type:"duplicate",other:used[value]}; errors[used[value]]={type:"duplicate",other:def.id}; }
            else used[value]=def.id;
        }
    }
    if (config.moveMouse===config.bringMouse) errors.bringMouse={type:"duplicate",other:"moveMouse"};
    return errors;
}
function applyWords(words,values) {
    var c=normalize(values), result=Object.assign({},words);
    // One replacement pass prevents a custom chord from being substituted again.
    var pattern=/Maj\+Entrée|Mayús\+Intro|Maiusc\+Invio|Strg\s*\+\s*Shift|Strg\s*\+|Strg|Page Up|Page Down|Home|End|←|→|↑|↓|Super \+ Alt \+ P|Ctrl\s*\+\s*Shift|Shift\+Enter|Ctrl\s*\+|Shift|Ctrl/g;
    for (var name of ["keyboardHint","controlsWindowShortcuts","controlsPrivacy","controlsShortcut","controlsWindowKeys","controlsPaging","chooseMoveHint","bringHint","focusHint","previewHint"]) {
        if (!result[name]) continue;
        result[name]=result[name].replace(pattern,function(token) {
            var navigation={"Page Up":"pageUp","Page Down":"pageDown",Home:"first",End:"last","←":"windowSide","→":"moveSide","↑":"previous","↓":"next"};
            if (navigation[token]) return display(c[navigation[token]]);
            if (/^(Maj|Mayús|Maiusc)\+/.test(token)) return display(c.move);
            token=token.replace(/Strg/g,"Ctrl");
            if (token==="Super + Alt + P") return display(c.open);
            if (/^Ctrl\s*\+\s*Shift$/.test(token)) return display(c.bringMouse);
            if (token==="Shift+Enter") return display(c.move);
            if (/^Ctrl\s*\+$/.test(token)) return display(name==="chooseMoveHint" ? c.moveMouse : c.numbers)+" +";
            return display(token==="Shift" ? c.privacy : c.numbers);
        }).replace(/\s*\+\s*/g," + ");
    }
    return result;
}
