// Conservative evidence and consent policy. This module never changes focus,
// window state, input routing or preferences. A candidate is a suspicion, not
// proof that a particular application caused the loss.
// FocusRecovery supplies passive observations and owns the opt-in backend.
function candidateSource(snapshot, id, now) {
    // XRes supplies the server-side PID used by Hyprland. Do not substitute
    // _NET_WM_PID, titles, process names or a guessed RSI-specific match.
    if (!snapshot || typeof id !== "string" || !/^0x[0-9a-f]+$/.test(id)
            || !Number.isFinite(now) || !Number.isFinite(snapshot.at)
            || now < snapshot.at || now - snapshot.at > 500
            || !Array.isArray(snapshot.sources) || !Array.isArray(snapshot.clients)
            || snapshot.sources.length > 256 || snapshot.clients.length > 4096) return null;
    var sources = snapshot.sources.filter(function(s) { return s && s.id === id; });
    if (sources.length !== 1) return null;
    var source = sources[0];
    if (!/^0x[0-9a-f]+$/.test(source.id) || !Number.isInteger(source.pid) || source.pid < 1
            || typeof source.class !== "string" || !source.class || source.managed !== true) return null;
    // Multiple managed X11 windows belonging to one process/class are ambiguous even
    // when only one happens to be visible in the compositor snapshot.
    if (snapshot.sources.filter(function(s) {
        return s && s.managed === true && s.pid === source.pid && s.class === source.class;
    }).length !== 1) return null;
    var clients = snapshot.clients.filter(function(c) {
        return c && c.xwayland === true && c.pid === source.pid && c.class === source.class;
    });
    if (clients.length !== 1) return null;
    var client = clients[0];
    // A tiled window on an inactive workspace still reaches Hyprland's
    // configure/refocus path. Visibility is not a prerequisite for this bug.
    if (typeof client.address !== "string" || !/^0x[0-9a-f]+$/.test(client.address)
            || typeof client.stableId !== "string" || !/^[0-9a-f]+$/.test(client.stableId)
            || client.mapped !== true || client.hidden !== false
            || client.floating !== false || client.fullscreen !== 0) return null;
    return {id: source.id, address: client.address, stableId: client.stableId, pid: source.pid};
}
function session(owner, now) {
    if (typeof owner !== "string" || !/^[a-z0-9:-]+$/.test(owner)
            || !Number.isFinite(now)) throw new Error("Invalid focus incident session");
    return {owner: owner, started: now, closed: false, focused: false, acquired: false,
        lostAt: null, focusAt: now, quietUntil: now, samples: {}, phase: "observing", incident: null,
        consent: false};
}
function current(state, owner) { return !!state && !state.closed && state.owner === owner; }
function end(state) {
    if (!state) return;
    state.closed = true; state.consent = false; state.samples = {};
    state.incident = null; state.lostAt = null; state.phase = "closed";
}
function suspend(state, owner, now) {
    if (!current(state, owner) || !Number.isFinite(now)) return;
    state.quietUntil = Math.max(state.quietUntil, now + 1000);
    state.lostAt = null;
}
function focus(state, owner, active, now, eligible) {
    if (!current(state, owner) || !Number.isFinite(now)) return;
    if (now < state.started) { end(state); return; }
    if (now < state.focusAt) return;
    state.focusAt = now;
    var previous = state.focused;
    state.focused = active === true;
    if (state.focused) { state.acquired = true; state.lostAt = null; return; }
    if (previous && state.acquired && eligible === true && now >= state.quietUntil)
        state.lostAt = now;
    else if (eligible !== true) state.lostAt = null;
}
function geometry(state, owner, sample) {
    if (!current(state, owner) || !sample || typeof sample.id !== "string"
            || !/^0x[0-9a-f]+$/.test(sample.id) || !Number.isFinite(sample.at)
            || sample.at < state.started) return;
    var id = sample.id;
    var old = state.samples[id];
    if (old && sample.at <= old.at) return;
    Object.keys(state.samples).forEach(function(key) {
        if (sample.at - state.samples[key].at > 2000) delete state.samples[key];
    });
    if (sample.atRisk !== true || !Number.isInteger(sample.width) || !Number.isInteger(sample.height)
            || sample.width < 1 || sample.height < 1 || sample.width > 131072 || sample.height > 131072
            || sample.synthetic !== true) {
        delete state.samples[id];
        return;
    }
    if (!Object.prototype.hasOwnProperty.call(state.samples, id) && Object.keys(state.samples).length >= 32) return;
    var size = sample.width + "x" + sample.height;
    var times = old && old.size === size ? old.times : [];
    // Duplicate/out-of-order packets cannot increase confidence.
    if (times.length && sample.at <= times[times.length - 1]) return;
    times = times.filter(function(at) { return sample.at - at <= 2000; });
    times.push(sample.at);
    state.samples[id] = {size: size, times: times.slice(-16), at: sample.at};
}
function inspect(state, owner, now, eligible) {
    if (!current(state, owner) || !Number.isFinite(now) || now < state.started) return null;
    if (state.phase !== "observing" || eligible !== true || state.focused
            || state.lostAt === null || now < state.quietUntil
            || now - state.lostAt < 200 || now - state.lostAt > 2000) return null;
    var candidates = [];
    Object.keys(state.samples).forEach(function(id) {
        // Use the same bounded history as geometry(). Some applications send
        // short bursts about 1.5 seconds apart rather than a steady stream.
        // A narrower asymmetric slice discarded that evidence despite an
        // actual loss next to one of the replies. Keep the near-loss condition.
        var times = state.samples[id].times.filter(function(at) {
            return at <= now && at >= now - 2000;
        });
        if (times.length < 3 || times[times.length - 1] - times[0] < 300) return;
        if (!times.some(function(at) { return Math.abs(at - state.lostAt) <= 200; })) return;
        candidates.push({source: id, replies: times.length});
    });
    // Do not attribute the problem when several possible sources overlap.
    if (candidates.length !== 1) return null;
    state.incident = {kind: "suspected-x11-resize", source: candidates[0].source,
        replies: candidates[0].replies, lostAt: state.lostAt, detectedAt: now};
    state.phase = "offered";
    return state.incident;
}
function protection() { return {grant: null, active: false, notice: null}; }
function decide(state, owner, choice, available, guard, source, backend) {
    if (!current(state, owner) || state.phase !== "offered") return false;
    if (choice === "dismiss") {
        state.phase = "dismissed"; state.consent = false;
        return false;
    }
    // The controller must revalidate source/lifecycle and backend support at
    // the actual click, not when the message was first displayed.
    if (choice !== "allow-for-window" || available !== true || !guard || guard.grant
            || !source || source.id !== state.incident.source
            || typeof source.address !== "string" || !/^0x[0-9a-f]+$/.test(source.address)
            || typeof source.stableId !== "string" || !/^[0-9a-f]+$/.test(source.stableId)
            || !Number.isInteger(source.pid) || source.pid < 1
            || typeof backend !== "string" || !/^[a-z0-9:-]+$/.test(backend)) return false;
    state.phase = "approved"; state.consent = true;
    guard.grant = {address: source.address, stableId: source.stableId, pid: source.pid, backend: backend};
    guard.active = false; guard.notice = null;
    return true;
}
function stopProtection(guard, reason) {
    if (!guard || !guard.grant) return;
    guard.grant = null; guard.active = false;
    guard.notice = {kind: "protection-ended", reason: reason};
}
function reconcileProtection(guard, snapshot, now, panelEligible, backend) {
    if (!guard || !guard.grant) return false;
    var wasActive = guard.active;
    guard.active = false;
    // Unknown inventory is not proof that a window has closed. Keep consent
    // dormant. An active hold may bridge an in-flight refresh up to the reader's
    // two-second deadline; cached data can never start or restart protection.
    if (!snapshot || !Number.isFinite(now) || !Number.isFinite(snapshot.at)
            || now < snapshot.at || (now - snapshot.at > 500
                && !(wasActive && snapshot.pending === true && now - snapshot.at <= 2000))
            || !Array.isArray(snapshot.clients) || snapshot.clients.length > 4096
            || snapshot.complete !== true) return false;
    if (snapshot.clients.some(function(c) {
        return !c || typeof c.address !== "string" || !/^0x[0-9a-f]+$/.test(c.address)
            || typeof c.stableId !== "string" || !/^[0-9a-f]+$/.test(c.stableId)
            || !Number.isInteger(c.pid) || typeof c.mapped !== "boolean";
    })) return false;
    var granted = guard.grant;
    var matches = snapshot.clients.filter(function(c) {
        return c && c.address === granted.address && c.stableId === granted.stableId
            && c.pid === granted.pid;
    });
    if (matches.length === 0) { stopProtection(guard, "window-closed"); return false; }
    if (matches.length !== 1 || matches[0].mapped !== true) return false;
    if (backend !== granted.backend) { stopProtection(guard, "backend-unavailable"); return false; }
    guard.active = panelEligible === true;
    return guard.active;
}
function takeNotice(guard) {
    if (!guard) return null;
    var notice = guard.notice; guard.notice = null;
    return notice;
}
function revoke(state, owner) {
    if (!current(state, owner)) return;
    state.consent = false; state.phase = "dismissed";
}
function forgetSource(state, owner, id) {
    if (!current(state, owner)) return;
    delete state.samples[id];
    if (state.incident && state.incident.source === id) {
        revoke(state, owner);
        state.incident = null;
    }
}
