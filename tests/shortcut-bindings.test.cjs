const { test } = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const vm = require('node:vm');
const bindings = vm.createContext({});
vm.runInContext(fs.readFileSync(require('node:path').join(__dirname, '../ShortcutBindings.js'), 'utf8'), bindings);

test('digit leases consume both keyboards, expire, reuse handles and preserve another owner', () => {
    const script = `
local keys, events = {}, {}
hl = {dsp={event=function(value) return value end, no_op=function() return 'noop' end}}
function hl.dispatch(value) table.insert(events,value) end
function hl.bind(key, callback, flags)
    assert(flags.auto_consuming and not flags.repeating and not flags.locked)
    local bind = {enabled=true, callback=callback}
    function bind:set_enabled(value) self.enabled=value end
    assert(not keys[key], 'binding handles must be reused')
    keys[key]=bind
    return bind
end
function hl.timer(callback, options)
    assert(options.timeout==750 and options.type=='repeat')
    local timer={callback=callback,enabled=true}
    function timer:set_enabled(value) self.enabled=value end
    function timer:set_timeout(value) assert(value==750); self.enabled=true end
    return timer
end
local function enabled(expected)
    local count=0
    for _,b in pairs(keys) do assert(b.enabled==expected); count=count+1 end
    assert(count==20)
end
${bindings.install('first:1')}
enabled(true)
local keypad={90,87,88,89,83,84,85,79,80,81}
for digit=0,9 do
    for _,key in ipairs({tostring(digit),'code:'..keypad[digit+1]}) do
        keys['CTRL + '..key].callback()
        assert(events[#events]=='windowpeek-shortcut-digit,first:1,'..digit)
    end
end
${bindings.release('stale:1')}
enabled(true)
${bindings.install('second:2')}
${bindings.release('first:1')}
${bindings.renew('first:1')}
enabled(true)
keys['CTRL + code:85'].callback()
assert(events[#events]=='windowpeek-shortcut-digit,second:2,6')
_windowpeek_shortcuts_v1.timer.callback()
enabled(false)
assert(keys['CTRL + 6'].callback().ok==false, 'expired callback must pass through')
assert(not _windowpeek_shortcuts_v1.timer.enabled)
${bindings.renew('second:2')}
enabled(true)
${bindings.release('second:2')}
enabled(false)
assert(not _windowpeek_shortcuts_v1.owner)
`;
    execFileSync('lua', ['-'], { input: script, encoding: 'utf8' });
});

test('only internal session tokens can enter Lua commands', () => {
    for (const value of ['', "a');error('bad", 'a,b', '\n', null, 0])
        for (const method of ['install', 'renew', 'release'])
            assert.throws(() => bindings[method](value), /Invalid shortcut token/);
});

const vocabulary = vm.createContext({});
vm.runInContext(fs.readFileSync(require("node:path").join(__dirname,"../Shortcuts.js"),"utf8"), vocabulary);
const opener = vm.createContext({Keys:vocabulary});
vm.runInContext(fs.readFileSync(require('node:path').join(__dirname, '../OpenShortcut.js'), 'utf8').replace(/^\.import.*\n/gm, ''), opener);
test('automatic opening preserves configured chords and rejects unreadable inventories', () => {
    assert.equal(opener.occupied([]), false);
    for (const list of [null, {}, [{modmask:72,key:'P'}], [{modmask:72,keycode:33}],
        [{modmask:72,key:'p',submap:'custom',submap_universal:'true'}], [{catch_all:true}]])
        assert.equal(opener.occupied(list), true);
    for (const list of [[{modmask:64,key:'P'}], [{modmask:72,key:'O'}],
        [{modmask:72,key:'P',submap:'custom'}],
        [{modmask:72,key:'P',description:'WindowPeek: open window list (automatic)'}]])
        assert.equal(opener.occupied(list), false);
});
test('default opening reuses its handle and releases it after disable or a dead shell', () => {
    const script = `
local created,events=0,{}
hl={dsp={event=function(v) return v end}}
function hl.dispatch(value) table.insert(events,value) end
function hl.bind(key,callback,flags)
    assert(key=='SUPER + ALT + P' and flags.auto_consuming and not flags.locked)
    created=created+1
    local b={callback=callback,enabled=true}
    function b:set_enabled(value) self.enabled=value end
    return b
end
function hl.timer(callback,options)
    assert(options.timeout==15000 and options.type=='repeat')
    local t={callback=callback,enabled=true}
    function t:set_enabled(value) self.enabled=value end
    function t:set_timeout(value) assert(value==15000); self.enabled=true end
    return t
end
${opener.install('owner:1')}
local s=_windowpeek_open_v1
s.bind.callback(); assert(events[1]=='windowpeek-open,owner:1')
${opener.install('owner:2')}
${opener.release('owner:1')}
${opener.renew('owner:1')}
assert(created==1 and s.bind.enabled and s.owner=='owner:2')
s.bind.callback(); assert(events[2]=='windowpeek-open,owner:2')
s.timer.callback()
assert(not s.bind.enabled and not s.owner and not s.timer.enabled)
assert(s.bind.callback().ok==false)
${opener.renew('owner:2')}
assert(s.bind.enabled and s.timer.enabled)
${opener.release('owner:2')}
assert(not s.bind.enabled and not s.owner)
`;
    execFileSync('lua',['-'],{input:script,encoding:'utf8'});
    for (const value of ['', "bad');code()", null])
        for (const method of ['install','renew','release']) assert.throws(()=>opener[method](value));
});

