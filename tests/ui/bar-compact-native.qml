import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import qs.Ui as Ui
import "HostBar" as Host
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: -3
    property int waits: 0
    property int expansionFrames: 0
    property int collapseTicks: 0
    readonly property var widget: hostBar.moduleWidgets("sarr.windowpeek")[0] || null
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var panel: find(widget,"windowPeekController")
    Connections {
        target: test.panel
        function onExpansionChanged() {
            if (test.panel.expansion > 0 && test.panel.expansion < 1) test.expansionFrames++;
        }
    }
    function find(item,name) {
        if(!item) return null;
        if(item.objectName===name) return item;
        for(var child of item.children || []) {var result=find(child,name);if(result) return result;}return null;
    }
    property bool settingsPending: false
    property string settingsError: ""
    function changeSettings(values, after) {
        settingsPending=true;
        widget.persistSettings(values,function(ok) {
            Qt.callLater(function() {
                settingsPending=false;
                if (!ok) settingsError="Fixture settings save failed";
                else if (after) after();
            });
        });
    }
    function check(ok,message) {if(!ok) throw new Error(message);}
    function wait(ok,message) {if(ok){waits=0;return false;}if(++waits>12)throw new Error(message);step--;return true;}
    function click() {check(events.mouseClick(widget,widget.width/2,widget.height/2,Qt.LeftButton,Qt.NoModifier,0),"bar click delivered");}
    Process {
        id: keys; command:[Quickshell.env("WINDOWPEEK_TEST_KEYBOARD"),"None"]
        running:true; stdinEnabled:true
        property bool ready:false
        stdout: SplitParser { onRead:function(line) { if(line==="pressed")keys.ready=true; } }
    }
    Process {
        id: mover
        property string nextCommand: "frame"
        onExited: function(code) { if (code===0) { pointer.write(nextCommand+"\n"); nextCommand="frame"; } }
    }
    Process {
        id: pointer; command:[Quickshell.env("WINDOWPEEK_TEST_POINTER_FRAME"),"--listen"]
        running:true; stdinEnabled:true
        property bool ready:false
        property bool pending:false
        stdout: SplitParser { onRead:function(line) {
            if(line==="ready") pointer.ready=true;
            if(line==="framed" || line==="clicked") pointer.pending=false;
        } }
    }
    QtObject {
        id:shell
        property int styleChanges: 0
        property var config: {
            var layout={left:[],center:[],right:[]};
            layout[Quickshell.env("WINDOWPEEK_TEST_BAR_SECTION") || "center"]=[{id:"sarr.windowpeek",autoUpdates:false,
                windowPreviews:false,openOnHover:false,doubleClickExpand:true,uiScale:test.scale}];
            return {bar:{position:"top",transparent:false,layout:layout}};
        }
        function updateEntryInline(id,entry) { return true; }
        function pluginShellForId(id) { return shell; }
        function mutateShellConfig(change) {
            var next=JSON.parse(JSON.stringify(config));change(next);
            if(next.bar.transparent!==config.bar.transparent)styleChanges++;
            config=next;return true;
        }
    }
    Component { id: widgetFactory; Plugin.Widget {} }
    QtObject {
        id: registry
        property var widgets: ({"sarr.windowpeek":{component:widgetFactory}})
        property int revision: 0
        function metadataFor(id) { return {firstParty:false}; }
    }
    Host.Bar {
        id: hostBar; shell: shell; barConfig: shell.config.bar
        barWidgetRegistry: registry; omarchyPath: "/usr/share/omarchy"
    }
    Item { parent:test.panel ? test.panel.body : null; TestEvent {id:events} }
    Timer {
        interval:250;repeat:true;running:true
        onTriggered: {
            if(!widget || !widget.settingsReady || !test.panel || test.settingsPending) return;
            try {
                test.check(!test.settingsError,test.settingsError);
                switch(test.step++) {
                case -3:
                    if(test.wait(pointer.ready && keys.ready,"virtual input ready"))break;
                    var point=widget.mapToGlobal(widget.width/2,widget.height/2);
                    pointer.pending=true;
                    mover.command=["hyprctl","eval","hl.dispatch(hl.dsp.cursor.move({x="+Math.round(point.x)+",y="+Math.round(point.y)+"}))"];
                    mover.running=true;break;
                case -2:
                    if(test.wait(!pointer.pending,"pointer over real bar surface"))break;
                    pointer.write("double\n");break;
                case -1:
                    test.check(shell.styleChanges===0,"WindowPeek double-click must not toggle the host bar style");
                    if(test.wait(widget.opened && test.panel.body.expanded,"rapid real double-click crosses panel mapping and expands from the bar"))break;
                    widget.close();break;
                case 0: test.click();break;
                case 1:
                    if(test.wait(widget.opened && test.panel.surface.backingWindowVisible,"single click opens production panel"))break;
                    test.check(test.panel.compactPinned && !test.panel.body.expanded,"single click pins compact, including hover-disabled mode");
                    break;
                case 2:
                    test.check(widget.opened && test.panel.compactPinned,"compact remains open without pointer hover");
                    test.expansionFrames=0;
                    test.check(events.mouseDoubleClickSequence(widget,widget.width/2,widget.height/2,Qt.LeftButton,Qt.NoModifier,20),"real Qt double-click sequence delivered");break;
                case 3:
                    if(test.wait(test.panel.body.expanded,"two quick bar clicks expand"))break;
                    test.check(test.expansionFrames>0,"bar double-click renders intermediate expansion frames");
                    test.check(!test.panel.compactPinned,"expanded state clears compact pin");
                    test.expansionFrames=0;
                    pointer.write("double\n");break;
                case 4:
                    test.check(widget.opened && test.panel.compactPinned,"real bar double-click collapses and keeps compact panel pinned");
                    test.check(test.expansionFrames>0,"bar double-click renders intermediate collapse frames");
                    if(++test.collapseTicks<3) { test.step--;break; }
                    keys.write("key Esc\n");break;
                case 5:
                    if(test.wait(!widget.opened,"Escape closes compact"))break;
                    test.click();break;
                case 6:
                    test.check(test.panel.compactPinned,"compact reopens");
                    keys.write("key Esc\n");break;
                case 7:
                    if(test.wait(!widget.opened,"Escape closes compact during the pending double-click sequence"))break;
                    test.click();test.check(test.panel.compactPinned,"reopening after Escape remains compact");break;
                case 8: break;
                case 9: test.click();break;
                case 10:
                    if(test.wait(!widget.opened,"later single click closes panel"))break;
                    test.changeSettings({doubleClickExpand:false},test.click);break;
                case 11:
                    test.check(widget.opened && test.panel.body.expanded,"default single-click behavior is preserved");
                    widget.close();test.changeSettings({doubleClickExpand:true},test.click);break;
                case 12:
                    test.check(test.panel.compactPinned,"compact opens for outside-click dismissal");
                    mover.nextCommand="click";pointer.pending=true;
                    mover.command=["hyprctl","eval","hl.dispatch(hl.dsp.cursor.move({x=1800,y=1040}))"];
                    mover.running=true;break;
                case 13:
                    test.check(!widget.opened,"clicking outside closes pinned compact");
                    var backPoint=widget.mapToGlobal(widget.width/2,widget.height/2);
                    mover.command=["hyprctl","eval","hl.dispatch(hl.dsp.cursor.move({x="+Math.round(backPoint.x)+",y="+Math.round(backPoint.y)+"}))"];
                    mover.running=true;break;
                case 14: test.click();break;
                case 15:
                    if(test.wait(test.panel.compactPinned && test.panel.surface.backingWindowVisible,"fresh compact panel for header double-click"))break;
                    test.check(test.panel.expansion===0,"fresh compact geometry starts collapsed");
                    test.expansionFrames=0;
                    var header=test.find(test.panel.body,"panelHeader");
                    test.check(events.mouseDoubleClickSequence(header,20,10,Qt.LeftButton,Qt.NoModifier,20),"header double-click delivered");break;
                case 16:
                    test.check(test.panel.body.expanded && test.panel.expansion===1,"header double-click finishes expanded");
                    test.check(test.expansionFrames>0,"header double-click renders intermediate expansion frames");
                    test.changeSettings({popupAnimations:false},function(){test.panel.collapse();});break;
                case 17:
                    test.check(test.panel.expansion===0,"disabled collapse is immediate");
                    test.expansionFrames=0;
                    var instantHeader=test.find(test.panel.body,"panelHeader");
                    events.mouseDoubleClickSequence(instantHeader,20,10,Qt.LeftButton,Qt.NoModifier,20);
                    test.check(test.panel.expansion===1 && test.expansionFrames===0,"disabled header expansion remains immediate");
                    widget.close();break;
                case 18:
                    test.check(shell.styleChanges===0,"all widget double-clicks leave the bar style unchanged");
                    var barSurface=widget.QsWindow.window.contentItem;
                    events.mouseDoubleClickSequence(barSurface,barSurface.width/2+300,barSurface.height/2,Qt.LeftButton,Qt.NoModifier,20);break;
                case 19:
                    test.check(shell.styleChanges===1,"double-click on empty bar space still toggles its style");
                    test.changeSettings({openOnHover:true,panelHoverDelay:0});
                    var hoverPoint=widget.mapToGlobal(widget.width+100,widget.height/2);
                    mover.command=["hyprctl","eval","hl.dispatch(hl.dsp.cursor.move({x="+Math.round(hoverPoint.x)+",y="+Math.round(hoverPoint.y)+"}))"];
                    mover.running=true;break;
                case 20:
                    if(test.wait(!test.find(widget,"windowPeekBarButton").tooltipHovered,"cursor leaves the bar label"))break;
                    var returnPoint=widget.mapToGlobal(widget.width/2,widget.height/2);
                    mover.command=["hyprctl","eval","hl.dispatch(hl.dsp.cursor.move({x="+Math.round(returnPoint.x)+",y="+Math.round(returnPoint.y)+"}))"];
                    mover.running=true;break;
                case 21:
                    if(test.wait(widget.hoverOpened,"bar hover still opens the passive compact panel"))break;
                    pointer.write("double\n");break;
                case 22:
                    if(test.wait(widget.opened && test.panel.body.expanded,"bar double-click expands an existing hover panel"))break;
                    test.check(shell.styleChanges===1,"hover promotion does not change bar style");
                    test.changeSettings({hintsMode:"on",pinByTitleClick:false});
                    var header=test.find(test.panel.body,"panelHeader");
                    var headerPoint=header.mapToGlobal(20,10);
                    pointer.pending=true;
                    mover.command=["hyprctl","eval","hl.dispatch(hl.dsp.cursor.move({x="+Math.round(headerPoint.x)+",y="+Math.round(headerPoint.y)+"}))"];
                    mover.running=true;break;
                case 23:
                    if(test.wait(!pointer.pending,"pointer reaches header"))break;
                    pointer.write("double\n");break;
                case 24:
                    test.check(!widget.opened && test.panel.hoverOpened && !test.panel.compactPinned,"disabled pinning makes header double-click collapse passive");
                    var barPoint=widget.mapToGlobal(widget.width/2,widget.height/2);
                    pointer.pending=true;
                    mover.command=["hyprctl","eval","hl.dispatch(hl.dsp.cursor.move({x="+Math.round(barPoint.x)+",y="+Math.round(barPoint.y)+"}))"];
                    mover.running=true;break;
                case 25:
                    var barHint=test.find(test.panel.body,"barLabelHint");
                    if(test.wait(!pointer.pending && barHint.visible,"hovering the real bar label shows its hint"))break;
                    test.check(barHint.text===widget.words.expandPanelHint,"disabled pinning hint promises only expansion");
                    test.check(!test.find(test.panel.body,"backgroundInstructions").visible,"bar hint excludes background hint");
                    var bubble=barHint.contentItem.parent, anchor=barHint.anchorRect;
                    var expectedY=Math.min(anchor.y+anchor.height+3*test.scale,barHint.windowRoot.height-6*test.scale-bubble.height*bubble.scale);
                    test.check(Math.abs(bubble.y-expectedY)<2*test.scale,"bar hint is below the panel");
                    widget.close();test.changeSettings({openOnHover:false});break;
                case 26: pointer.write("click\n");break;
                case 27:
                    test.check(!widget.opened && test.panel.hoverOpened && !test.panel.compactPinned,"real bar click opens passive compact even with hover opening disabled");break;
                case 28: pointer.write("double\n");break;
                case 29:
                    if(test.wait(widget.opened && test.panel.body.expanded,"real bar double-click expands when pinning is disabled"))break;
                    pointer.write("double\n");break;
                case 30:
                    test.check(!widget.opened && test.panel.hoverOpened && !test.panel.compactPinned,"real bar double-click collapses without pinning");
                    pointer.pending=true;
                    mover.command=["hyprctl","eval","hl.dispatch(hl.dsp.cursor.move({x=1800,y=1040}))"];
                    mover.running=true;break;
                case 31:
                    if(test.wait(!pointer.pending && !test.panel.hoverOpened && !test.panel.mapped,"unpinned compact closes after real pointer exit"))break;
                    test.changeSettings({pinByTitleClick:true},test.click);break;
                case 32:
                    test.check(widget.opened && test.panel.compactPinned,"re-enabling pinning restores bar behavior");
                    test.check(test.find(test.panel.body,"barLabelHint").text.indexOf(widget.words.unpinBarHint)===0,"pinned bar hint describes unpin and close");
                    test.changeSettings({pinByTitleClick:false});break;
                case 33:
                    test.check(!widget.opened && !test.panel.compactPinned,"disabling pinning releases an already pinned compact panel");
                    widget.close();test.changeSettings({openOnHover:true,panelHoverDelay:0});
                    var rehover=widget.mapToGlobal(widget.width/2,widget.height/2);
                    pointer.pending=true;
                    mover.command=["hyprctl","eval","hl.dispatch(hl.dsp.cursor.move({x="+Math.round(rehover.x)+",y="+Math.round(rehover.y)+"}))"];
                    mover.running=true;break;
                case 34:
                    if(!keys.running){keys.ready=false;keys.running=true;}
                    if(test.wait(test.panel.hoverOpened && keys.running && keys.ready,"fresh bar hover and virtual keyboard ready"))break;
                    keys.write("key Esc\n");break;
                case 35:
                    test.check(!widget.opened && !test.panel.hoverOpened,"Escape keeps the panel dismissed under a stationary bar cursor");
                    if(++test.collapseTicks<6){test.step--;break;}
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            }catch(error){console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error+" state="+JSON.stringify({opened:widget.opened,hover:test.panel.hoverOpened,pinned:test.panel.compactPinned,expanded:test.panel.body.expanded,barHovered:widget.barLabelHovered}));widget.close();stop();Qt.quit();}
        }
    }
}
