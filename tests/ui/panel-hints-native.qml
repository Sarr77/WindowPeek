import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "HostBar" as Host
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

// Use the production layer surface: a plain Window does not reproduce its
// content-item ownership and transforms. Run in a private compositor.
ShellRoot {
    id: test
    property int step: -2
    property int waits: 0
    readonly property var widget: hostBar.moduleWidgets("sarr.windowpeek")[0] || null
    readonly property var panel: find(widget,"windowPeekController")
    property real previousY: 0
    property var afterCapture: null
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var body: panel ? panel.body : null
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    function hover(item, x, y) {
        check(events.mouseMove(item, x, y, 0, Qt.NoButton, Qt.NoModifier), "hover delivered");
    }
    function afterScreenshot(action) {
        if (capture.running) afterCapture = action; else action();
    }
    function verifyBottom(hint, name) {
        check(hint.visible, name + " is visible");
        var bubble = hint.contentItem.parent;
        var window = body.Window.window.contentItem;
        var box = bubble.mapToItem(window, 0, 0, bubble.width, bubble.height);
        var card = panel.surface.cardItem;
        var panelBox = card.mapToItem(window, 0, 0, card.width, card.height);
        console.log("HINT_GEOMETRY", name, JSON.stringify({hint:box, panel:panelBox,
            windowWidth:window.width, windowHeight:window.height, anchor:hint.anchorRect}));
        var expected = Math.min(panelBox.y + panelBox.height + 3 * test.scale,
            window.height - 6 * test.scale - box.height);
        check(Math.abs(box.y - expected) <= 2 * test.scale,
            name + " stays at panel bottom: expected " + expected + ", got " + box.y);
        check(box.x >= 0 && box.x + box.width <= window.width
            && box.y >= 0 && box.y + box.height <= window.height, name + " fits the screen");
        previousY = box.y;
        var imagePath = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
        if (imagePath) { capture.command = ["grim", "-o", "WPTEST", imagePath + "." + name + ".png"]; capture.running = true; }
    }
    FakeHost {
        id: host; bar: test.widget ? test.widget.bar : null
        windowPreview: thumbnail
        settings: ({hintsMode:"on", doubleClickExpand:true, windowPreviews:false})
        Component.onCompleted: savedAppearance = Appearance.normalize({uiScale:test.scale})
    }
    Plugin.WindowThumbnail { id: thumbnail; hostWidget:host; shortcutTarget:test.body ? test.body.previewKeyTarget : null }
    Process {
        id: capture
        onExited: function(code) {
            if (code !== 0) console.error("WINDOWPEEK_TEST_FAIL: screenshot failed");
            var action = test.afterCapture; test.afterCapture = null;
            if (action) action();
        }
    }
    QtObject {
        id:shell
        property var config: ({bar:{position:"top",transparent:false,layout:{left:[{
            id:"sarr.windowpeek",autoUpdates:false,windowPreviews:false,openOnHover:false,
            doubleClickExpand:true,uiScale:test.scale}],center:[],right:[]}}})
        function updateEntryInline(id,entry) { return true; }
        function pluginShellForId(id) { return shell; }
    }
    Component { id: widgetFactory; Plugin.Widget {} }
    QtObject {
        id: registry
        property var widgets: ({"sarr.windowpeek":{component:widgetFactory}})
        property int revision: 0
        function metadataFor(id) { return {firstParty:false}; }
    }
    Host.Bar {
        id: hostBar; shell:shell; barConfig:shell.config.bar
        barWidgetRegistry:registry; omarchyPath:"/usr/share/omarchy"
    }
    Item { parent:test.body; TestEvent { id: events } }
    Timer {
        interval:600; running:true; repeat:true
        onTriggered: {
            if (capture.running || test.afterCapture) return;
            try {
                var background = test.find(test.body,"backgroundInstructions");
                var logo = test.find(test.body,"hoverOmarchyLogo");
                switch(test.step++) {
                case -2:
                    if (!test.widget || !test.widget.settingsReady) {
                        test.check(++test.waits < 10,"widget loads"); test.step--; break;
                    }
                    test.widget.open(); break;
                case -1:
                    test.check(!!panel,"production Widget loads its panel");
                    panel.hostWidget = host; break;
                case 0: panel.open(); break;
                case 1: test.hover(test.body,2,2); break;
                case 2:
                    test.verifyBottom(background,"expanded");
                    test.check(background.text===host.words.collapsePanelHint,"expanded background explains only its collapse action");
                    test.afterScreenshot(function() { test.hover(test.body,12,6); }); break;
                case 3:
                    test.check(background.contentItem.parent.y === test.previousY,"background hint does not follow cursor");
                    panel.collapse(); break;
                case 4: test.hover(test.body,2,2); break;
                case 5:
                    test.verifyBottom(background,"compact");
                    test.check(background.text===host.words.expandPanelHint,"compact background explains only its expansion action");
                    test.afterScreenshot(function() { test.hover(logo,logo.width/2,logo.height/2); }); break;
                case 6:
                    test.check(!background.visible,"logo excludes background instructions");
                    test.verifyBottom(test.find(logo,"logoHint"),"logo");
                    test.afterScreenshot(function() { panel.open(); test.body.mode="settings"; }); break;
                case 7:
                    var settingsLogo=test.find(test.body,"settingsOmarchyLogo");
                    // On a 1080px output at 200%, the collapsed Settings sections
                    // cover the decoration completely. A hidden logo has no hint.
                    if (!settingsLogo.visible) {
                        test.check(settingsLogo.y + settingsLogo.height <= 0
                            && !test.find(settingsLogo,"logoHint").visible,"clipped Settings logo has no hint");
                        test.step=9; host.persistSettings({hintsMode:"off"}); break;
                    }
                    test.hover(settingsLogo,settingsLogo.width/2,settingsLogo.height/2); break;
                case 8:
                    test.verifyBottom(test.find(test.find(test.body,"settingsOmarchyLogo"),"logoHint"),"settings-logo");
                    test.afterScreenshot(function() { host.persistSettings({hintsMode:"off"}); }); break;
                case 9:
                    test.check(!test.find(test.find(test.body,"settingsOmarchyLogo"),"logoHint").visible,"hints off hides logo hint");
                    var help = test.find(test.body,"hintsToggle");
                    test.hover(help,help.width/2,help.height/2); break;
                case 10:
                    var helpControl = test.find(test.body,"hintsToggle");
                    var controlHint = helpControl.children.find(function(item) { return "alwaysAvailable" in item; });
                    test.check(controlHint && controlHint.visible,"control hint survives the backing-window transfer");
                    test.verifyBottom(controlHint,"help-control");
                    panel.close(); host.persistSettings({hintsMode:"on"}); panel.hoverRequested=true; break;
                case 11: test.hover(test.body,2,2); break;
                case 12:
                    test.check(panel.hoverOpened && !panel.opened,"passive hover panel is open");
                    test.verifyBottom(background,"passive");
                    test.afterScreenshot(function() { test.hover(logo,logo.width/2,logo.height/2); }); break;
                case 13:
                    test.verifyBottom(test.find(logo,"logoHint"),"passive-logo");
                    test.afterScreenshot(function() {
                        var row=test.find(test.body,"windowFocusPointer");
                        test.hover(row,row.width/2,row.height/2);
                    });test.step=21;break;
                case 21:
                    var passiveRow=test.find(test.body,"windowFocusHint");
                    test.check(passiveRow.visible && !background.visible && !test.find(logo,"logoHint").visible,"hovering a compact row shows only that row's hint");
                    test.check(passiveRow.text===host.words.focusHint+"\n"+host.words.chooseMoveHint+"\n"+host.words.bringHint,"compact row describes its own actions");
                    test.verifyBottom(passiveRow,"passive-row");
                    test.afterScreenshot(function() { host.persistSettings({shortcuts:{moveMouse:"Alt",bringMouse:"Alt+Shift"}}); });break;
                case 22:
                    test.check(test.find(test.body,"windowFocusHint").text.indexOf("Alt + click")>=0,"hover row help follows customized controls");
                    panel.open(false,true);break;
                case 23:
                    test.check(panel.compactPinned,"compact remains available when pinned");
                    var pinnedRow=test.find(test.body,"windowFocusPointer");
                    test.hover(pinnedRow,pinnedRow.width/2,pinnedRow.height/2);break;
                case 24:
                    test.check(test.find(test.body,"windowFocusHint").visible && !background.visible,"pinned compact row keeps contextual help");
                    host.persistSettings({shortcuts:{}});test.step=14;break;
                case 14:
                    panel.hoverRequested=false; panel.dismissHover();
                    panel.open(); break;
                case 15:
                    host.persistSettings({hintsMode:"auto",hintsUsed:0,windowPreviews:true,previewHoverDelay:0});
                    var rowPointer=test.find(test.body,"windowFocusPointer");
                    test.hover(rowPointer,rowPointer.width/2,rowPointer.height/2);
                    // Passive observers can leave the underlying panel hovered
                    // as well. Specific controls must win regardless of that flag.
                    test.body.outerBackgroundHovered=true; break;
                case 16:
                    test.check(test.find(test.body,"windowFocusHint").visible,"row hint is visible");
                    test.check(thumbnail.visible,"window preview remains visible with its row hint");
                    test.check(!background.visible && !background.requested,"row excludes general instructions");
                    test.check(host.hints.used===1,"only the row hint consumes the automatic budget");
                    test.check(test.find(test.body,"windowFocusHint").statusText.indexOf(host.words.hintsDisableExpanded)>=0,"auto row footer names the expanded panel's ? button");
                    test.verifyBottom(test.find(test.body,"windowFocusHint"),"row-exclusive");
                    var rowTip=test.find(test.body,"windowFocusHint").contentItem.parent;
                    var previewX=thumbnail.screenOrigin.x-panel.surface.screen.x;
                    test.check(rowTip.x+rowTip.width*rowTip.scale<=previewX
                        || rowTip.x>=previewX+thumbnail.width,"row hint does not cover the window preview");
                    var movePointer=test.find(test.body,"windowMovePointer");
                    test.afterScreenshot(function() { test.hover(movePointer,movePointer.width/2,movePointer.height/2); }); break;
                case 17:
                    test.check(test.find(test.body,"windowMoveHint").visible && !test.find(test.body,"windowFocusHint").visible
                        && !background.visible,"Move has the only visible hint");
                    test.check(host.hints.used===2,"Move consumes exactly one display");
                    var update=test.find(test.body,"updateSwitch");
                    test.hover(update,update.width/2,update.height/2); break;
                case 18:
                    var updateControl=test.find(test.body,"updateSwitch");
                    var updateHint=updateControl.children.find(function(item) { return "alwaysAvailable" in item; });
                    test.check(updateHint.visible && !background.visible,"update switch excludes general instructions");
                    test.verifyBottom(updateHint,"update-control");
                    test.check(host.hints.used===3,"update help consumes exactly one display");
                    var helpButton=test.find(test.body,"hintsToggle");
                    test.hover(helpButton,helpButton.width/2,helpButton.height/2); break;
                case 19:
                    test.check(!background.visible && host.hints.used===3,"help switch excludes general instructions and stays budget-free");
                    test.body.outerBackgroundHovered=Qt.binding(function() { return !!test.panel && test.panel.surface.backgroundHovered; });
                    test.hover(test.body,2,2); break;
                case 20:
                    test.check(background.visible && host.hints.used===4,"returning to empty space restores only general instructions");
                    test.body.outerBackgroundHovered=true;
                    test.hover(test.body.Window.window.contentItem,1800,1040);
                    test.step=25;break;
                case 25:
                    test.check(!background.visible && !test.body.pointerInsidePanel && host.hints.used===4,
                        "leaving the panel suppresses stale background hover without consuming hints");
                    host.persistSettings({doubleClickExpand:false});
                    test.check(background.text===host.words.collapsePanelClickHint,"single-click mode has its actual background gesture");
                    host.persistSettings({openOnHover:false});
                    test.check(!background.visible,"no collapse hint when compact mode is unavailable");
                    panel.close();
                    console.log("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit(); break;
                }
            } catch(error) {
                console.error("WINDOWPEEK_TEST_FAIL step " + (test.step-1) + ": " + error);
                stop(); if (panel) panel.close(); Qt.quit();
            }
        }
    }
}
