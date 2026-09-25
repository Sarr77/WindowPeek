const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const r = vm.createContext({});
vm.runInContext(fs.readFileSync('TextReadability.js', 'utf8'), r);
const c = (v, a=1) => ({r:v,g:v,b:v,a});
const host = {textShadowMode:'auto',panelStyle:'wallpaper',wallpaperTransparency:90,
    glassTransparency:90,surfaces:{panel:c(.08),wallpaperBrightness:0},textShadowSamples:[[240,240,240]]};
test('Auto reacts to wallpaper contrast, text alpha, tint and opaque row backing', () => {
    assert.equal(r.needed(host,c(.8)),true);
    assert.equal(r.needed({...host,textShadowSamples:[[10,10,10]]},c(.8)),false);
    assert.equal(r.needed({...host,wallpaperTransparency:0},c(.8)),false);
    assert.equal(r.needed(host,c(.8),c(.05)),false);
    assert.equal(r.needed(host,c(.1)),false);
    assert.equal(r.needed(host,c(.1,.25)),true);
});
test('Auto handles transparent content conservatively and leaves solid panels alone', () => {
    assert.equal(r.needed({...host,panelStyle:'glass'},c(.8)),true);
    assert.equal(r.needed({...host,panelStyle:'glass',glassTransparency:0},c(.8)),false);
    assert.equal(r.needed({...host,panelStyle:'solid'},c(.08)),false);
});
test('Explicit choice wins over the contrast estimate and invalid preferences use Auto', () => {
    assert.equal(r.needed({...host,textShadowMode:'off'},c(.8)),false);
    assert.equal(r.needed({...host,textShadowMode:'on',panelStyle:'solid'},c(.8)),true);
    assert.equal(r.needed({...host,textShadowMode:'invalid'},c(.8)),true);
    assert.equal(r.needed(null,c(.8)),false);
});

test('low-contrast small glyphs get a solid foreground, rather than a pale outline around faint ink', () => {
    const green={r:80/255,g:148/255,b:117/255,a:1};
    const theme={r:193/255,g:196/255,b:151/255,a:1};
    const foliage={...host,wallpaperTransparency:100,textShadowSamples:[[66,141,114]]};
    const chosen=r.ink(foliage,green,theme);
    assert.equal(chosen.a,1);
    assert.ok(r.score(foliage,chosen)>r.score(foliage,green)*1.5);
    const faded={...theme,a:.45};
    assert.equal(r.ink(foliage,faded,theme).a,1);
    assert.equal(r.ink({...foliage,textShadowMode:'off'},faded,theme),faded);
    assert.equal(r.ink({...foliage,panelStyle:'solid'},faded,theme),faded);
    assert.equal(green.r,80/255,'saved source color is untouched');
});
test('readable accent roles keep their color and corrections stay in the theme palette', () => {
    const blue={r:0,g:.2,b:.6,a:1};
    assert.equal(r.ink(host,blue,c(.9)),blue);
    const chosen=r.ink({...host,wallpaperTransparency:100},c(.55),c(.1));
    assert.equal(chosen.r,.1);
});

test('async Python worker matches rendering policy across themes, alpha, backing and modes', () => {
    const {spawnSync} = require('node:child_process');
    let seed=1234567;
    const random=()=>{ seed=(1664525*seed+1013904223)>>>0;return seed/4294967296; };
    const color=()=>({r:random(),g:random(),b:random(),a:random()});
    for(const panelStyle of ['wallpaper','glass','solid']) {
        for(const textShadowMode of ['auto','on','off']) {
            const context={...host,panelStyle,textShadowMode,wallpaperTransparency:random()*100,
                glassTransparency:random()*100,surfaces:{panel:color(),wallpaperBrightness:random()-.5},
                textShadowSamples:Array.from({length:64},()=>[random()*255,random()*255,random()*255])};
            const jobs=Array.from({length:64},(_,i)=>({key:String(i),color:color(),theme:color(),backing:color()}));
            const child=spawnSync('python3',['-I','-B','wallpaper_contrast.py',JSON.stringify({mode:'text-readability',epoch:17,context,jobs})],{encoding:'utf8'});
            assert.equal(child.status,0,child.stderr);
            const answer=JSON.parse(child.stdout);assert.equal(answer.epoch,17);
            for(const job of jobs) {
                const got=answer.results[job.key];
                assert.equal(got.active,r.needed(context,job.color,job.backing));
                assert.deepEqual(got.ink,JSON.parse(JSON.stringify(r.ink(context,job.color,job.theme,job.backing))));
            }
        }
    }
});
