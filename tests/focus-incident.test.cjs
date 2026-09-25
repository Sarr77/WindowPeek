const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const policy = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../FocusIncident.js'), 'utf8'), policy);
const interruptions = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../FocusInterruptions.js'), 'utf8'), interruptions);
const owner = 'panel:1';
const backend = 'fixture-backend:1';
test('settings suggestion needs three separate unexplained losses, across panel openings', () => {
    const h = interruptions.history();
    for (let i=0; i<3; i++) {
        const token = 'panel:'+i, at=1000+i*10000;
        const s = policy.session(token, at-1000);
        policy.focus(s, token, true, at-100, true);
        policy.focus(s, token, false, at, true);
        assert.equal(interruptions.observe(h,s,token,at+499,true),false);
        assert.equal(interruptions.observe(h,s,token,at+501,true),true);
        assert.equal(interruptions.observe(h,s,token,at+700,true),false,'polling cannot recount one loss');
        assert.equal(interruptions.suggested(h,at+700),i===2);
        assert.equal(s.consent,false);
    }
    assert.equal(interruptions.suggested(h,150000),false,'old losses expire');
});
test('first settled loss can show generic help without attribution or a repeated-loss suggestion', () => {
    const h=interruptions.history(),s=policy.session(owner,0);
    policy.focus(s,owner,true,900,true);policy.focus(s,owner,false,1000,true);
    assert.equal(interruptions.observe(h,s,owner,1501,true),true);
    assert.equal(interruptions.canSuggest(h,1501),true);
    assert.equal(interruptions.suggested(h,1501),false);
    assert.equal(s.phase,'observing');assert.equal(s.consent,false);
    interruptions.dismiss(h,1600);
    assert.equal(interruptions.canSuggest(h,1700),false);
    policy.focus(s,owner,true,1800,true);policy.focus(s,owner,false,2000,true);
    assert.equal(interruptions.observe(h,s,owner,2501,true),true,'a muted reminder does not hide a new loss status');
    assert.equal(interruptions.suggested(h,2501),false);
    assert.equal(interruptions.canSuggest(h,1801600),true);
});
test('intentional switches, no prior focus, recovery and foreign sessions do not suggest', () => {
    for (const alter of [
        s=>policy.suspend(s,owner,1100), s=>policy.focus(s,owner,true,1100,true),
        s=>{s.acquired=false;}, s=>{s.owner='other';}, s=>policy.end(s)
    ]) {
        const h=interruptions.history(),s=policy.session(owner,0);
        policy.focus(s,owner,true,900,true);policy.focus(s,owner,false,1000,true);alter(s);
        assert.equal(interruptions.observe(h,s,owner,1600,true),false);
        assert.equal(interruptions.suggested(h,1600),false);
    }
    const h=interruptions.history(),s=policy.session(owner,0);
    policy.focus(s,owner,true,900,true);policy.focus(s,owner,false,1000,true);
    assert.equal(interruptions.observe(h,s,owner,1600,false),false);
    interruptions.dismiss(h,1600);
    h.events=[{key:'1',at:2000},{key:'2',at:3000},{key:'3',at:4000}];
    assert.equal(interruptions.suggested(h,4500),false,'dismissal stops repeated nudges');
});
function allow(s, guard = policy.protection(), token = owner, available = true) {
    return policy.decide(s, token, 'allow-for-window', available, guard,
        {id:'0x123', address:'0xabc', stableId:'af', pid:42}, backend);
}
function sourceSnapshot() {
    return {at: 1000, sources: [{id: '0x123', pid: 42, class: 'FictionalX11', managed:true}], clients: [{
        address:'0xabc', stableId:'af', pid:42, class:'FictionalX11', xwayland:true,
        mapped:true, hidden:false, visible:true, floating:false, fullscreen:0
    }]};
}
test('source identity needs fresh, unique XRes and compositor matches; no app-name heuristics', () => {
    assert.equal(policy.candidateSource(sourceSnapshot(), '0x123', 1100)?.address, '0xabc');
    for (const change of [
        s => {s.at = 0;}, s => {s.at = 2000;}, s => {s.sources[0].pid = 0;},
        s => {s.clients[0].pid = 43;}, s => {s.clients[0].class = 'Another';},
        s => {s.sources.push({...s.sources[0], id:'0x124'});},
        s => {s.clients.push({...s.clients[0], address:'0xdef', hidden:true});},
        s => {s.clients[0].xwayland = false;}, s => {s.clients[0].floating = true;},
        s => {s.clients[0].fullscreen = 2;}, s => {s.clients[0].hidden = true;},
        s => {s.clients[0].mapped = false;}, s => {delete s.sources[0].managed;},
        s => {delete s.clients[0].stableId;}, s => {delete s.clients[0].floating;},
        s => {s.clients[0].address = 'not-a-window';}
    ]) {
        const s = sourceSnapshot(); change(s);
        assert.equal(policy.candidateSource(s, '0x123', 1100), null);
    }
});
test('managed source on another workspace qualifies; helper windows do not create ambiguity', () => {
    const s = sourceSnapshot();
    s.clients[0].visible = false;
    s.sources.push({...s.sources[0], id:'0x125', managed:false});
    assert.equal(policy.candidateSource(s, '0x123', 1100)?.address, '0xabc');
    assert.equal(policy.candidateSource(s, '0x125', 1100), null);
    s.sources[1].managed = true;
    assert.equal(policy.candidateSource(s, '0x123', 1100), null, 'two actual managed windows stay ambiguous');
});
function example() {
    const s = policy.session(owner, 0);
    policy.focus(s, owner, true, 100, true);
    for (const at of [250, 500, 750, 1000])
        policy.geometry(s, owner, {id: '0x123', at, width: 800, height: 600, synthetic: true, atRisk: true});
    policy.focus(s, owner, false, 950, true);
    return s;
}
test('requires real focus loss and repeated unchanged synthetic replies, then offers only once', () => {
    const s = example();
    assert.equal(policy.inspect(s, owner, 1100, true), null, 'settles before offering');
    assert.equal(policy.inspect(s, owner, 1200, true)?.kind, 'suspected-x11-resize');
    assert.equal(s.consent, false, 'detection is not permission');
    assert.equal(policy.inspect(s, owner, 1300, true), null);
});
test('spaced resize bursts share the full evidence window, including immediately after opening', () => {
    for (const lostAt of [1599, 109]) {
        const s = policy.session(owner, 0);
        policy.focus(s, owner, true, 20, true);
        for (const at of [100, 104, 108, 1600, 1604, 1608])
            policy.geometry(s, owner, {id:'0x123',at,width:800,height:600,synthetic:true,atRisk:true});
        policy.focus(s, owner, false, lostAt, true);
        assert.equal(policy.inspect(s, owner, 1850, true)?.kind, 'suspected-x11-resize');
    }
});
test('no alert merely because an X11 app exists or replies', () => {
    const s = example(); s.lostAt = null; s.focused = true;
    assert.equal(policy.inspect(s, owner, 1200, true), null);
    const missing = example(); missing.samples = {};
    assert.equal(policy.inspect(missing, owner, 1200, true), null);
});
test('ordinary resize, changing size, stale bursts and single replies do not qualify', () => {
    for (const alteration of [
        s => policy.geometry(s, owner, {id:'0x123', at:1050, width:800, height:600, synthetic:false, atRisk:true}),
        s => policy.geometry(s, owner, {id:'0x123', at:1050, width:801, height:600, synthetic:true, atRisk:true}),
        s => {s.samples['0x123'].times = [1, 2, 3];},
        s => {s.samples['0x123'].times = [1000];},
        s => {s.samples['0x123'].times = [900, 901, 902];}
    ]) {
        const s = example(); alteration(s);
        assert.equal(policy.inspect(s, owner, 1200, true), null);
    }
});
test('intended input/state change before or just after focus loss cancels the candidate', () => {
    const s = example(); policy.suspend(s, owner, 960);
    assert.equal(policy.inspect(s, owner, 1200, true), null);
    const before = example(); policy.focus(before, owner, true, 900, true);
    policy.suspend(before, owner, 940); policy.focus(before, owner, false, 950, true);
    assert.equal(policy.inspect(before, owner, 1200, true), null);
});
test('opening, menus, previews, dismissal and spontaneous focus recovery do not prompt', () => {
    const s = policy.session(owner, 0);
    policy.focus(s, owner, false, 950, true);
    assert.equal(s.lostAt, null, 'must previously own focus');
    for (const change of [
        s => policy.focus(s, owner, false, 951, false),
        s => policy.focus(s, owner, true, 1000, true),
        s => policy.end(s)
    ]) {
        const s = example(); change(s);
        assert.equal(policy.inspect(s, owner, 1200, true), null);
    }
    assert.equal(policy.inspect(example(), owner, 1200, false), null);
});
test('ambiguous sources and unclassified windows fail closed', () => {
    const s = example(); s.samples['0x124'] = s.samples['0x123'];
    assert.equal(policy.inspect(s, owner, 1200, true), null);
    const unclassified = example();
    policy.geometry(unclassified, owner, {id:'0x123', at:1050, width:800, height:600, synthetic:true});
    assert.equal(policy.inspect(unclassified, owner, 1200, true), null);
});
test('only an explicit current-session decision with an available backend grants permission', () => {
    const s = example();
    assert.equal(allow(s), false, 'no prior offer');
    policy.inspect(s, owner, 1200, true);
    assert.equal(allow(s, policy.protection(), 'panel:old'), false);
    assert.equal(allow(s, policy.protection(), owner, false), false);
    assert.equal(policy.decide(s, owner, 'timeout', true), false);
    assert.equal(s.consent, false);
    assert.equal(allow(s), true);
    policy.end(s);
    assert.equal(s.consent, false, 'closing clears the detector decision');
    const reopened = policy.session('panel:2', 2000);
    assert.equal(reopened.consent, false, 'a new detector cannot make an approval decision');
});
test('dismissal and revocation cannot be reversed by late telemetry', () => {
    for (const action of ['dismiss', 'revoke']) {
        const s = example(); policy.inspect(s, owner, 1200, true);
        if (action === 'dismiss') policy.decide(s, owner, 'dismiss', true);
        else {allow(s); policy.revoke(s, owner);}
        assert.equal(policy.inspect(s, owner, 1300, true), null);
        assert.equal(allow(s), false);
        assert.equal(s.consent, false);
    }
});
test('consent belongs to the confirmed window lifetime; panel closure suspends protection, not consent', () => {
    const s = example(), guard = policy.protection();
    policy.inspect(s, owner, 1200, true);
    assert.equal(allow(s, guard), true);
    const snapshot = {...sourceSnapshot(), complete:true};
    assert.equal(policy.reconcileProtection(guard, snapshot, 1200, true, backend), true);
    policy.end(s);
    assert.equal(policy.reconcileProtection(guard, snapshot, 1250, false, backend), false);
    assert.ok(guard.grant);
    assert.equal(policy.takeNotice(guard), null);
    assert.equal(policy.reconcileProtection(guard, snapshot, 1300, true, backend), true);
    snapshot.at = 1400; snapshot.clients = [];
    assert.equal(policy.reconcileProtection(guard, snapshot, 1400, true, backend), false);
    assert.equal(guard.grant, null);
    assert.equal(policy.takeNotice(guard)?.reason, 'window-closed');
    assert.equal(policy.takeNotice(guard), null, 'only one notification');
    assert.equal(policy.reconcileProtection(guard, sourceSnapshot(), 1400, true, backend), false);
});
test('no closure notification from failed/stale inventory; reused window identity never inherits consent', () => {
    for (const invalid of [null, {at:1000, clients:[]}, {at:0, complete:true, clients:[]},
        {at:2000, complete:true, clients:[]}]) {
        const s = example(), guard = policy.protection();
        policy.inspect(s, owner, 1200, true); allow(s, guard);
        policy.reconcileProtection(guard, invalid, 1200, true, backend);
        assert.ok(guard.grant); assert.equal(guard.active, false);
        assert.equal(policy.takeNotice(guard), null);
    }
    for (const key of ['stableId', 'pid']) {
        const s = example(), guard = policy.protection();
        policy.inspect(s, owner, 1200, true); allow(s, guard);
        const snapshot = {...sourceSnapshot(), complete:true}; snapshot.clients[0][key] = key === 'pid' ? 43 : 'b0';
        policy.reconcileProtection(guard, snapshot, 1200, true, backend);
        assert.equal(guard.grant, null);
        assert.equal(policy.takeNotice(guard)?.reason, 'window-closed');
    }
    const s = example(), guard = policy.protection();
    policy.inspect(s, owner, 1200, true); allow(s, guard);
    const malformed = {...sourceSnapshot(), complete:true}; delete malformed.clients[0].stableId;
    policy.reconcileProtection(guard, malformed, 1200, true, backend);
    assert.ok(guard.grant);
    assert.equal(guard.active, false);
    assert.equal(policy.takeNotice(guard), null);
});
test('permission cannot cross source or backend and manual stop cannot be undone by telemetry', () => {
    const s = example(), guard = policy.protection(); policy.inspect(s, owner, 1200, true);
    assert.equal(policy.decide(s, owner, 'allow-for-window', true, guard,
        {id:'0x456', address:'0xabc', stableId:'af', pid:42}, backend), false);
    assert.equal(allow(s, guard), true);
    const snapshot = {...sourceSnapshot(), complete:true};
    policy.reconcileProtection(guard, snapshot, 1200, true, 'different-backend');
    assert.equal(guard.grant, null);
    assert.equal(policy.takeNotice(guard)?.reason, 'backend-unavailable');
    const next = example(); policy.inspect(next, owner, 1200, true); allow(next, guard);
    policy.stopProtection(guard, 'user');
    assert.equal(policy.reconcileProtection(guard, snapshot, 1200, true, backend), false);
    assert.equal(policy.takeNotice(guard)?.reason, 'user');
});
test('source disappearance, identity change or failed revalidation revokes offered and approved sessions', () => {
    for (const approved of [false, true]) {
        const s = example(); policy.inspect(s, owner, 1200, true);
        if (approved) allow(s);
        policy.forgetSource(s, owner, '0x123');
        assert.equal(s.incident, null);
        assert.equal(s.consent, false);
        assert.equal(allow(s), false);
    }
});
test('late focus/geometry packets cannot replace newer state; inactive sources free the bounded budget', () => {
    const s = example();
    policy.focus(s, owner, true, 900, true);
    assert.equal(s.focused, false);
    policy.geometry(s, owner, {id:'0x123', at:900, width:1, height:1, synthetic:false, atRisk:false});
    assert.equal(policy.inspect(s, owner, 1200, true)?.source, '0x123');
    const many = policy.session(owner, 0);
    for (let n=1;n<=32;n++) policy.geometry(many, owner, {
        id:'0x'+n.toString(16), at:100, width:800, height:600, synthetic:true, atRisk:true
    });
    policy.geometry(many, owner, {id:'0x99', at:3000, width:800, height:600, synthetic:true, atRisk:true});
    assert.deepEqual(Object.keys(many.samples), ['0x99']);
});
test('foreign sessions, malformed data, duplicate packets and backwards time are ignored', () => {
    const s = policy.session(owner, 100);
    for (const sample of [null, {}, {id:'__proto__', at:200}, {id:'0x1', at:NaN}])
        policy.geometry(s, owner, sample);
    policy.geometry(s, 'panel:old', {id:'0x1',at:200,width:1,height:1,synthetic:true,atRisk:true});
    assert.equal(Object.keys(s.samples).length, 0);
    for (let n=0;n<100;n++)
        policy.geometry(s, owner, {id:'0x1',at:200,width:1,height:1,synthetic:true,atRisk:true});
    assert.equal(s.samples['0x1'].times.length, 1);
    policy.focus(s, owner, true, 50, true);
    assert.equal(s.closed, true);
});
test('replays private native focus and geometry traces without flagging the controls', () => {
    const traces = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/focus-incidents.json'), 'utf8'));
    for (const trace of traces) {
        const s = policy.session(owner, 0);
        let cursor = 0, eligible = true, offered = false;
        const end = trace.events.at(-1).at + 250;
        for (let now = 0; now <= end; now += 50) {
            while (cursor < trace.events.length && trace.events[cursor].at <= now) {
                const event = trace.events[cursor++];
                if (event.kind === 'geometry') policy.geometry(s, owner, event);
                else if (event.kind === 'reason' && event.reason !== 5) policy.suspend(s, owner, event.at);
                else if (event.kind === 'focus') {
                    eligible = event.eligible;
                    policy.focus(s, owner, event.active, event.at, eligible);
                }
            }
            if (policy.inspect(s, owner, now, eligible)) offered = true;
        }
        assert.equal(offered, trace.expectedOffer, trace.name);
        assert.equal(s.consent, false, 'a detected problem never authorizes a workaround');
    }
});

test('pending refresh preserves only an already-active hold within the reader deadline', () => {
    const s = example(), guard = policy.protection();
    policy.inspect(s, owner, 1200, true); allow(s, guard);
    const snapshot = {...sourceSnapshot(), at:1200, complete:true};
    assert.equal(policy.reconcileProtection(guard, snapshot, 1200, true, backend), true);
    snapshot.pending = true;
    assert.equal(policy.reconcileProtection(guard, snapshot, 1950, true, backend), true);
    assert.equal(policy.reconcileProtection(guard, snapshot, 3199, true, backend), true);
    assert.equal(policy.reconcileProtection(guard, snapshot, 3201, true, backend), false);
    assert.ok(guard.grant, 'an expired refresh does not invent closure');
    assert.equal(policy.reconcileProtection(guard, snapshot, 3202, true, backend), false, 'old data cannot restart protection');
    snapshot.at = 3203; snapshot.pending = false; snapshot.clients = [];
    assert.equal(policy.reconcileProtection(guard, snapshot, 3203, true, backend), false);
    assert.equal(guard.grant, null, 'fresh confirmed closure still revokes immediately');
});
