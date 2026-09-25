// Temporary rules apply only to WindowPeek's own uniquely titled window. The
// compositor-side lease releases focus and disables handles after shell failure.
function token(value) {
    if (typeof value !== "string" || !/^[a-z0-9:-]+$/.test(value)) throw new Error("Invalid protection token");
    return "'" + value + "'";
}
function number(value) {
    if (!Number.isFinite(value) || Math.abs(value) > 131072) throw new Error("Invalid panel geometry");
    return String(Math.round(value));
}
function install(owner, pid, monitor, x, y, width, height, strict, initialHold, anchorRect, panelRect, previewRect, popupRect) {
    token(owner);
    if (!Number.isSafeInteger(pid) || pid < 1 || !/^[a-zA-Z0-9_.:-]+$/.test(monitor)) throw new Error("Invalid panel identity");
    var title = "WindowPeek protection " + owner;
    var hold = initialHold !== false ? "true" : "false";
    return "if _windowpeek_native_focus_v1 and _windowpeek_native_focus_v1.stop then _windowpeek_native_focus_v1.stop() end; "
        + "local s=_windowpeek_native_focus_v2; if not s then s={binds={}}; _windowpeek_native_focus_v2=s end; "
        + "if s.stop then s.stop() end; "
        + "if s.callbackVersion~=4 then s.binds={}; s.callbackVersion=4 end; "
        + "function s.window() if not s.owner then return nil end; for _,w in ipairs(hl.get_windows()) do "
        + "if w.mapped and w.title==s.title and w.pid==s.pid then return w end end end; "
        // Hyprland chooses floating windows by their outer rectangle before
        // consulting the surface input mask. Exclude our transparent viewport
        // from that hit test while yielding, and restore it on pointer entry.
        // This timer does no IPC/UI work and changes a property only on entry/exit.
        + "function s.inside(p,r) return p and r and p.x>=r.x and p.y>=r.y and p.x<r.x+r.width and p.y<r.y+r.height end; "
        + "function s.route() if not s.owner then return end; local p=hl.get_cursor_pos(); local skip=not (s.enabled and not s.yielded) and not (s.inside(p,s.bounds) or s.inside(p,s.preview) or s.inside(p,s.popup)); "
        + "if skip~=s.noFocus then local w=s.window(); if w then hl.dispatch(hl.dsp.window.set_prop({prop='no_focus',value=skip and 'true' or 'false',window=w})); s.noFocus=skip; if p then hl.dispatch(hl.dsp.cursor.move({x=p.x,y=p.y})) end end end end; "
        + "if not s.routeTimer then s.routeTimer=hl.timer(function() s.route() end,{timeout=16,type='repeat'}) end; "
        + "function s.hold(value) local w=s.window(); if w then hl.dispatch(hl.dsp.window.set_prop({prop='stay_focused',value=value and 'true' or 'false',window=w})) end; s.route(); s.routeTimer:set_enabled(not (s.enabled and not s.yielded)) end; "
        + "function s.stop() s.hold(false); if s.rule and tostring(s.rule)~='HL.WindowRule(expired)' then s.rule:set_enabled(false) end; "
        + "for _,b in ipairs(s.binds) do if tostring(b)~='HL.Keybind(expired)' then b:set_enabled(false) end end; "
        + "local w=s.window(); if w then hl.dispatch(hl.dsp.window.set_prop({prop='no_focus',value='false',window=w})) end; "
        + "s.owner=nil; if s.timer then s.timer:set_enabled(false) end; if s.routeTimer then s.routeTimer:set_enabled(false) end end; "
        + "function s.expire() local owner=s.owner; s.stop(); if owner then hl.dispatch(hl.dsp.event('windowpeek-protection-expired,'..owner)) end end; "
        + "if s.leaseVersion~=2 then if s.timer then s.timer:set_enabled(false) end; s.timer=nil; s.leaseVersion=2 end; "
        + "if not s.timer then s.timer=hl.timer(function() s.expire() end,{timeout=1000,type='repeat'}) end; "
        + "s.presented=false; s.noFocus=nil; s.owner=" + token(owner) + "; s.pid=" + pid + "; s.title='" + title + "'; s.enabled=" + hold + "; s.yielded=false; s.strict=" + (strict === true ? "true" : "false") + "; "
        + anchor(owner, anchorRect)
        + bounds(owner, panelRect, previewRect, popupRect)
        + "s.rule=hl.window_rule({name='windowpeek-temporary-focus',match={title='^" + title + "$'},float=true,"
        + "stay_focused=" + hold + ",monitor='" + monitor + "',move={'" + number(x) + "','" + number(y) + "'},"
        + "size={'" + number(width) + "','" + number(height) + "'},no_anim=true,no_shadow=true,no_blur=true,border_size=0}); "
        + "for i,key in ipairs({'mouse_up','mouse_down','mouse_left','mouse_right','mouse:272','mouse:273','mouse:274'}) do local b=s.binds[i]; "
        + "if not b or tostring(b)=='HL.Keybind(expired)' then b=hl.bind(key,function() "
        + "if not s.owner then return {ok=false} end; local w=s.window(); local p=hl.get_cursor_pos(); if not w or not p then return {ok=false} end; "
        + "local a=s.anchor; if i>=5 and s.enabled and a and p.x>=a.x and p.y>=a.y and p.x<a.x+a.width and p.y<a.y+a.height then "
        + "s.yielded=false; s.hold(true); if not w.active then hl.dispatch(hl.dsp.focus({window=w})); hl.dispatch(hl.dsp.cursor.move({x=p.x,y=p.y})) end; "
        + "hl.dispatch(hl.dsp.event('windowpeek-protection-resume,'..s.owner)); "
        + "hl.dispatch(hl.dsp.event('windowpeek-protection-bar,'..s.owner..','..({1,2,4})[i-4])); return {ok=true} end; "
        + "local r=s.bounds; local inside=r and p.x>=r.x and p.y>=r.y and p.x<r.x+r.width and p.y<r.y+r.height; "
        + "if not inside and not (s.strict and s.enabled and i<5) then s.yielded=true; s.hold(false); hl.dispatch(hl.dsp.cursor.move({x=p.x,y=p.y})); "
        + "hl.dispatch(hl.dsp.event('windowpeek-protection-yield,'..s.owner..','..(i<5 and 'outside-wheel' or 'outside-button'))); "
        + "elseif i>=5 then if s.enabled then s.yielded=false; s.hold(true); hl.dispatch(hl.dsp.event('windowpeek-protection-resume,'..s.owner)) else s.route() end; "
        + "if not w.active then hl.dispatch(hl.dsp.focus({window=w})) end; hl.dispatch(hl.dsp.cursor.move({x=p.x,y=p.y})) end; "
        + "return {ok=false}; end,{non_consuming=i<5,auto_consuming=i>=5,ignore_mods=true,description='WindowPeek: temporary focus protection'}); s.binds[i]=b end; "
        + "if tostring(b)~='HL.Keybind(expired)' then b:set_enabled(true) end end; s.timer:set_timeout(1000); ";
}
function renew(owner, enabled, x, y, width, height, anchorRect) {
    return "local s=_windowpeek_native_focus_v2; if s and s.owner==" + token(owner)
        + " then s.enabled=" + (enabled ? "true" : "false") + "; s.hold(s.enabled and not s.yielded); s.timer:set_timeout(1000) end; "
        + (x !== undefined && y !== undefined ? position(owner, x, y, width, height) : "")
        + (anchorRect ? anchor(owner, anchorRect) : "");
}
function release(owner) {
    return "local s=_windowpeek_native_focus_v2; if s and s.owner==" + token(owner) + " then s.stop() end; ";
}
// Resize and restore the bar anchor in the same compositor callback. Floating
// resize keeps the old centre; a later position callback would show that jump.
function position(owner, x, y, width, height) {
    return "local s=_windowpeek_native_focus_v2; if s and s.owner==" + token(owner)
        + " then local w=s.window(); "
        // A dynamic override survives release of the temporary rule until this
        // very window unmaps. Otherwise disabling protection can animate away
        // the old native buffer over the already restored layer panel.
        + "if w and not s.presented then hl.dispatch(hl.dsp.window.set_prop({window=w,prop='no_anim',value='true'})); s.presented=true end; "
        + (width !== undefined && height !== undefined ? "if w and (math.abs(w.size.x-" + number(width) + ")>0.5 or math.abs(w.size.y-" + number(height) + ")>0.5) then hl.dispatch(hl.dsp.window.resize({x=" + number(width) + ",y=" + number(height) + ",relative=false,window=w})) end; " : "")
        + "if w and (math.abs(w.at.x-" + number(x) + ")>0.5 or math.abs(w.at.y-" + number(y) + ")>0.5) then hl.dispatch(hl.dsp.window.move({x=" + number(x)
        + ",y=" + number(y) + ",relative=false,window=w})) end end; ";
}

