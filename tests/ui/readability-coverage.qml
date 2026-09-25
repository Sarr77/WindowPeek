import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin
import "WindowPeek/vendor/omarchy" as Choice

ShellRoot {
    id: test
    property int step: 0
    property int waits: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var r=find(child,name); if(r) return r; }
        return null;
    }
    function labels(item, enabled) {
        var count=0;
        for (var child of item.children || []) {
            if ("shadowActive" in child) {
                check(child.shadowHost === host, "detached text keeps its host: "+child.text);
                check(child.shadowActive === (enabled && child.visible), "visible detached text follows mode: "+child.text);
                count++;
            }
            count+=labels(child,enabled);
        }
        return count;
    }
    FakeHost {
        id: host
        settings: ({panelStyle:"wallpaper",wallpaperTransparency:100,textShadowMode:"on",previewHoverDelay:0})
        textShadowSamples: [[66,141,114]]
        themeAccent:"#509475"
        wallpaperSource:"file://"+Quickshell.env("WINDOWPEEK_TEST_PROFILE")+"/green.svg"
        windowPreview: thumbnail
    }
    TestEvent { id: events }
    FloatingWindow {
        id: window; visible:true; implicitWidth:1000*test.scale; implicitHeight:700*test.scale
        color:"#428d72"
        Item {
            id: content; property var hostWidget:host
            width:1000; height:700; scale:test.scale; transformOrigin:Item.TopLeft
            Rectangle { anchors.fill:parent; color:"#428d72" }
            Plugin.PanelContent { id: panel; width:500; height:650; hostWidget:host }
            Column {
                x:530; y:25; width:420; spacing:16
                Plugin.EditField { id: input; width:400; foreground:"#738f77"; selectByMouse:true; placeholderText:"Search windows…" }
                Plugin.EditField { id: numeric; width:120; foreground:"#738f77"; text:"0.3"; validator:DoubleValidator { bottom:0 } }
                Choice.SearchableDropdown { id: choice; width:400; hostWidget:host; options:["One","Two"]; showLabel:false }
                Plugin.LabelButton { id: origin; label:"Choose image" }
                Plugin.PanelHint { id: hint; hostWidget:host; text:"Hint on its own opaque surface"; alwaysAvailable:true; requested:true }
            }
            Plugin.LogoPicker { id: picker; hostWidget:host }
            Plugin.ShortcutRecorder { id: recorder; hostWidget:host; editor:QtObject { function candidateError() {return "";} } }
        }
    }
    Plugin.WindowThumbnail { id: thumbnail; hostWidget:host; shortcutTarget:panel.previewKeyTarget }
    Timer {
        interval:180; running:true; repeat:true
        onTriggered: {
            try {
                switch(test.step++) {
                case 0:
                    Color.shellValues={}; Color.background="#111c18"; Color.foreground="#c1c497"; Color.accent="#509475";
                    host.previewAppearance({colorMode:"theme",colorScope:"all"});
                    panel.begin(); thumbnail.modifierState.enabled=false;
                    thumbnail.showFor(test.find(panel,"windowFocusPointer"),"0x1",panel);
                    thumbnail.modifierState.pending="fixture";
                    thumbnail.modifierState.receive("custom","windowpeek-preview-shift,fixture,0"); break;
                case 1:
                    if (!hint.visible) { test.check(test.waits++<10,"hint dwell completes"); test.step--; break; }
                    test.check(thumbnail.visible && thumbnail.backingWindowVisible,"preview mapped");
                    test.check(test.labels(thumbnail.contentItem,true)===3,"all three preview captions covered");
                    test.check(hint.contentItem.shadowHost===host && hint.contentItem.shadowActive,"reparented hint covered");
                    test.check(input.shadowHost===host && input.color!==input.foreground,"input contrast corrected");
                    test.check(input.placeholderTextColor!==input.originalPlaceholderColor,"placeholder corrected");
                    var placeholder=test.find(panel.searchField,"readableInputPlaceholder");
                    test.check(placeholder.visible && placeholder.style===Text.Raised && placeholder.color.a===1,"Search placeholder has solid letters and a glyph shadow");
                    test.check(numeric.color!==numeric.foreground,"numeric field corrected");
                    content.grabToImage(function(r){ if(Quickshell.env("WINDOWPEEK_TEST_IMAGE")) r.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE")); });
                    thumbnail.contentItem.grabToImage(function(r){ if(Quickshell.env("WINDOWPEEK_TEST_IMAGE")) r.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE")+".preview.png"); });
                    break;
                case 20:
                    thumbnail.dismiss(); window.contentItem.forceActiveFocus(); input.forceActiveFocus(); test.step=2; break;
                case 2:
                    if (thumbnail.visible) { test.step=20; break; }
                    events.keyClick(Qt.Key_A,Qt.NoModifier,0); events.keyClick(Qt.Key_B,Qt.NoModifier,0);
                    test.check(input.text==="ab" && input.cursorPosition===2,"native input receives text");
                    test.check(!test.find(input,"readableInputPlaceholder").visible,"placeholder disappears while typing");
                    input.select(0,2); test.check(input.selectedText==="ab","native selection intact");
                    events.keyClick(Qt.Key_C,Qt.NoModifier,0);
                    test.check(input.text==="c" && input.activeFocus,"selection replacement retains focus");
                    choice.open(); break;
                case 3:
                    var field=test.find(choice.QQC.Overlay.overlay,"dropdownSearchField");
                    test.check(!!field && field.shadowHost===host,"dropdown input keeps host through overlay");
                    choice.close(); picker.currentSource="file://"+Quickshell.env("WINDOWPEEK_TEST_PROFILE")+"/fixture.png"; picker.begin(origin); break;
                case 4:
                    test.check(test.labels(picker.contentItem,true)>2,"file chooser text covered");
                    test.check(test.find(picker.contentItem,"logoFolderPath").shadowHost===host,"file path input covered");
                    picker.close(); recorder.begin({id:"test",label:"Test shortcut",modifier:false},"Ctrl+A",origin); break;
                case 5:
                    test.check(test.labels(recorder.contentItem,true)>2,"shortcut dialog text covered");
                    host.persistSettings({textShadowMode:"off"}); break;
                case 6:
                    test.labels(recorder.contentItem,false);
                    test.check(!hint.contentItem.shadowActive,"hint follows Off");
                    test.check(input.color===input.foreground && input.placeholderTextColor===input.originalPlaceholderColor,"Off restores native input colors");
                    recorder.close(); host.persistSettings({textShadowMode:"auto"}); break;
                case 7:
                    test.check(input.color!==input.foreground,"Auto corrects weak input on wallpaper");
                    console.info("WINDOWPEEK_TEST_PASS: detached surfaces and native input readability"); stop(); Qt.quit(); break;
                }
            } catch(e) { console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+e); stop(); Qt.quit(); }
        }
    }
}
