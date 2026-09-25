import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    readonly property real uiScale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var result = find(child, name); if (result) return result; }
        return null;
    }
    TestEvent { id: input }
    QtObject {
        id: state
        property bool busy: false
        property double observedAt: 0
        property var snapshot: ({clients:[]})
        signal refreshed(int revision)
        signal failed()
        function refresh() {}
    }
    Plugin.FocusRecovery { id: recovery; state: state; language: "pl" }
    Component { id: storeFactory; Plugin.FocusIssues {} }
    property var restored: null
    QtObject {
        id: host
        property string language: "pl"
        property color accent: "#bc9bda"
        property bool keepSearchFocus: false
        property var focusRecovery: recovery
        function persistSettings(value) { keepSearchFocus=value.keepSearchFocus;return true; }
    }
    Window {
        id: window; visible:true; width:520*test.uiScale; height:700*test.uiScale
        Rectangle {anchors.fill:parent;color:"#26374d"}
        Item {
            width:500;height:660;x:10*test.uiScale;y:10*test.uiScale;scale:test.uiScale;transformOrigin:Item.TopLeft
            Flickable {
                id: viewport
                anchors.fill:parent;contentHeight:settings.implicitHeight;clip:true
                Plugin.TroubleshootingSettings {id:settings;width:parent.width;hostWidget:host}
            }
            Plugin.FocusRecoveryDialog {id:dialog;anchors.fill:parent;recovery:recovery}
        }
    }
    Timer {
        interval:100;running:true;repeat:true
        onTriggered: {
            if (recovery.issues.saving || !recovery.issues.ready || (test.restored && !test.restored.ready)) return;
            try {
                var k="x11:FictionalApp";
                switch(test.step++) {
                case 0:
                    test.check(recovery.issues.record({xwayland:true,class:"FictionalApp",app:"Example App"},Date.now()),"history saved");
                    recovery.offered={app:"Example App",klass:"FictionalApp",appKey:k,source:{stableId:"ff"}};
                    dialog.open();break;
                case 1:
                    test.check(!!test.find(settings,"focusIssueApp"),"application appears in settings");
                    test.find(dialog,"focusIgnoreMenu").clicked();break;
                case 2:
                    test.check(dialog.choosingIgnore,"ignore choices open");
                    test.find(dialog,"focusIgnoreApp").clicked();break;
                case 3:
                    test.check(!dialog.opened && recovery.issues.muted(k),"app ignored through dialog");
                    test.check(!recovery.granted,"ignoring does not enable protection");
                    test.find(settings,"focusIssueApp").clicked();break;
                case 4:
                    test.check(!recovery.issues.muted(k),"settings restores application warnings");
                    test.find(settings,"ignoreFocusSession").clicked();break;
                case 5:
                    test.check(recovery.issues.sessionIgnored,"session switch saved");
                    test.restored=storeFactory.createObject(test,{desktopSession:recovery.issues.desktopSession});break;
                case 6:
                    test.check(test.restored.sessionIgnored && test.restored.apps.length===1,"store reload preserves session/history");
                    test.restored.desktopSession="new-login";
                    test.check(!test.restored.sessionIgnored,"new login expires session ignore");
                    test.find(settings,"ignoreFocusSession").clicked();
                    test.find(settings,"ignoreAllFocusWarnings").clicked();break;
                case 7:
                    test.check(recovery.issues.allIgnored,"global switch saved");
                    test.find(settings,"ignoreAllFocusWarnings").clicked();
                    test.step=70; break;
                case 70:
                    test.check(!recovery.issues.muted(""),"global warnings restored");
                    recovery.offered={app:"Example App",klass:"FictionalApp",appKey:k,source:{stableId:"ff"}};
                    recovery.issues.readBlocked=true;
                    dialog.open();dialog.activate("ignore");dialog.activate("app");
                    test.check(dialog.opened && !recovery.issues.muted(k) && recovery.message!=="","failed write does not pretend success");
                    recovery.issues.readBlocked=false;dialog.activate("back");
                    test.check(!dialog.choosingIgnore,"back returns one level");
                    test.check(test.find(dialog,"approveFocusProtection").y >= 0,"actions laid out");
                    recovery.issues.choose("all",false,"");dialog.opened=false;
                    viewport.contentY=Math.min(settings.implicitHeight-viewport.height,test.find(settings,"focusApplicationsSection").y);
                    test.step=8; break;
                case 8:
                    if(Quickshell.env("WINDOWPEEK_TEST_IMAGE"))window.contentItem.grabToImage(function(image) {image.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE"));});
                    break;
                case 9:
                    console.info("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            } catch(error) {console.error("WINDOWPEEK_TEST_FAIL: "+error);stop();Qt.quit();}
        }
    }
}
