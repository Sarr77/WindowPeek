// Hyprland 0.56.2 can crash in set_enabled on an expired weak handle.
// tostring checks validity without dereferencing it; reinstall replaces stale handles.
// Lease the configured number family before passive hover acquires keyboard
// focus. Disable and reuse our own handles; never unbind user shortcuts.
function token(value) {
    if (typeof value !== "string" || !/^[a-z0-9:-]+$/.test(value)) throw new Error("Invalid shortcut token");
    return "'" + value + "'";
}
function modifierToken(value) {
    value = value === undefined ? "CTRL" : value;
    if (typeof value !== "string" || !/^(CTRL|ALT|SHIFT|SUPER)( \+ (CTRL|ALT|SHIFT|SUPER))*$/.test(value))
        throw new Error("Invalid shortcut modifier");
    return "'" + value + "'";
}
function install(owner, modifier) {
    return "local s=_windowpeek_shortcuts_v1; if not s then s={binds={}}; _windowpeek_shortcuts_v1=s; end; "
        + "function s.stop() s.owner=nil; for _,b in ipairs(s.binds) do if tostring(b)~='HL.Keybind(expired)' then b:set_enabled(false) end end; s.timer:set_enabled(false) end; "
        + "if not s.timer then s.timer=hl.timer(function() s.stop() end,{timeout=750,type='repeat'}); end; "
        + "for _,b in ipairs(s.binds) do if tostring(b)~='HL.Keybind(expired)' then b:set_enabled(false) end end; "
        + "if not s.byModifier then s.byModifier={}; if #s.binds>0 then s.byModifier.CTRL=s.binds end end; "
        + "local modifier=" + modifierToken(modifier) + "; "
        + "local binds=s.byModifier[modifier] or {}; local keypad={90,87,88,89,83,84,85,79,80,81}; "
        + "for digit=0,9 do local top=modifier:find('SHIFT',1,true) and ('code:'..(digit==0 and 19 or 9+digit)) or tostring(digit); "
        + "for i,key in ipairs({top,'code:'..keypad[digit+1]}) do local index=digit*2+i; "
        + "if not binds[index] or tostring(binds[index])=='HL.Keybind(expired)' then binds[index]=hl.bind(modifier..' + '..key,function() if not s.owner then return {ok=false} end; "
        + "hl.dispatch(hl.dsp.event('windowpeek-shortcut-digit,'..s.owner..','..digit)); "
        + "end,{auto_consuming=true,description='WindowPeek: visible window '..digit}) end end end; s.byModifier[modifier]=binds; "
        + "s.binds=s.byModifier[modifier]; s.owner=" + token(owner) + "; "
        + "for _,b in ipairs(s.binds) do if tostring(b)~='HL.Keybind(expired)' then b:set_enabled(true) end end; s.timer:set_timeout(750); ";
}
function renew(owner) {
    return "local s=_windowpeek_shortcuts_v1; if s and (not s.owner or s.owner==" + token(owner)
        + ") then if not s.owner then s.owner=" + token(owner)
        + "; for _,b in ipairs(s.binds) do if tostring(b)~='HL.Keybind(expired)' then b:set_enabled(true) end end end; s.timer:set_timeout(750) end; ";
}
function release(owner) {
    return "local s=_windowpeek_shortcuts_v1; if s and s.owner==" + token(owner) + " then s.stop() end; ";
}
function dispatch(code) { return "(function() " + code + "return hl.dsp.no_op() end)()"; }
