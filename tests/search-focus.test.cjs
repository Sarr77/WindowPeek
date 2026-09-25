const { test } = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const vm = require('node:vm');
const focus = vm.createContext({});
vm.runInContext(fs.readFileSync(require('node:path').join(__dirname, '../SearchFocus.js'), 'utf8'), focus);

test('temporary keyboard focus restores all mouse modes on close or lease expiry', () => {
    for (const original of [0, 1, 2, 3]) {
        execFileSync('lua', ['-'], {input: `
local current=${original}
hl={dsp={event=function(v) return v end},dispatch=function() end}
function hl.get_config(key) assert(key=='input.follow_mouse');return current end
function hl.config(value) assert(value.input.follow_mouse~=nil);current=value.input.follow_mouse end
function hl.timer(callback,options)
 assert(options.timeout==750 and options.type=='repeat')
 local t={callback=callback,enabled=true}
 function t:set_enabled(v) self.enabled=v end
 function t:set_timeout(v) assert(v==750);self.enabled=true end
 return t
end
${focus.install('first:1')}
assert(current==3)
${focus.install('second:2')}
${focus.release('first:1')}
${focus.renew('first:1')}
assert(current==3 and _windowpeek_search_focus_v1.owner=='second:2')
${focus.release('second:2')}
assert(current==${original} and not _windowpeek_search_focus_v1.timer.enabled)
${focus.install('third:3')}
_windowpeek_search_focus_v1.timer.callback()
assert(current==${original} and not _windowpeek_search_focus_v1.owner)
${focus.renew('third:3')}
assert(current==${original},'stale heartbeat must not revive focus after expiry')
${focus.install('fourth:4')}
current=2
${focus.release('fourth:4')}
assert(current==2,'explicit external change wins over saved state')
${focus.install('fifth:5')}
current=0
${focus.install('reload:6', true)}
assert(current==3)
${focus.release('fifth:5')}
${focus.release('reload:6')}
assert(current==0,'config reload becomes the new restore value')
`, encoding: 'utf8'});
    }
});
test('search focus accepts only internal owner tokens', () => {
    for (const value of ['', "');error('bad", 'a,b', '\n', null, 0])
        for (const method of ['install', 'renew', 'release'])
            assert.throws(() => focus[method](value), /Invalid search-focus token/);
});
