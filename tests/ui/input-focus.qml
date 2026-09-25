import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import QtTest
import Quickshell
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property var field: null
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item,name) {
        if (!item) return null;
        if (item.objectName===name) return item;
        for (var child of item.children || []) { var found=find(child,name); if(found) return found; }
        return null;
    }
    function named(name) { return find(panel,name); }
    function click(item,x,y) {
        check(!!item,"click target exists");
        events.mouseClick(item,x===undefined?item.width/2:x,y===undefined?item.height/2:y,Qt.LeftButton,Qt.NoModifier,0);
    }
    function prepare(item) { check(!!item,"field exists"); field=item;panel.ensureVisible(item); }
    function edit(text) { click(field);check(field.activeFocus,"field takes focus on click");if(text!==undefined)field.text=text; }
    function caption() {click(field.parent,1,1);}
    function blurred(message) {check(!field.activeFocus && !field.focus && !field.cursorVisible,message+" focus="+field.focus+" active="+field.activeFocus+" cursor="+field.cursorVisible+" value="+field.text);}
    TestEvent { id: events }
    FakeHost {
        id:host
        settings:({hintsMode:"off",hoverLogoImage:"builtin:omarchy-pixel",settingsLogoImage:"builtin:omarchy-pixel"})
    }
    Window {
        id: window;visible:true;width:600*test.scale;height:900*test.scale
        Plugin.PanelContent {
            id:panel;x:20*test.scale;y:20*test.scale;width:540;height:850
            scale:test.scale;transformOrigin:Item.TopLeft;hostWidget:host
        }
        Binding { target:panel.QQC.Overlay.overlay;property:"scale";value:test.scale }
        Binding { target:panel.QQC.Overlay.overlay;property:"transformOrigin";value:Item.TopLeft }
    }
    Timer {
        interval:160;running:true;repeat:true
        onTriggered:{
            try {
                switch(test.step++) {
                case 0:panel.begin();break;
                case 1:
                    test.prepare(test.named("windowSearch"));test.edit();
                    test.click(panel,2,2);
                    test.check(test.field.activeFocus && test.field.cursorVisible,"window search retains focus on blank header press");
                    events.keyClick(Qt.Key_1,Qt.ControlModifier,0);
                    test.check(host.focused===panel.shortcutAddresses[0] && !test.field.text,"shortcut still selects a window without typing into search");
                    events.keyClick(Qt.Key_A,Qt.NoModifier,0);
                    test.check(test.field.text==="a","typing after background click goes straight to search");
                    panel.showSettings();test.blurred("search releases focus when Settings opens");
                    test.named("settingsPersonalizationSection").expanded=true;panel.mode="pictures";break;
                case 2:test.prepare(test.named("hoverLogoLoopDelay"));break;
                case 3:test.edit("0.3");test.caption();break;
                case 4:
                    test.blurred("loop delay loses focus on its caption");
                    test.check(host.hoverLogoLoopDelay===0.3,"outside press commits the pending numeric value");
                    test.prepare(test.named("hoverLogoCooldown"));break;
                case 5:
                    test.edit("8");test.click(test.named("hoverLogoLoopToggle"));break;
                case 6:
                    test.blurred("non-focusable loop switch removes cooldown caret");
                    test.check(host.hoverLogoCooldown===8 && !host.hoverLogoLoop,"field saves and switch still receives click: cooldown="+host.hoverLogoCooldown+" loop="+host.hoverLogoLoop);
                    test.prepare(test.named("settingsLogoLoopDelay"));break;
                case 7:
                    test.edit("1.5");test.click(test.field);
                    test.check(test.field.activeFocus,"clicking inside retains text editing");
                    events.mousePress(test.field,12,test.field.height/2,Qt.LeftButton,Qt.NoModifier,0);
                    events.mouseMove(test.field,-10,test.field.height/2,0,Qt.LeftButton,Qt.NoModifier);
                    events.mouseRelease(test.field,-10,test.field.height/2,Qt.LeftButton,Qt.NoModifier,0);
                    test.check(test.field.activeFocus,"selection drag beyond field does not blur");
                    test.field.enabled=false;test.blurred("disabling a field releases focus");test.field.enabled=true;
                    panel.mode="settings";test.named("settingsPersonalizationSection").expanded=false;
                    test.named("settingsPanelSection").expanded=true;
                    test.prepare(test.find(test.named("panelHoverDelayControl"),"delayInput"));break;
                case 8:test.edit("850");test.click(test.find(test.named("panelHoverDelayControl"),"delayCaption"));break;
                case 9:
                    test.blurred("hover delay loses focus outside input");test.check(host.panelHoverDelay===850,"hover delay saves on blur");
                    panel.mode="scaling";break;
                case 10:test.prepare(test.find(test.named("panelScaleControl"),"scaleInput"));break;
                case 11:
                    test.edit();test.caption();test.blurred("scale entry loses focus outside input");
                    panel.mode="appearance";break;
                case 12:test.prepare(test.named("hexInput"));break;
                case 13:
                    test.edit();test.caption();test.blurred("HEX entry loses focus when clicking color swatch");
                    panel.mode="labels";break;
                case 14:test.named("labelsEditor").setStyle("custom");break;
                case 15:test.prepare(test.named("labelInput_panelTitle"));break;
                case 16:
                    test.edit();test.click(test.field.parent,2,2);test.blurred("custom label stops editing on its caption");
                    test.edit();test.named("labelsEditor").setStyle("default");
                    test.blurred("hiding custom fields releases focus");panel.showSettings();break;
                case 17:test.named("languages").open();break;
                case 18:
                    test.field=test.find(panel.QQC.Overlay.overlay,"dropdownSearchField");
                    test.edit("English");test.caption();
                    test.blurred("modal dropdown search releases focus on header padding");
                    test.named("languages").close();test.named("settingsPersonalizationSection").expanded=true;panel.mode="pictures";
                    test.named("settingsLogoPicker").changed("image");break;
                case 19:
                    test.field=test.find(panel.QQC.Overlay.overlay,"logoFolderPath");
                    test.edit();test.caption();test.blurred("file chooser path releases focus on row padding");
                    test.named("logoSettings").activePopup.close();
                    test.prepare(test.named("hoverLogoCooldown"));break;
                case 20:
                    test.edit();events.keyClick(Qt.Key_Tab,Qt.NoModifier,0);
                    test.blurred("Tab transfers focus away from a numeric field");
                    test.check(!!window.activeFocusItem,"keyboard focus stays available for navigation");
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            } catch(error) {console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error);stop();Qt.quit();}
        }
    }
}
