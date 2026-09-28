import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "WindowPeek" as Plugin
import "WindowPeek/WindowCommands.js" as Commands

// Actual dispatcher and verification against two private Wayland outputs.
ShellRoot {
    id:test
    property int step:0
    property int waits:0
    property string member:""
    property string peer:""
    property string guardA:""
    property string guardB:""
    property var baseline
    property int completed:0
    property int expectedCompleted:0
    property string failure:""
    property string expectedError:""
    property var stalePlan
    function check(ok,text) { if(!ok)throw new Error(text); }
    function win(address) { return Commands.client(state.snapshot,address); }
    function visibleWorkspaces() { return JSON.stringify(state.snapshot.monitors.map(function(m){return {name:m.name,id:m.activeWorkspace.id};})); }
    function dispatch(code) { setup.command=["hyprctl","eval",code];setup.running=true; }
    function windowRef(address) { return 'hl.get_window("address:'+address+'")'; }
    function setupWindow(address,workspace,monitor) {
        return 'hl.dispatch(hl.dsp.window.move({window="address:'+address+'",workspace='+JSON.stringify(workspace)+',follow=false})); '
            +'hl.dispatch(hl.dsp.workspace.move({workspace='+JSON.stringify(workspace)+',monitor='+JSON.stringify(monitor)+'})); ';
    }
    function move(destination,monitor) { check(actions.move(member,destination,monitor),"action accepted");expectedCompleted++; }
    function moved(destination,monitor) {
        check(!actions.error && completed===expectedCompleted,"action verifies success: "+actions.error);
        check(win(member).workspace.name===destination && win(member).monitor===state.snapshot.monitors.find(function(m){return m.name===monitor;}).id,"window reaches workspace and monitor");
        check(visibleWorkspaces()===baseline.workspaces && state.snapshot.activeAddress===baseline.active,"silent move preserves visible workspaces and keyboard focus");
        check(win(peer).workspace.name==="Origin" && win(guardA).workspace.name==="Origin" && win(guardB).workspace.name==="Destination","other windows stay on their workspaces");
    }
    Window { title:"WP move member";visible:true;width:300;height:200 }
    Window { title:"WP move peer";visible:true;width:300;height:200 }
    Window { title:"WP move guard A";visible:true;width:300;height:200 }
    Window { title:"WP move guard B";visible:true;width:300;height:200 }
    Plugin.WindowState { id:state }
    Plugin.WindowActions { id:actions;state:state;onCompleted:test.completed++ }
    Process {
        id:setup
        stdout:StdioCollector { id:output }
        onExited:function(code) {
            if(test.expectedError) {
                if(output.text.indexOf(test.expectedError)<0)test.failure="missing expected error: "+output.text;
                test.expectedError="";
            } else if(code!==0 || output.text.trim()!=="ok")test.failure="setup: "+output.text;
            state.refresh();
        }
    }
    Timer {
        interval:180;running:true;repeat:true
        onTriggered: {
            try {
                test.check(!test.failure,test.failure);
                if(setup.running || actions.busy || state.busy || !state.ready) {
                    test.check(++test.waits<100,"operation completes");return;
                }
                test.waits=0;
                switch(test.step++) {
                case 0:
                    var titles=["WP move member","WP move peer","WP move guard A","WP move guard B"];
                    var windows=titles.map(function(title){return state.snapshot.clients.find(function(w){return w.title===title;});});
                    if(windows.some(function(w){return !w;})){test.step--;state.refresh();break;}
                    test.check(state.snapshot.monitors.length===2,"two isolated outputs required");
                    test.member=windows[0].address;test.peer=windows[1].address;test.guardA=windows[2].address;test.guardB=windows[3].address;
                    test.dispatch(test.setupWindow(test.member,"name:Origin","WPTEST")+test.setupWindow(test.peer,"name:Origin","WPTEST")
                        +test.setupWindow(test.guardA,"name:Origin","WPTEST")+test.setupWindow(test.guardB,"name:Destination","WPTEST2")
                        +Commands.focus(test.guardB)+"; "+Commands.focus(test.guardA));break;
                case 1:
                    test.baseline={workspaces:test.visibleWorkspaces(),active:state.snapshot.activeAddress};
                    test.check(test.baseline.active===test.guardA,"baseline focus is the untouched window");
                    test.check(!Commands.move(state.snapshot,test.member,"7"),"new workspace cannot dispatch without a monitor");
                    test.move("7","WPTEST2");break;
                case 2:test.moved("7","WPTEST2");test.move("8","WPTEST");break;
                case 3:test.moved("8","WPTEST");test.move("name:Destination");break;
                case 4:
                    test.moved("Destination","WPTEST2");
                    test.check(!Commands.move(state.snapshot,test.member,"name:Origin","WPTEST2"),"existing workspace cannot be pulled to another monitor");
                    test.check(!Commands.move(state.snapshot,test.member,"9","unplugged"),"missing monitor cannot dispatch");
                    test.move("name:Origin");break;
                case 5:
                    test.moved("Origin","WPTEST");
                    test.dispatch('hl.dispatch(hl.dsp.group.toggle({window='+test.windowRef(test.member)+'})); '
                        +test.windowRef(test.member)+'.group:add('+test.windowRef(test.peer)+'); '+Commands.focus(test.guardA));break;
                case 6:
                    test.check(test.win(test.member).grouped.length===2,"group fixture contains both tabs");
                    test.move("9","WPTEST2");break;
                case 7:
                    test.moved("9","WPTEST2");
                    test.check(test.win(test.member).grouped.length<2,"only chosen tab leaves group");
                    actions.bring(test.member,"WPTEST",null);test.expectedCompleted++;break;
                case 8:
                    test.check(!actions.error && test.completed===test.expectedCompleted && test.win(test.member).workspace.name==="Origin"
                        && state.snapshot.activeAddress===test.member,"bring still uses invoking monitor's active workspace and focuses the window");
                    test.move("special:scratchpad");break;
                case 9:
                    test.check(!actions.error && test.completed===test.expectedCompleted && test.win(test.member).workspace.name==="special:scratchpad","Scratchpad remains a direct hide action");
                    test.stalePlan=Commands.move(state.snapshot,test.member,"10","WPTEST2");
                    test.check(!!test.stalePlan,"new destination planned before concurrent creation");
                    test.dispatch(test.setupWindow(test.guardB,"10","WPTEST"));break;
                case 10:
                    test.expectedError="destinationChanged";test.dispatch(test.stalePlan.command);break;
                case 11:
                    test.check(test.win(test.member).workspace.name==="special:scratchpad","stale move leaves source untouched");
                    var ten=state.snapshot.workspaces.find(function(w){return w.name==="10";});
                    test.check(ten && ten.monitor==="WPTEST" && test.win(test.guardB).workspace.name==="10","newly occupied destination and its other window never move to requested monitor");
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();
                }
            }catch(e){console.error("WINDOWPEEK_TEST_FAIL: "+e+" step="+(test.step-1));stop();Qt.quit();}
        }
    }
}
