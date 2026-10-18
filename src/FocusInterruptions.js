// Session-only evidence for loss status and repeated-loss suggestions. Never identifies an app,
// grants permission, changes preferences or acquires keyboard focus.
function history() { return {events: [], mutedUntil: 0}; }
function prune(history, now) {
    history.events = history.events.filter(function(e) { return e.at <= now && now - e.at <= 120000; }).slice(-8);
}
function observe(history, session, owner, now, eligible) {
    if (!history || !session || session.closed || session.owner !== owner
            || !Number.isFinite(now) || eligible !== true || session.focused
            || !session.acquired || session.lostAt === null || now < session.quietUntil
            || now - session.lostAt < 500 || now - session.lostAt > 2000) return false;
    prune(history, now);
    var key = owner + ":" + session.lostAt;
    if (history.events.some(function(e) { return e.key === key; })) return false;
    history.events.push({key: key, at: session.lostAt});
    return true;
}
function canSuggest(history, now) {
    return !!history && Number.isFinite(now) && now >= history.mutedUntil;
}
function suggested(history, now) {
    if (!canSuggest(history, now)) return false;
    prune(history, now);
    return history.events.length >= 3;
}
function dismiss(history, now) {
    history.events = [];
    history.mutedUntil = now + 1800000;
}
