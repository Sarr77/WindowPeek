import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin
import "WindowPeek/FocusRecoveryText.js" as Texts

ShellRoot {
    id: test
    property int step: 0
    property real startingScroll: 0
    property alias panelContent: panel
    readonly property bool compactCase: Quickshell.env("WINDOWPEEK_TEST_STYLE") === "compact"
    readonly property real availableHeight: Math.min(740,960/scale)
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok,message) { if(!ok) throw new Error(message); }
    function find(item,name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var r=find(child,name); if(r)return r; }
        return null;
    }
    function click(name) { var item=find(panel,name); check(!!item,name); panel.ensureVisible(item); events.mouseClick(item,item.width/2,item.height/2,Qt.LeftButton,Qt.NoModifier,0); }
    function capture(label) {
        var path=Quickshell.env("WINDOWPEEK_TEST_IMAGE");
        if(path) window.contentItem.grabToImage(function(image) {image.saveToFile(path.replace(/\.png$/, "-"+label+".png"));});
    }
    TestEvent { id: events }
    TestCase { id: pixels; name:"FocusExplanation"; when:false }
    QtObject {
        id: preview
        property bool visible: false
        property int dismissCount: 0
        function dismiss() {visible=false;dismissCount++;}
        function hideFor(item) {}
        function showFor(item,address,bounds) {}
    }
    FakeHost {
        id: host; settings: ({hintsMode:"off"}); windowPreview:preview
        Component.onCompleted: {
            var data=JSON.parse(JSON.stringify(snapshot));
            for(var i=10;i<30;i++)data.clients.push({address:"0x"+i.toString(16),class:"example",app:"Example",title:"Fictional document "+i,workspace:{id:1,name:"1"}});
            snapshot=data;
        }
    }
    QtObject {
        id: recovery
        property var panel: ({body:test.panelContent})
        property bool granted: false
        property bool backendAvailable: true
        property bool sessionProtection: false
        property string protectionApp: ""
        property bool manualRequested: false
        readonly property bool manualEnabled: host.keepSearchFocus
        property bool interrupted: true
        property bool suggested: false
        property var offered: null
        property bool pendingApproval: false
        property string message: ""
        readonly property var copy: Texts.words(host.language)
        function dismissSuggestion() { suggested=false; interrupted=false; }
        function decline() { offered=null; }
        function stop(reason) { granted=false; sessionProtection=false; }
        function enableSessionProtection() { sessionProtection=true; granted=true; test.panelContent.recoveryOpen=false; }
    }
    Window {
        id: window; visible:true; width:(panel.width+40)*test.scale; height:(panel.height+40)*test.scale
        color:"#26374d"
        Rectangle { anchors.fill:parent; color:window.color }
        Plugin.PanelContent {
            id:panel; x:20*test.scale; y:20*test.scale; width:test.compactCase ? 420 : 520; height:recoveryOpen ? Math.min(test.availableHeight,implicitHeight) : test.availableHeight
            scale:test.scale; transformOrigin:Item.TopLeft
            hostWidget:host; recovery:recovery
            onExpandRequested: { expanded=true; expansion=1; }
        }
    }
    Timer {
        interval:150; running:true; repeat:true
        onTriggered: {
            try {
                switch(test.step++) {
                case 0: panel.begin(); break;
                case 1:
                    test.check(!host.keepSearchFocus && panel.mode==="windows", "first-loss notice is passive");
                    test.check(test.find(panel,"focusRecoveryNotice").label===recovery.copy.review,"unknown source offers generic review");
                    test.click("focusRecoveryNotice"); break;
                case 2:
                    test.check(panel.recoveryOpen && panel.mode==="windows" && !host.keepSearchFocus,"unknown loss opens the brief dialog without protection");
                    test.check(!!test.find(panel,"approveFocusProtection") && test.find(panel,"approveFocusProtection").enabled,
                        "unidentified source offers temporary protection with its own scope");
                    test.capture("unknown-dialog");test.step=23;break;
                case 23: test.click("focusTroubleshootingAction");test.step=24;break;
                case 24:
                    test.check(panel.mode==="troubleshooting" && !recovery.suggested && !recovery.interrupted && !host.keepSearchFocus,"first-loss notice only opens Settings");
                    test.check(test.find(panel,"editorScroll").contentY===0,"explanation opens at the top");
                    test.capture("intro");test.step=20;
                    break;
                case 20: test.click("keepSearchFocusToggle");test.step=31;break;
                case 31:
                    test.check(panel.recoveryOpen && !host.keepSearchFocus,"Settings requires confirmation before enabling persistent protection");
                    test.capture("confirmation");test.step=35;break;
                case 35:
                    test.click("cancelPermanentProtection");
                    test.check(!panel.recoveryOpen && panel.mode==="troubleshooting" && !host.keepSearchFocus,"cancel returns to the same Settings page without enabling");
                    test.click("keepSearchFocusToggle");test.step=32;break;
                case 32: test.click("confirmPermanentProtection");test.step=3;break;
                case 3:
                    test.check(host.keepSearchFocus,"explicit toggle enables");
                    test.capture("protection");test.step=21;break;
                case 21: panel.back(Qt.MouseFocusReason);test.step=4;break;
                case 4:
                    test.check(panel.mode==="windows" && panel.recoveryOpen,"Back returns to the review that opened help");
                    panel.navigateBack();test.check(!panel.recoveryOpen,"next Back returns to main panel");
                    panel.showSettings();test.find(panel,"settingsControlsSection").expanded=true;
                    var entry=test.find(panel,"troubleshootingEntry"); panel.ensureVisible(entry); break;
                case 5: test.click("troubleshootingEntry"); break;
                case 6:
                    test.check(panel.mode==="troubleshooting", "Controls opens nested editor");
                    test.click("keepSearchFocusToggle"); break;
                case 7:
                    test.check(!host.keepSearchFocus,"explicit toggle disables");
                    panel.ensureVisible(test.find(panel,"focusWarningPreferences"));test.capture("warnings");
                    break;
                case 8:
                    panel.navigateBack(); test.check(panel.mode==="settings","right-click navigation returns one level");
                    panel.begin(); recovery.suggested=true;break;
                case 9:
                    test.click("focusRecoveryNotice");break;
                case 10:
                    test.check(panel.recoveryOpen && !host.keepSearchFocus,"repeated losses use the same brief dialog");
                    test.click("focusTroubleshootingAction");test.step=25;break;
                case 25:
                    test.check(panel.mode==="troubleshooting" && !recovery.suggested && !host.keepSearchFocus,"repeated-loss suggestion also opens only the explanation");
                    panel.begin();recovery.offered={app:"Example App",appKey:"x11:ExampleApp"};
                    if(test.compactCase){panel.expanded=false;panel.expansion=0;}
                    preview.visible=true;test.step=22;break;
                case 22: panel.contentY=80;test.startingScroll=panel.contentY;test.click("focusRecoveryNotice");test.step=11;break;
                case 11:
                    test.check(panel.recoveryOpen && !preview.visible && preview.dismissCount>0,"review dismisses existing preview");
                    test.check(!test.find(panel,"panelHeader").visible && !test.find(panel,"windowList").visible
                        && !test.find(panel,"panelFooter").visible,"normal content cannot show through the themed dialog");
                    var image=pixels.grabImage(window.contentItem);
                    var x=Math.floor((panel.x+panel.width*test.scale-2)),y=Math.floor((panel.y+panel.height*test.scale-2));
                    test.check(Math.abs(image.red(x,y)-38)<2 && Math.abs(image.green(x,y)-55)<2 && Math.abs(image.blue(x,y)-77)<2,
                        "dialog preserves enclosing panel background");
                    test.capture("dialog");break;
                case 12:
                    test.click("focusTroubleshootingAction");break;
                case 13:
                    test.check(panel.mode==="troubleshooting" && !panel.recoveryOpen && !host.keepSearchFocus,"dialog opens alternatives without enabling protection");
                    test.check(test.find(panel,"editorScroll").contentY===0,"Troubleshooting starts with explanation from dialog");
                    panel.navigateBack();break;
                case 14:
                    test.check(panel.recoveryOpen && panel.mode==="windows","right click from help returns to the prior review");
                    panel.navigateBack();break;
                case 15:
                    test.check(!panel.recoveryOpen && Math.abs(panel.contentY-test.startingScroll)<1,"return to list restores its scroll position");
                    panel.searchField.text="Atlas";panel.showTroubleshooting();break;
                case 16:
                    test.click("settingsButton");break;
                case 17:
                    test.check(panel.mode==="windows" && !panel.recoveryOpen && panel.searchField.text==="Atlas","direct help Back returns to Search and preserves query");
                    recovery.interrupted=true;panel.openRecovery();host.rejectSave=true;break;
                case 18:
                    test.click("keepFocusProtection");test.step=33;break;
                case 33:
                    test.check(!host.keepSearchFocus && panel.recoveryOpen,"short dialog also requires confirmation");
                    test.click("confirmPermanentProtection");test.step=19;break;
                case 19:
                    test.check(panel.recoveryOpen && !host.keepSearchFocus && recovery.message===recovery.copy.saveFailed,"failed protection save preserves the dialog and prior choice");
                    host.rejectSave=false;test.click("confirmPermanentProtection");test.step=26;break;
                case 26:
                    test.check(host.keepSearchFocus && !panel.recoveryOpen && panel.mode==="windows","explicit short-dialog choice enables recurring protection without opening Settings");
                    test.check(!test.find(panel,"focusProtectionStatus").parent.visible,"permanent protection has no routine status row");
                    host.persistSettings({keepSearchFocus:false});recovery.granted=true;recovery.protectionApp="Example Suite (Example App)";break;
                case 27:
                    test.check(test.find(panel,"focusProtectionStatus").text.endsWith(" (Example App)"),"temporary status names the protected source app");
                    panel.protectionPaused=true;break;
                case 28:
                    test.check(test.find(panel,"focusProtectionStatus").text.indexOf(recovery.copy.paused)===0
                        && test.find(panel,"focusProtectionStatus").text.endsWith(" (Example App)"),"paused protection retains its app label");
                    panel.prepareClose();recovery.granted=false;recovery.protectionApp="";recovery.manualRequested=true;break;
                case 29:
                    test.check(test.find(panel,"focusProtectionStatus").text.endsWith(" (Example App)"),"closing notice is unaffected by protection teardown");
                    panel.begin();break;
                case 30:
                    test.check(test.find(panel,"focusProtectionStatus").text===recovery.copy.manualEnabled,"next opening reads current protection state instead of the closing snapshot");
                    recovery.manualRequested=false;recovery.granted=true;test.step=34;break;
                case 34:
                    test.check(test.find(panel,"turnOffFocusProtection").visible,"temporary protection offers direct Turn off");
                    test.click("turnOffFocusProtection");
                    test.check(!recovery.granted,"Turn off stops temporary protection without opening settings");
                    recovery.interrupted=true;panel.openRecovery();test.step=36;break;
                case 36:
                    test.click("approveFocusProtection");
                    test.check(recovery.sessionProtection && recovery.granted && !host.keepSearchFocus && !panel.recoveryOpen,
                        "unattributed temporary choice never enables permanent protection");
                    test.click("turnOffFocusProtection");recovery.interrupted=true;window.color="#428d72";
                    host.persistSettings({panelStyle:"wallpaper",wallpaperTransparency:100});
                    host.textShadowSamples=[[66,141,114]];
                    Color.shellValues={};Color.background="#111c18";Color.foreground="#c1c497";
                    Color.accent="#509475";host.themeAccent="#509475";
                    host.savedAppearance=Object.assign({},host.savedAppearance,{colorMode:"theme",colorScope:"all"});
                    host.appearance=host.savedAppearance;
                    break;
                case 37:
                    test.check(!test.find(panel,"focusWarningBackdrop") && test.find(panel,"focusProtectionStatus").font.bold
                        && test.find(panel,"focusProtectionStatus").shadowActive,
                        "warning has a letter-only halo without a background block");
                    test.capture("warning-contrast");test.step=38;break;
                case 38:
                    panel.expanded=false;panel.expansion=0;break;
                case 39:
                    var count=test.find(panel,"windowCountText");
                    test.check(count.shadowActive && !Qt.colorEqual(count.color,count.textColor)
                        && count.style===Text.Raised && count.font.pixelSize>=11,
                        "compact count gets solid readable ink and a shadow, never a hollow outline");
                    test.capture("hover-legibility");break;
                case 40:
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            }catch(e){console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+e);stop();Qt.quit();}
        }
    }
}
