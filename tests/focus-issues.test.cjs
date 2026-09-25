const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const p = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname,'../FocusIssues.js'),'utf8'),p);
const client = {xwayland:true, class:'Dynamic',initialClass:'FictionalApp',app:'Fictional App',title:'PRIVATE QUERY',pid:45,address:'0x123'};
test('history keeps only application identity and evidence metadata across windows',()=>{
 let d=p.record(p.empty(),client,1000);
 d=p.record(d,{...client,pid:90,address:'0x456',class:'OtherDynamic'},2000);
 assert.equal(d.apps.length,1);assert.equal(d.apps[0].incidents,2);
 assert.equal(d.apps[0].klass,'FictionalApp');assert.equal(d.apps[0].firstSeen,1000);
 assert.ok(!JSON.stringify(d).includes('PRIVATE'));assert.ok(!JSON.stringify(d).includes('pid'));
 assert.equal(p.record(d,{...client,xwayland:false},3000).apps[0].incidents,2);
});
test('session choices survive a bar reload but expire for a different desktop session',()=>{
 let d=p.choose(p.empty(),'session',true,'compositor-a');
 d=p.normalize(JSON.parse(JSON.stringify(d)));
 assert.equal(p.muted(d,'compositor-a',''),true);
 assert.equal(p.muted(d,'compositor-b',''),false);
 assert.equal(p.muted(p.choose(d,'session',false,'compositor-a'),'compositor-a',''),false);
});
test('app ignore follows class, does not mute unknown or other apps, and can be restored',()=>{
 let d=p.record(p.empty(),client,1000),k=d.apps[0].key;
 d=p.choose(d,'app',true,'session',k);
 d=p.record(d,{...client,pid:91,address:'0x999'},2000);
 assert.equal(p.muted(d,'another-session',k),true);
 assert.equal(p.muted(d,'session',p.appKey('Unrelated')),false);
 assert.equal(p.muted(d,'session',''),false);
 d=p.choose(d,'app',false,'session',k);
 assert.equal(p.muted(d,'session',k),false);
 assert.equal(d.apps[0].incidents,2);
});
test('global ignore is independent of app/session overrides and grants no protection',()=>{
 let d=p.record(p.empty(),client,1000),k=d.apps[0].key;
 d=p.choose(d,'app',true,'s',k);d=p.choose(d,'all',true,'s');
 assert.equal(p.muted(d,'new','unknown'),true);
 d=p.choose(d,'all',false,'new');
 assert.equal(p.muted(d,'new',k),true);assert.equal(p.muted(d,'new',''),false);
 assert.equal(d.grant,undefined);
});
test('history is bounded without discarding existing ignored applications',()=>{
 let d=p.empty();
 for(let i=0;i<256;i++){d=p.record(d,{xwayland:true,class:'App'+i},1000+i);d=p.choose(d,'app',true,'s',d.apps[i].key);}
 let full=p.record(d,{xwayland:true,class:'Overflow'},5000);
 assert.equal(full.apps.length,256);assert.ok(full.apps.every(a=>a.ignored));
 d=p.choose(d,'app',false,'s',d.apps[0].key);
 full=p.record(d,{xwayland:true,class:'Overflow'},5000);
 assert.equal(full.apps.length,256);assert.ok(full.apps.some(a=>a.klass==='Overflow'));
 assert.ok(!full.apps.some(a=>a.klass==='App0'));
});
test('corrupt or forged identities cannot silently become ignore entries',()=>{
 assert.throws(()=>p.normalize({version:2,apps:[]}));
 const d=p.normalize({version:1,apps:[{key:'x11:Other',klass:'App',ignored:true}]});
 assert.equal(d.apps.length,0);assert.equal(p.muted(d,'s','x11:Other'),false);
});
