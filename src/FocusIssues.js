// Local suspected-source history and notification choices, never protection grants.
function clean(value, limit) {
    return typeof value === "string" ? value.replace(/[\x00-\x1f\x7f]/g, "").trim().slice(0, limit) : "";
}
function appKey(klass) { return klass ? "x11:" + encodeURIComponent(klass) : ""; }
function empty() { return {version: 1, ignoreAll: false, ignoredSession: "", apps: []}; }
function normalize(raw) {
    if (!raw || raw.version !== 1 || !Array.isArray(raw.apps)) throw new Error("Invalid focus issues file");
    var seen = {}, apps = [];
    raw.apps.slice(0, 256).forEach(function(a) {
        if (!a || typeof a !== "object") return;
        var klass = clean(a.klass, 256), key = appKey(klass);
        if (!key || a.key !== key || seen[key]) return;
        seen[key] = true;
        var first = Number.isSafeInteger(a.firstSeen) && a.firstSeen > 0 ? a.firstSeen : 0;
        var last = Number.isSafeInteger(a.lastSeen) && a.lastSeen >= first ? a.lastSeen : first;
        apps.push({key: key, klass: klass, name: clean(a.name, 128) || klass,
            kind: "suspected-x11-resize", firstSeen: first, lastSeen: last,
            incidents: Number.isSafeInteger(a.incidents) ? Math.max(1, Math.min(1000000, a.incidents)) : 1,
            ignored: a.ignored === true});
    });
    return {version: 1, ignoreAll: raw.ignoreAll === true,
        ignoredSession: clean(raw.ignoredSession, 256), apps: apps};
}
function record(data, client, now) {
    var next = normalize(data);
    if (!client || client.xwayland !== true || !Number.isSafeInteger(now) || now <= 0) return next;
    // Initial class survives changing runtime classes; never use title/PID/address as an app key.
    var klass = clean(client.initialClass || client.class, 256), key = appKey(klass);
    if (!key) return next;
    var item = next.apps.find(function(a) { return a.key === key; });
    if (!item) {
        // Bound history without silently discarding an ignore choice.
        if (next.apps.length >= 256) {
            var index = -1;
            next.apps.forEach(function(a, i) { if (!a.ignored && (index < 0 || a.lastSeen < next.apps[index].lastSeen)) index = i; });
            if (index < 0) return next;
            next.apps.splice(index, 1);
        }
        item = {key: key, klass: klass, name: clean(client.app, 128) || klass,
            kind: "suspected-x11-resize", firstSeen: now, lastSeen: now, incidents: 0, ignored: false};
        next.apps.push(item);
    }
    item.lastSeen = now; item.incidents = Math.min(1000000, item.incidents + 1);
    if (clean(client.app, 128)) item.name = clean(client.app, 128);
    return next;
}
function muted(data, desktopSession, key) {
    return data.ignoreAll || (!!desktopSession && data.ignoredSession === desktopSession)
        || (!!key && data.apps.some(function(a) { return a.key === key && a.ignored; }));
}
function choose(data, scope, value, desktopSession, key) {
    var next = normalize(data);
    if (scope === "all") next.ignoreAll = value === true;
    else if (scope === "session") next.ignoredSession = value === true ? desktopSession : "";
    else if (scope === "app") {
        var app = next.apps.find(function(a) { return a.key === key; });
        if (app) app.ignored = value === true;
    }
    return next;
}
