import QtQuick
import Quickshell
import Quickshell.Io
import "HostBar" as Host
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int edge: 0
    property int output: 0
    property int step: 0
    property int retries: 0
    property bool finished: false
    readonly property var positions: ["right", "top", "bottom", "left"]
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var widgets: hostBar.moduleWidgets("sarr.windowpeek")
    readonly property var widget: widgets[output] || null
    readonly property var panel: find(widget, "windowPeekController")
    function find(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var result = find(child, name); if (result) return result; }
        return null;
    }
    function check(ok, message) { if (!ok) throw new Error(positions[edge] + "/" + output + ": " + message); }
    function wait(ok, message) {
        if (ok) { retries = 0; return false; }
        if (++retries > 16) throw new Error(message);
        step--; return true;
    }
    function click(item) {
        var point = item.mapToGlobal(item.width / 2, item.height / 2);
        pointer.pending = true;
        mover.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.cursor.move({x=" + Math.round(point.x) + ",y=" + Math.round(point.y) + "}))"];
        mover.running = true;
    }
    function move(x, y) {
        pointer.pending=true; mover.action="frame";
        mover.command=["hyprctl","eval","hl.dispatch(hl.dsp.cursor.move({x="+Math.round(x)+",y="+Math.round(y)+"}))"];
        mover.running=true;
    }
    function moveAway() {
        var screen=panel.surface.screen, side=positions[edge];
        move(screen.x+(side==="left" ? screen.width-20 : 20),
            screen.y+(side==="top" ? screen.height-20 : 20));
    }
    function offer() {
        widget.runtime.updates.startManualCheck = function(force) {};
        widget.runtime.updates.manualResult = {status:"available",version:"9.9.9",commit:"a".repeat(40),
            verification:"verified",lastCheck:Date.now()/1000};
    }
    function checkLabel() {
        var button = find(widget,"windowPeekBarButton"), badge = find(widget,"windowPeekUpdateBadge");
        check(button.visible && badge.visible,"both bar buttons visible");
        if (widget.vertical) {
            check(button.text === "▣\n12", "icon above count on a vertical bar");
            check(badge.y >= button.y + button.height && badge.y + badge.height <= widget.height + .01,
                "update target sits below the window target");
        } else {
            check(button.text === "Saved 12", "saved horizontal label retained");
            check(badge.x >= button.x + button.width, "horizontal targets stay separate");
        }
        var labels = button.nativeLabels;
        check(labels.length > 0,"painted label exists");
        for (var label of labels) {
            var p = label.mapToItem(button,0,0);
            check(p.x >= -.01 && p.x + label.width <= button.width + .01
                && p.y >= -.01 && p.y + label.height <= button.height + .01,"glyphs fit inside bar target: "+JSON.stringify({x:p.x,y:p.y,w:label.width,h:label.height,bw:button.width,bh:button.height,font:button.fontSize,text:button.text,rw:widget.width,barSize:widget.barSize,vertical:widget.vertical,buttonVertical:button.vertical,requested:widget.requestedBarFont}));
        }
    }
    function checkPanel() {
        var surface = panel.surface, card = surface.cardItem, side = positions[edge];
        check(surface.backingWindowVisible && card.opacity > .99, "panel rendered");
        check(card.x >= 0 && card.y >= 0 && card.x + card.width <= surface.screenW
            && card.y + card.height <= surface.screenH,"panel fits monitor");
        var clearance = side === "top" ? card.y : side === "bottom" ? surface.screenH-card.y-card.height
            : side === "left" ? card.x : surface.screenW-card.x-card.width;
        check(Math.abs(clearance-surface.barThickness-surface.gap)<1,"panel clears painted strip");
        var mark = find(widget,"windowPeekActiveUnderline");
        check(mark.visible,"open panel indicator visible");
        if (widget.vertical) check(mark.width < mark.height
            && (side === "left" ? mark.x > widget.width/2 : mark.x < widget.width/2),"indicator faces desktop on vertical edge");
        else check(mark.width > mark.height
            && (side === "top" ? mark.y > widget.height/2 : mark.y < widget.height/2),"indicator faces desktop on horizontal edge");
        var point = marker.mapToGlobal(1,1);
        probe.command = ["python3",Quickshell.env("WINDOWPEEK_TEST_PIXEL_PROBE"),String(Math.round(point.x)),String(Math.round(point.y))];
        probe.running = true;
        var image=Quickshell.env("WINDOWPEEK_TEST_IMAGE");
        if (image && side==="right" && output===widgets.length-1) {
            var screen=surface.screen;
            shot.command=["grim","-s","1","-g",screen.x+","+screen.y+" "+screen.width+"x"+screen.height,image];
            shot.running=true;
        }
    }
    QtObject {
        id: shell
        property var config: ({bar:{position:"top",background:"opaque",layout:{left:[],center:[{
            id:"sarr.windowpeek",autoUpdates:false,checkUpdates:true,windowPreviews:false,openOnHover:false,
            popupAnimations:false,panelStyle:"solid",uiScale:test.scale,barScale:test.scale,hintsMode:"off",
            labelStyle:"custom",customLabels:{barText:"Saved {count}"}}],right:[]}}})
        readonly property var barConfig: config.bar
        function updateEntryInline(id,entry) { return true; }
        function pluginShellForId(id) { return shell; }
    }
    Component { id: factory; Plugin.Widget {} }
    QtObject {
        id: registry
        property var widgets: ({"sarr.windowpeek":{component:factory}})
        property int revision: 0
        function metadataFor(id) { return {firstParty:false}; }
    }
    Host.Bar { id: hostBar; shell:shell; barConfig:shell.config.bar; barWidgetRegistry:registry; omarchyPath:"/usr/share/omarchy" }
    Rectangle {
        id: marker; parent:test.panel ? test.panel.surface.cardItem : null
        x:8; y:8; width:8; height:8; color:"#11ee44"; z:999
    }
    Process {
        id: pointer; command:[Quickshell.env("WINDOWPEEK_TEST_POINTER_FRAME"),"--listen"]
        running:true; stdinEnabled:true
        property bool ready:false
        property bool pending:false
        stdout:SplitParser { onRead:function(line) { if(line==="ready")pointer.ready=true; if(line==="framed" || line==="clicked")pointer.pending=false; } }
    }
    Process {
        id:mover; property string action:"click"
        onExited:function(code) { test.check(code===0,"move in private compositor");pointer.write(action+"\n");action="click"; }
    }
    Process {
        id:keys; command:[Quickshell.env("WINDOWPEEK_TEST_KEYBOARD"),"None"]
        running:true; stdinEnabled:true
        property bool ready:false
        stdout:SplitParser { onRead:function(line) { if(line==="pressed")keys.ready=true; } }
    }
    Process { id:probe; property int result:-1; onExited:function(code) { result=code; } }
    Process { id:shot }
    Timer { id:finish; interval:300; onTriggered:Qt.quit() }
    Timer {
        interval:250;running:true;repeat:true
        onTriggered: {
            if (!widget || !widget.settingsReady || !panel || !pointer.ready || !keys.ready
                || mover.running || pointer.pending || probe.running || shot.running || widget.runtime.preferences.saving) return;
            try {
                switch(test.step++) {
                case 0:
                    for (var item of test.widgets) item.close();
                    var next=JSON.parse(JSON.stringify(shell.config));next.bar.position=test.positions[test.edge];shell.config=next;
                    break;
                case 1:
                    widget.runtime.state.enabled=false;
                    var clients=[];
                    for(var i=0;i<12;i++)clients.push({address:"0x"+(i+1).toString(16),class:"Editor",title:"Project "+(i+1),mapped:true,workspace:{id:1,name:"1"},grouped:[]});
                    widget.runtime.state.snapshot={clients:clients,workspaces:[{id:1,name:"1",monitorID:0,monitor:"WPTEST"}],monitors:[{id:0,name:"WPTEST"}],activeAddress:""};
                    test.offer();break;
                case 2:
                    if(test.wait(widget.bar.position===test.positions[test.edge] && widget.inventory.windows.length===12,"bar and inventory update"))break;
                    test.checkLabel();test.click(test.find(widget,"windowPeekBarButton"));break;
                case 3:
                    if(test.wait(widget.opened,"native click opens the window list"))break;
                    test.checkPanel();break;
                case 4:
                    test.check(probe.result===0,"compositor displays the panel at the expected coordinates");
                    widget.close();break;
                case 5:
                    if(test.wait(!panel.mapped,"list closed before the update action"))break;
                    test.click(test.find(widget,"windowPeekUpdateBadge"));break;
                case 6:
                    if(test.wait(panel.body.installConfirmationOpen,"native update click opens its own prompt"))break;
                    test.check(!test.find(widget,"windowPeekActiveUnderline").visible,"indicator hidden during confirmation");
                    keys.write("key Esc\n");break;
                case 7:
                    if(test.wait(!panel.body.installConfirmationOpen,"Escape dismisses update confirmation"))break;
                    widget.close();
                    test.moveAway();break;
                case 8:
                    widget.persistSettings({openOnHover:true,panelHoverDelay:0});break;
                case 9:
                    var button=test.find(widget,"windowPeekBarButton"),point=button.mapToGlobal(button.width/2,button.height/2);
                    test.move(point.x,point.y);break;
                case 10:
                    if(test.wait(widget.hoverOpened && panel.surface.backingWindowVisible,"native hover opens list"))break;
                    test.check(widget.runtime.preferences.values.customLabels.barText==="Saved {count}","orientation preserved saved text");
                    test.moveAway();break;
                case 11:
                    if(test.wait(!widget.hoverOpened,"leaving the vertical or horizontal label closes hover"))break;
                    widget.persistSettings({openOnHover:false});
                    widget.runtime.updates.manualResult={status:"current"};break;
                case 12:
                    var badge=test.find(widget,"windowPeekUpdateBadge"),main=test.find(widget,"windowPeekBarButton");
                    test.check(!badge.visible,"no update button without an offer");
                    test.check(Math.abs((widget.vertical ? widget.height : widget.width)
                        -(widget.vertical ? main.height : main.width))<.01,"hidden update target leaves no empty slot");
                    console.info("WINDOWPEEK_EDGE_PASS: "+test.positions[test.edge]+" "+widget.screenName);
                    if(++test.output<test.widgets.length){test.step=0;break;}
                    test.output=0;
                    if(++test.edge<test.positions.length){test.step=0;break;}
                    console.info("WINDOWPEEK_TEST_PASS: all bar edges, labels, independent update clicks, indicators and compositor pixels");
                    stop();finish.start();break;
                }
            } catch(error) {
                console.error("WINDOWPEEK_TEST_FAIL: "+error);if(widget)widget.close();stop();finish.start();
            }
        }
    }
}
