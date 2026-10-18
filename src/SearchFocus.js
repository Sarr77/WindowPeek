// Keep keyboard focus while allowing pointer input to pass to other windows.
// Hyprland 0.56's exclusive layers and focus grabs also capture the pointer.
// Temporarily use click-to-focus, with a short compositor-side expiry so a dead
// shell cannot leave this behavior behind. Never write the user's config files.
function token(value) {
    if (typeof value !== "string" || !/^[a-z0-9:-]+$/.test(value)) throw new Error("Invalid search-focus token");
    return "'" + value + "'";
}
function install(owner, reloaded) {
    return "local s=_windowpeek_search_focus_v1; if not s then s={} _windowpeek_search_focus_v1=s end; "
        + "function s.stop() if s.saved~=nil and hl.get_config('input.follow_mouse')==3 then hl.config({input={follow_mouse=s.saved}}) end; s.saved=nil; s.owner=nil; s.timer:set_enabled(false) end; "
        + "if not s.timer then s.timer=hl.timer(function() s.stop() end,{timeout=750,type='repeat'}) end; "
        + (reloaded ? "s.saved=nil; s.owner=nil; " : "")
        + "if s.saved==nil then s.saved=hl.get_config('input.follow_mouse') end; "
        + "if type(s.saved)=='number' then hl.config({input={follow_mouse=3}}); s.owner=" + token(owner)
        + "; s.timer:set_timeout(750); end; ";
}
function renew(owner) {
    return "local s=_windowpeek_search_focus_v1; if s and s.owner==" + token(owner)
        + " then s.timer:set_timeout(750) end; ";
}
function release(owner) {
    return "local s=_windowpeek_search_focus_v1; if s and s.owner==" + token(owner) + " then s.stop() end; ";
}