test('custom shortcut validation protects typing, focus traversal and number selection', () => {
    const c = vocabulary;
    assert.deepEqual(Object.keys(c.collisions(c.defaults)), []);
    for (const chord of ['Tab','Shift+Tab','Enter','Esc','Space'])
        assert.equal(c.collisions({...c.defaults,next:chord}).next.type,'reserved');
    assert.equal(c.collisions({...c.defaults,next:'J'}).next.type,'text');
    assert.equal(c.collisions({...c.defaults,next:'Alt+2',numbers:'Alt'}).next.type,'duplicate');
    assert.equal(c.collisions({...c.defaults,next:'2'}).next.type,'quickDigits');
    assert.equal(c.collisions({...c.defaults,open:'P'}).open.type,'globalModifier');
    assert.equal(c.collisions({...c.defaults,open:'Ctrl+1'}).open.type,'duplicate');
    assert.equal(c.collisions({...c.defaults,bringMouse:'Ctrl'}).bringMouse.type,'duplicate');
    assert.equal(c.normalize({privacy:"Ctrl');bad()",next:45}).privacy,'Shift');
    assert.equal(c.luaChord('Ctrl+Alt+P'),'CTRL + ALT + P');
    for (const mod of ['Ctrl','Alt','Shift','Super','Ctrl+Shift']) {
        const mask=c.mask(mod);
        assert.equal(c.held(mask,mod),true);
        assert.equal(c.digit({key:16777236,modifiers:mask|0x20000000}),6);
        assert.equal(c.digit({key:16777236,modifiers:mask}),-1);
        assert.equal(c.mouseAction({...c.defaults,moveMouse:mod,bringMouse:'Alt+Shift'},mask),'move');
    }
});

test('switching number modifiers disables old handles and preserves lease expiry', () => {
    execFileSync('lua',['-'],{encoding:'utf8',input:`
local keys, events={},{}
hl={dsp={event=function(v) return v end}}
function hl.dispatch(v) table.insert(events,v) end
function hl.bind(key,callback,flags)
  assert(not keys[key]); local b={enabled=true,callback=callback}
  function b:set_enabled(v) self.enabled=v end
  keys[key]=b; return b
end
function hl.timer(callback,options)
  local t={callback=callback}; function t:set_enabled(v) end; function t:set_timeout(v) end; return t
end
${bindings.install('ctrl:1','CTRL')}
${bindings.install('alt:1','ALT')}
for key,b in pairs(keys) do assert(b.enabled == (key:sub(1,3)=='ALT')) end
${bindings.install('shift:1','SHIFT')}
assert(keys['SHIFT + code:10'].enabled and keys['SHIFT + code:90'].enabled)
${bindings.renew('ctrl:1')}
assert(not keys['CTRL + 1'].enabled)
keys['SHIFT + code:85'].callback(); assert(events[#events]=='windowpeek-shortcut-digit,shift:1,6')
_windowpeek_shortcuts_v1.timer.callback()
for _,b in pairs(keys) do assert(not b.enabled) end
${bindings.install('alt:2','ALT')}
assert(keys['ALT + 1'].enabled)
`});
});
