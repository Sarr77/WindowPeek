// Observe buttons without consuming them. A short lease limits observation to
// an open panel and expires if the shell exits without releasing its handles.
// A wheel rechecks the surface at the unchanged cursor position synchronously.
// Hyprland otherwise keeps the prime's old pointer target until physical motion,
// even after the layer input region has shrunk. The original axis event passes.
function token(value) {
    if (typeof value !== "string" || !/^[a-z0-9:-]+$/.test(value)) throw new Error("Invalid outside-click token");
    return "'" + value + "'";
}
function install(owner) {
    return "local s=_windowpeek_outside_clicks_v1; if not s then s={binds={}}; _windowpeek_outside_clicks_v1=s end; "
        + "function s.stop() s.owner=nil; for _,b in ipairs(s.binds) do if tostring(b)~='HL.Keybind(expired)' then b:set_enabled(false) end end; s.timer:set_enabled(false) end; "
        + "if not s.timer then s.timer=hl.timer(function() s.stop() end,{timeout=750,type='repeat'}) end; "
        + "for i,key in ipairs({'mouse:272','mouse:273','mouse:274','mouse_up','mouse_down','mouse_left','mouse_right'}) do local b=s.binds[i]; "
        + "if not b or tostring(b)=='HL.Keybind(expired)' then b=hl.bind(key,function() if s.owner then local p=hl.get_cursor_pos(); "
        + "if p then if i<=3 then hl.dispatch(hl.dsp.event('windowpeek-outside-click,'..s.owner..','..p.x..','..p.y)) else hl.dispatch(hl.dsp.cursor.move({x=p.x,y=p.y})) end end end; "
        + "end,{non_consuming=true,ignore_mods=true,description='WindowPeek: outside click'}); s.binds[i]=b end; "
        + "if tostring(b)~='HL.Keybind(expired)' then b:set_enabled(true) end end; s.owner=" + token(owner) + "; s.timer:set_timeout(750); ";
}
function renew(owner) {
    return "local s=_windowpeek_outside_clicks_v1; if s and (not s.owner or s.owner==" + token(owner)
        + ") then s.owner=" + token(owner)
        + "; for _,b in ipairs(s.binds) do if tostring(b)~='HL.Keybind(expired)' then b:set_enabled(true) end end; s.timer:set_timeout(750) end; ";
}
function release(owner) {
    return "local s=_windowpeek_outside_clicks_v1; if s and s.owner==" + token(owner) + " then s.stop() end; ";
}
