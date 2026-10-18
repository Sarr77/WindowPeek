// Hyprland 0.56.2 can crash in set_enabled on an expired weak handle.
// tostring checks validity without dereferencing it; reinstall replaces stale handles.
.import "Shortcuts.js" as Keys

function conflicts(binds, chord) {
    if (!Array.isArray(binds)) return [];
    chord=Keys.normalizeChord(chord || Keys.defaults.open,false);
    if (!chord) return [];
    var key=Keys.keyPart(chord).toLowerCase();
    var aliases={enter:"return",esc:"escape",pageup:"prior",pagedown:"next"};
    key=aliases[key] || key;
    var codes={"0":19,"1":10,"2":11,"3":12,"4":13,"5":14,"6":15,"7":16,"8":17,"9":18,Home:110,End:115,PageUp:112,PageDown:117,Left:113,Right:114,Up:111,Down:116,Enter:36,Space:65,Tab:23,Esc:9,F1:67,F2:68,F3:69,F4:70,F5:71,F6:72,F7:73,F8:74,F9:75,F10:76,F11:95,F12:96,F13:191,F14:192,F15:193,F16:194,F17:195,F18:196,F19:197,F20:198,F21:199,F22:200,F23:201,F24:202,Insert:118,Delete:119,Backspace:22,Minus:20,Equal:21,Comma:59,Period:60,Slash:61,Semicolon:47,Apostrophe:48,BracketLeft:34,BracketRight:35,Backslash:51,Grave:49,P:33,A:38,B:56,C:54,D:40,E:26,F:41,G:42,H:43,I:31,J:44,K:45,L:46,M:58,N:57,O:32,Q:24,R:27,S:39,T:28,U:30,V:55,W:25,X:53,Y:29,Z:52};
    return binds.filter(function(bind) {
        return bind && !/^WindowPeek: (open window list \(automatic\)|visible window [0-9])/.test(String(bind.description))
            && (bind.modmask === Keys.hyprMask(chord) || bind.catch_all)
            && (!bind.submap || bind.submap_universal === true || bind.submap_universal === "true")
            && (String(bind.key).toLowerCase() === key || (codes[Keys.keyPart(chord)] && bind.keycode === codes[Keys.keyPart(chord)]) || bind.catch_all);
    });
}
function occupied(binds, chord) {
    return !Array.isArray(binds) || conflicts(binds, chord).length > 0;
}
function numberOccupied(binds, modifier) {
    var keypad=[90,87,88,89,83,84,85,79,80,81];
    if (!Array.isArray(binds)) return true;
    for (var digit=0;digit<=9;digit++) if (occupied(binds,modifier+"+"+digit)) return true;
    return binds.some(function(bind) {
        return bind && !/^WindowPeek: visible window [0-9]/.test(String(bind.description))
            && bind.modmask === Keys.hyprMask(modifier)
            && (!bind.submap || bind.submap_universal === true || bind.submap_universal === "true")
            && (keypad.indexOf(bind.keycode)>=0 || /^KP_(?:[0-9]|Insert|End|Down|Next|Left|Begin|Right|Home|Up|Prior)$/i.test(String(bind.key)));
    });
}
function token(owner) {
    if (typeof owner !== "string" || !/^[a-z0-9:-]+$/.test(owner)) throw new Error("Invalid shortcut token");
    return "'" + owner + "'";
}
function install(owner, chord) {
    chord=Keys.normalizeChord(chord || Keys.defaults.open,false);
    if (!chord) throw new Error("Invalid opening shortcut");
    var key="'"+Keys.luaChord(chord)+"'";
    return "local s=_windowpeek_open_v1; if not s then s={}; _windowpeek_open_v1=s; end; "
        + "function s.stop() s.owner=nil; if tostring(s.bind)~='HL.Keybind(expired)' then s.bind:set_enabled(false) end; s.timer:set_enabled(false) end; "
        + "if not s.timer then s.timer=hl.timer(function() s.stop() end,{timeout=15000,type='repeat'}); end; "
        + "if s.bind then if tostring(s.bind)~='HL.Keybind(expired)' then s.bind:set_enabled(false) end end; "
        + "if not s.binds then s.binds={}; if s.bind then s.binds['SUPER + ALT + P']=s.bind end end; "
        + "local key="+key+"; if not s.binds[key] or tostring(s.binds[key])=='HL.Keybind(expired)' then s.binds[key]=hl.bind(key,function() if not s.owner then return {ok=false} end; "
        + "hl.dispatch(hl.dsp.event('windowpeek-open,'..s.owner)); end,"
        + "{auto_consuming=true,description='WindowPeek: open window list (automatic)'}); end; "
        + "s.bind=s.binds[key]; s.owner=" + token(owner) + "; if tostring(s.bind)~='HL.Keybind(expired)' then s.bind:set_enabled(true) end; s.timer:set_timeout(15000); ";
}
function renew(owner) {
    return "local s=_windowpeek_open_v1; if s and (not s.owner or s.owner==" + token(owner)
        + ") then s.owner=" + token(owner) + "; if tostring(s.bind)~='HL.Keybind(expired)' then s.bind:set_enabled(true) end; s.timer:set_timeout(15000) end; ";
}
function release(owner) {
    return "local s=_windowpeek_open_v1; if s and s.owner==" + token(owner) + " then s.stop() end; ";
}
