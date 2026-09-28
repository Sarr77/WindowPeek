const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const crypto = require('node:crypto');
const vm = require('node:vm');
const root = require('node:path').join(__dirname,'..');
function load(file) { const c=vm.createContext({});vm.runInContext(fs.readFileSync(root+'/'+file,'utf8'),c);return c; }
const catalog=load('LogoCatalog.js'), settings=load('Settings.js');
test('random selection draws only bundled GIFs, excluding the previous choice',()=>{
  assert.equal(settings.logoChoice(catalog.randomChoice),catalog.randomChoice);
  assert.ok(catalog.animated(catalog.randomChoice));
  for(const previous of ['',...catalog.effects.map(([id])=>'builtin:ttfx-'+id)]) {
    const count=catalog.effects.length-(previous ? 1 : 0), results=new Set();
    for(let i=0;i<count;i++) {
      const source=catalog.randomSource(previous,(i+0.5)/count);
      assert.ok(catalog.effect(source));assert.notEqual(source,previous);results.add(source);
    }
    assert.equal(results.size,count,'every eligible GIF is reachable exactly once');
  }
  assert.equal(catalog.label(catalog.randomChoice,{}, {randomGif:'Losowy GIF'}),'Losowy GIF');
  assert.notEqual(catalog.randomChoice,'builtin:ttfx-randomsequence');
});
test('fresh-install defaults match the complete artwork reset for both views',()=>{
  const defaults=JSON.parse(fs.readFileSync(root+'/manifest.json','utf8')).barWidget.defaults;
  for(const target of ['hover','settings']) {
    const preset=catalog.artworkDefaults(target);
    for(const key of Object.keys(preset)) {
      const value=key.endsWith('Layout') ? catalog.layout(defaults[key]) : defaults[key];
      assert.equal(JSON.stringify(value),JSON.stringify(preset[key]),key);
    }
    const a=catalog.artworkDefaults(target);a[target+'LogoLayout'].zoom=200;
    assert.equal(catalog.artworkDefaults(target)[target+'LogoLayout'].zoom,100);
  }
});
test('GIF defaults follow source changes without overwriting explicit opacity',()=>{
  for(const source of [catalog.randomChoice,...catalog.effects.map(([id])=>'builtin:ttfx-'+id),'file:///custom%20picture.GIF']) {
    assert.equal(catalog.defaultOpacity(source),50);
    for(const value of [undefined,null,'50',NaN]) assert.equal(catalog.opacity(value,source),50);
    for(const value of [0,32,50,100]) assert.equal(catalog.opacity(value,source),value);
  }
  for(const source of ['', 'builtin:omarchy-pixel','file:///picture.png','file:///picture.svg']) {
    assert.equal(catalog.opacity(null,source),100);
    assert.equal(catalog.opacity(32,source),32);
  }
  assert.equal(catalog.opacitySetting(undefined),null);
  assert.equal(catalog.opacitySetting(null),null);
  assert.equal(catalog.opacitySetting(0),0);
});
// Read actual GIF blocks, never search compressed image bytes for magic values.
function gifDisposals(data) {
  assert.match(data.toString('ascii',0,6),/^GIF8[79]a$/);
  let offset=13+(data[10]&128 ? 3*(1<<((data[10]&7)+1)) : 0), disposal=null;
  const frames=[];
  function blocks() {
    while(offset<data.length) {const size=data[offset++];if(!size)return;offset+=size;}
    assert.fail('unterminated GIF block');
  }
  while(offset<data.length) {
    const marker=data[offset++];
    if(marker===0x3b)return frames;
    if(marker===0x21) {
      const label=data[offset++];
      if(label===0xf9) {assert.equal(data[offset],4);disposal=(data[offset+1]>>2)&7;}
      blocks();
    } else if(marker===0x2c) {
      const packed=data[offset+8];offset+=9;
      if(packed&128)offset+=3*(1<<((packed&7)+1));
      offset++;blocks();frames.push(disposal);disposal=null;
    } else assert.fail('unexpected GIF marker '+marker);
  }
  assert.fail('missing GIF trailer');
}
test('every catalog choice normalizes and has local animation and poster',()=>{
  assert.equal(catalog.effects.length,37);
  const provenance=JSON.parse(fs.readFileSync(root+'/vendor/ttfx/sources.json','utf8'));
  assert.equal(Object.keys(provenance.files).length,catalog.effects.length);
  for(const [id] of catalog.effects) {
    const key='builtin:ttfx-'+id;
    assert.equal(crypto.createHash('sha256').update(fs.readFileSync(root+'/vendor/ttfx/'+id+'.gif')).digest('hex'),provenance.files[id].sha256);
    const disposals=gifDisposals(fs.readFileSync(root+'/vendor/ttfx/'+id+'.gif'));
    assert.ok(disposals.length>1);
    assert.ok(disposals.every(d=>d===2),id+' must clear all transparent frames, without old character trails');
    assert.equal(settings.logoChoice(key),key);assert.equal(catalog.effect(key),id);
    for(const ext of ['gif','png']) assert.ok(fs.statSync(root+'/vendor/ttfx/'+id+'.'+ext).size>0);
  }
  for(const key of ['builtin:ttfx-../../etc/passwd','builtin:ttfx-toString','https://example.com/test.gif','builtin:ttfx-unknown']) {
    assert.equal(settings.logoChoice(key),'');assert.equal(catalog.effect(key),'');
  }
  assert.equal(settings.logoChoice('builtin:omarchy-pixel'),'builtin:omarchy-pixel');
  assert.equal(settings.logoChoice('file:///custom%20picture.gif'),'file:///custom%20picture.gif');
});
test('layout bounds reject malformed saved values, retain independent axes',()=>{
  assert.equal(catalog.opacity(undefined),100);assert.equal(catalog.opacity('25'),100);
  assert.equal(catalog.opacity(-10),0);assert.equal(catalog.opacity(140),100);assert.equal(catalog.opacity(42),42);
  const v=catalog.layout({zoom:1e9,width:Infinity,height:36,x:-400,y:NaN});
  assert.equal(v.zoom,catalog.layoutScaleMax);assert.equal(v.width,100);assert.equal(v.height,36);assert.equal(v.x,-100);assert.equal(v.y,0);
  assert.equal(catalog.layout({zoom:24.5,width:12.5,height:0}).zoom,24.5);
  assert.equal(catalog.layout({height:0}).height,catalog.layoutScaleMin);
  assert.equal(catalog.motion('unknown'),'none');
  for (const id of ['pixels','scatter','wipe','blinds','iris','dissolve']) assert.equal(catalog.reveal(id),id);
  for (const value of ['unknown','../../file',null,{},3]) assert.equal(catalog.reveal(value),'none');
});
test('recent files are bounded, unique and local',()=>{
  const files=Array.from({length:30},(_,i)=>'file:///image'+i+'.png');
  assert.equal(catalog.recent(files).length,12);
  assert.equal(catalog.remember(files,files[4])[0],files[4]);
  assert.equal(catalog.remember(files,'https://example.com/x.gif').length,12);
  assert.equal(catalog.recent(['file:///a','file:///a']).length,1);
});
