// Hyprland 0.56.2 can crash in set_enabled on an expired weak handle.
// tostring checks validity without dereferencing it; reinstall replaces stale handles.
// Short-lived navigation leases cover the compact list's focus acquisition.
function token(value) {
    if (typeof value !== "string" || !/^[a-z0-9:-]+$/.test(value)) throw new Error("Invalid hover token");
    return "'" + value + "'";
}
function definitions(actions) {
    if (!Array.isArray(actions)) throw new Error("Invalid hover actions");
    return "{" + actions.map(function(action) {
        if (!action || !/^[a-z]+$/.test(action.id) || typeof action.chord !== "string"
                || !/^[A-Z0-9_]+( \+ [A-Z0-9_]+)*$/.test(action.chord)) throw new Error("Invalid hover action");
        return "{id='" + action.id + "',chord='" + action.chord + "',repeating=" + (action.repeating === true ? "true" : "false") + "}";
    }).join(",") + "}";
}
function install(owner, actions) {
    return "local h=_windowpeek_hover_keys_v1; if not h then h={cache={},binds={}}; _windowpeek_hover_keys_v1=h; end; "
        + "function h.stop() h.owner=nil; for _,b in ipairs(h.binds) do if tostring(b)~='HL.Keybind(expired)' then b:set_enabled(false) end end; h.timer:set_enabled(false) end; "
        + "if not h.timer then h.timer=hl.timer(function() h.stop() end,{timeout=750,type='repeat'}); end; h.stop(); h.binds={}; "
        + "for _,a in ipairs(" + definitions(actions) + ") do local key=a.id..':'..a.chord; local b=h.cache[key]; "
        + "if not b or tostring(b)=='HL.Keybind(expired)' then b=hl.bind(a.chord,function() if not h.owner then return {ok=false} end; "
        + "hl.dispatch(hl.dsp.event('windowpeek-hover-action,'..h.owner..','..a.id)); "
        + "end,{auto_consuming=true,repeating=a.repeating,description='WindowPeek: hover '..a.id}); h.cache[key]=b end; "
        + "table.insert(h.binds,b); if tostring(b)~='HL.Keybind(expired)' then b:set_enabled(true) end end; h.owner=" + token(owner) + "; h.timer:set_timeout(750); ";
}
function renew(owner) {
    return "local h=_windowpeek_hover_keys_v1; if h and (not h.owner or h.owner==" + token(owner)
        + ") then if not h.owner then h.owner=" + token(owner)
        + "; for _,b in ipairs(h.binds) do if tostring(b)~='HL.Keybind(expired)' then b:set_enabled(true) end end end; h.timer:set_timeout(750) end; ";
}
function release(owner) {
    return "local h=_windowpeek_hover_keys_v1; if h and h.owner==" + token(owner) + " then h.stop() end; ";
}
