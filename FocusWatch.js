function token(value) {
    if (typeof value !== "string" || !/^[a-z0-9:-]+$/.test(value)) throw new Error("Invalid focus observer token");
    return "'" + value + "'";
}
function install(owner) {
    return "local s=_windowpeek_focus_observer_v1; if not s then s={}; _windowpeek_focus_observer_v1=s end; "
        + "if s.stop then s.stop() end; function s.stop() s.owner=nil; if s.event then s.event:remove(); s.event=nil end; "
        + "if s.timer then s.timer:set_enabled(false) end end; "
        + "if not s.timer then s.timer=hl.timer(function() s.stop() end,{timeout=1000,type='repeat'}) end; "
        + "s.owner=" + token(owner) + "; s.event=hl.on('window.active',function(_,reason) "
        + "if s.owner then hl.dispatch(hl.dsp.event('windowpeek-focus-reason,'..s.owner..','..tostring(reason))) end end); s.timer:set_timeout(1000); ";
}
function renew(owner) { return "local s=_windowpeek_focus_observer_v1; if s and s.owner==" + token(owner) + " then s.timer:set_timeout(1000) end; "; }
function release(owner) { return "local s=_windowpeek_focus_observer_v1; if s and s.owner==" + token(owner) + " then s.stop() end; "; }
