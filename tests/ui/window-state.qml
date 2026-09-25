import QtQuick
import Quickshell
import "WindowPeek" as Plugin
ShellRoot {
    id:test
    property int changes:0
    Plugin.WindowState { id:state; enabled:false; onInventoryChanged:test.changes++ }
    function check(ok,message) {if(!ok)throw new Error(message);}
    Timer {
        interval:50;running:true
        onTriggered: {
            try {
                var raw=[[{address:"0x1",stableId:"first",pid:100,class:"Example",title:"Document",workspace:{id:1,name:"1"},at:[0,0],size:[100,100]}],
                    [{id:1,name:"1",monitor:"TEST-A",monitorID:0}],[{id:0,name:"TEST-A"}],{address:"0x1"}];
                function receive() {state.receive(0,raw.map(JSON.stringify).join("\n\n\n"));}
                receive();var inventory=state.inventory, revision=state.revision, changes=test.changes;
                raw[0][0].size=[200,200];raw[0][0].stableId="second";receive();
                test.check(state.snapshot.clients[0].stableId==="second" && state.snapshot.clients[0].size[0]===200,"focus diagnostics receive fresh identities and geometry");
                test.check(state.revision===revision+1 && state.observedAt>0,"freshness remains observable");
                test.check(state.inventory===inventory && test.changes===changes,"unchanged list retains its identity");
                raw[0][0].title="Changed";receive();
                test.check(state.inventory!==inventory && state.inventory.windows[0].title==="Changed","title change reaches search");
                raw[1][0].name="Renamed";receive();
                test.check(state.inventory.windows[0].workspace.name==="Renamed","workspace metadata stays fresh");
                raw[3].address="";receive();
                test.check(!state.inventory.windows[0].active,"active marker updates");
                state.receive(1,"");
                test.check(state.inventory.status==="unavailable" && !state.ready,"failure clears stale results");
                receive();test.check(state.ready && state.inventory.windows.length===1,"recovery restores results");
                console.info("WINDOWPEEK_TEST_PASS");Qt.quit();
            }catch(e){console.error("WINDOWPEEK_TEST_FAIL: "+e);Qt.quit();}
        }
    }
}
