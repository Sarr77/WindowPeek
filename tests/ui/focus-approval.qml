import QtQuick
import Quickshell
import Quickshell.Io
import "WindowPeek" as Plugin
import "WindowPeek/FocusIncident.js" as Policy

ShellRoot {
    id:test
    property int step:0
    property int waits:0
    property bool observerPathChecked:false
    property bool observerPathValid:false
    function check(ok,text){if(!ok)throw new Error(text);}
    function seed() {
        recovery.pendingApproval=false;recovery.guard=Policy.protection();recovery.revision++;
        recovery.panel=panel;panel.opened=true;recovery.owner="approval:test";
        recovery.session=Policy.session(recovery.owner,Date.now()-2000);
        recovery.session.phase="offered";recovery.session.incident={source:"0x123"};
        recovery.offered={app:"Example App",source:{id:"0x123",address:"0xabc",stableId:"ff",pid:42}};
        recovery.sources=[{id:"0x123",class:"ExampleApp",pid:42,managed:true}];
        recovery.sourcesAt=Date.now()-1000;
        state.snapshot={clients:[{address:"0xabc",stableId:"ff",pid:42,class:"ExampleApp",xwayland:true,
            mapped:true,hidden:false,floating:false,fullscreen:0}]};
    }
    QtObject {
        id:state
        property bool busy:false
        property double observedAt:0
        property var snapshot:null
        signal refreshed(int revision)
        signal failed()
        function refresh(){observedAt=Date.now();refreshed(1);}
    }
    QtObject {
        id:panel
        property bool opened:true
        property bool opening:false
        property var hostWidget:({keepSearchFocus:false})
        property var body:({mode:"windows",expanded:true,busy:false,interacting:false,currentPopup:null,recoveryOpen:true})
        property var destinationMenu:({opened:false})
        property bool childPreviewVisible:false
        property var surface:({nativeActive:true})
    }
    Plugin.FocusRecovery {id:recovery;state:state}
    Process {
        command:["python3","-c","import os,sys; sys.exit(0 if os.path.isfile(sys.argv[1]) else 1)",recovery.observer.command[1]]
        running:true
        onExited:function(code){test.observerPathValid=code===0;test.observerPathChecked=true;}
    }
    Timer {
        interval:100;running:true;repeat:true
        onTriggered:{
            if(!test.observerPathChecked)return;
            try{
                test.check(test.observerPathValid,"observer worker resolves its real file path, including URL-encoded characters");
                switch(test.step++){
                case 0:
                    test.seed();recovery.approve();
                    test.check(recovery.pendingApproval && !recovery.granted && recovery.message==="","fresh client reply waits for independent source sample");break;
                case 1:
                    recovery.sourcesAt=Date.now();recovery.finishApproval();
                    test.check(recovery.granted && recovery.protectionApp==="Example App" && !recovery.pendingApproval,"one click grants after both fresh samples arrive");
                    recovery.stop("user");
                    test.check(!recovery.granted && recovery.offeringStopped,"Turn off retains a manual re-enable choice");
                    recovery.approve();break;
                case 2:
                    recovery.sourcesAt=Date.now();recovery.finishApproval();
                    test.check(recovery.granted && !recovery.offeringStopped,"fresh approval can re-enable the same reviewed source");
                    test.seed();recovery.approve();
                    state.observedAt=Date.now()-700;recovery.sourcesAt=Date.now();recovery.finishApproval();
                    test.check(recovery.granted,"late source sample refreshes stale compositor inventory before granting");
                    test.seed();recovery.approve();break;
                case 3:
                    state.snapshot.clients[0].stableId="ee";recovery.sourcesAt=Date.now();recovery.finishApproval();
                    test.check(!recovery.granted && !recovery.pendingApproval && recovery.message===recovery.copy.changed,"changed identity is still rejected");
                    test.seed();recovery.approve();recovery.decline();break;
                case 4:
                    recovery.sourcesAt=Date.now();recovery.finishApproval();
                    test.check(!recovery.granted && !recovery.pendingApproval,"cancel cannot grant later when refresh completes");
                    test.seed();recovery.approve();panel.opened=false;recovery.sourcesAt=Date.now();recovery.finishApproval();
                    test.check(!recovery.granted && !recovery.pendingApproval,"closing cancels pending approval");
                    test.seed();recovery.approve();test.waits=0;break;
                case 5:
                    if(recovery.pendingApproval && ++test.waits<35){test.step--;break;}
                    test.check(!recovery.pendingApproval && !recovery.granted && recovery.message===recovery.copy.changed,"missing observer times out safely without granting");
                    test.seed();recovery.approve();break;
                case 6:
                    recovery.sourcesAt=Date.now();recovery.finishApproval();recovery.stop("user");
                    test.check(recovery.offeringStopped,"stopped offer is available while source lives");
                    state.snapshot={clients:[]};state.refresh();
                    test.check(!recovery.offered && !recovery.stoppedOffer && !recovery.granted,"source closure removes manual re-enable choice");
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            }catch(e){console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+e);stop();Qt.quit();}
        }
    }
}