// Only the plugin's own label is handled here. Native focus protection can
// prevent its layer surface receiving a click; forward that physical press once
// and consume it conditionally so Qt cannot also toggle the same panel.
function anchor(owner, rect) {
    rect = rect || {x: 0, y: 0, width: 0, height: 0};
    return "local s=_windowpeek_native_focus_v2; if s and s.owner==" + token(owner)
        + " then s.anchor={x=" + number(rect.x) + ",y=" + number(rect.y)
        + ",width=" + number(rect.width) + ",height=" + number(rect.height) + "} end; ";
}

function setStrict(owner, strict) {
    return "local s=_windowpeek_native_focus_v2; if s and s.owner==" + token(owner)
        + " then s.strict=" + (strict === true ? "true" : "false") + " end; ";
}

function bounds(owner, rect, preview, popup) {
    rect = rect || {x:0, y:0, width:1, height:1};
    preview = preview || {x:0, y:0, width:0, height:0};
    popup = popup || {x:0, y:0, width:0, height:0};
    return "local s=_windowpeek_native_focus_v2; if s and s.owner==" + token(owner)
        + " then s.bounds={x=" + number(rect.x) + ",y=" + number(rect.y)
        + ",width=" + number(rect.width) + ",height=" + number(rect.height) + "}; s.preview={x=" + number(preview.x) + ",y=" + number(preview.y)
        + ",width=" + number(preview.width) + ",height=" + number(preview.height) + "}; s.popup={x=" + number(popup.x) + ",y=" + number(popup.y)
        + ",width=" + number(popup.width) + ",height=" + number(popup.height) + "}; s.route() end; ";
}
