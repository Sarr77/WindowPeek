import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import QtTest
import Quickshell
import "WindowPeek" as Plugin
import "WindowPeek/src/Appearance.js" as Appearance
import "WindowPeek/src/I18n.js" as I18n

ShellRoot {
    id: test
    property int step: 0
    property bool finished: false
    property int languageIndex: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    TestEvent { id: events }
    TestCase { id: settle; when:false }
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var result=find(child,name); if(result)return result; }
        return null;
    }
    function select(state, index) {
        var picker=find(editor,"barStylePicker-"+state);
        check(events.mouseClick(picker,picker.width/2,picker.height-18,Qt.LeftButton,Qt.NoModifier,0),"picker click");
        settle.wait(30);
        check(picker.popupOpen,"picker opens with actual Qt input");
        events.keyClick(Qt.Key_Up,Qt.NoModifier,0); events.keyClick(Qt.Key_Up,Qt.NoModifier,0);
        for(var i=0;i<index;i++)events.keyClick(Qt.Key_Down,Qt.NoModifier,0);
        events.keyClick(Qt.Key_Return,Qt.NoModifier,0);
        settle.wait(10);
        check(!picker.popupOpen,"selection closes the picker");
        settle.tryVerify(function() { return picker.popupInputItem === null; }, 1000, "popup finishes closing before the next interaction");
        settle.wait(30);
    }
    FakeHost {
        id: host
        settings:({panelStyle:"wallpaper",followBarStyle:true,glassTransparency:8,wallpaperTransparency:70,hintsMode:"off"})
        Component.onCompleted:savedAppearance=Appearance.normalize({uiScale:test.scale})
    }
    Window {
        id: window; visible:true; width:540*test.scale; height:800*test.scale; color:"#1b1b26"
        Plugin.BarStyleRules {
            id:editor; x:20*test.scale; y:20*test.scale; width:500; scale:test.scale
            transformOrigin:Item.TopLeft; hostWidget:host
            Binding { target:editor.QQC.Overlay.overlay; property:"transformOrigin"; value:Item.TopLeft }
            Binding { target:editor.QQC.Overlay.overlay; property:"scale"; value:test.scale }
        }
    }
    Timer {
        interval:80;running:true;repeat:true
        onTriggered:{
            stop(); // QtTest waits process events: do not re-enter the next step mid-interaction.
            try {
                switch(test.step++) {
                case 0:
                    test.check(test.find(editor,"barStylePicker-opaque").value==="solid"
                        && test.find(editor,"barStylePicker-glassy").value==="wallpaper"
                        && test.find(editor,"barStylePicker-none").value==="wallpaper","default per-state choices");
                    test.select("opaque",2);break;
                case 1:
                    test.check(host.barStyleRules.opaque.style==="glass","opaque rule saved through input");
                    var slider=test.find(test.find(editor,"barStyleTransparency-opaque"),"transparencySlider");
                    slider.forceActiveFocus(Qt.TabFocusReason);settle.wait(30);events.keyClick(Qt.Key_Right,Qt.NoModifier,0);break;
                case 2:
                    test.check(host.barStyleRules.opaque.glassTransparency===66,"Glass slider keyboard saves a step: "+host.barStyleRules.opaque.glassTransparency);
                    test.select("glassy",2);break;
                case 3:
                    test.check(host.barStyleRules.glassy.style==="glass" && host.barStyleRules.glassy.glassTransparency===65,
                        "Glass remains available with its independent default transparency");
                    test.select("glassy",1);
                    test.check(host.barStyleRules.glassy.style==="wallpaper"
                        && !test.find(editor,"barStyleTransparency-glassy").visible,"per-state slider follows chosen style");
                    host.rejectSave=true;test.select("none",2);break;
                case 4:
                    test.check(host.saveFailed && host.barStyleRules.none.style==="wallpaper"
                        && test.find(editor,"barStylePicker-none").value==="wallpaper","failed save restores displayed choice: " + JSON.stringify({failed:host.saveFailed,rule:host.barStyleRules.none,picker:test.find(editor,"barStylePicker-none").value}));
                    host.rejectSave=false;test.select("none",2);break;
                case 5:
                    test.check(host.barStyleRules.none.style==="glass" && host.barStyleRules.opaque.glassTransparency===66,
                        "editing a different row preserves the first rule");
                    test.check(host.settings.glassTransparency===8 && host.settings.wallpaperTransparency===70,
                        "manual and Wallpaper preferences preserved");
                    host.setLanguage(I18n.languages[test.languageIndex++].code);break;
                case 6:
                    test.check(test.find(editor,"barStylePicker-opaque").label===host.words.barStyleOpaque
                        && test.find(editor,"barStylePicker-glassy").label===host.words.barStyleGlassy
                        && test.find(editor,"barStylePicker-none").label===host.words.barStyleTransparent,
                        "contextual labels follow language "+host.language);
                    if(test.languageIndex<I18n.languages.length){test.step=5;break;}
                    test.find(editor,"barStylePicker-glassy").open();settle.wait(20);
                    editor.closePickers();
                    test.check(!test.find(editor,"barStylePicker-glassy").popupOpen,"parent can close nested pickers");
                    console.info("WINDOWPEEK_TEST_PASS: bar style pickers, independent transparency, failed saves and 30 languages");test.finished=true;Qt.callLater(Qt.quit);
                }
            } catch(error){console.error("WINDOWPEEK_TEST_FAIL: "+error);test.finished=true;Qt.callLater(Qt.quit);}
            if (!test.finished) start();
        }
    }
}
