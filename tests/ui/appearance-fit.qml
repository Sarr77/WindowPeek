import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin

ShellRoot {
    id:test
    property int step:0
    property real controls:0
    property real previewHeight:0
    readonly property real scale:Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok,text) { if(!ok)throw new Error(text); }
    function find(item,name) {
        if(item.objectName===name)return item;
        for(var child of item.children||[]){var found=find(child,name);if(found)return found;}return null;
    }
    FakeHost { id:host }
    Window {
        id:window; visible:true; width:540*test.scale; height:1080*test.scale; color:Color.popups.background
        Plugin.PanelContent {
            id:panel; x:20*test.scale; y:20*test.scale; width:500; height:implicitHeight; maximumHeight:1040
            scale:test.scale; transformOrigin:Item.TopLeft; hostWidget:host
        }
    }
    Timer {
        interval:180;running:true;repeat:true
        onTriggered: {
            try {
                var editor=test.find(panel,"appearanceEditor"),scroll=test.find(panel,"editorScroll"),preview=test.find(panel,"appearanceLivePreview");
                switch(test.step++) {
                case 0:panel.begin(true);panel.mode="appearance";break;
                case 1:
                    test.controls=editor.controlsHeight;test.previewHeight=preview.height;
                    panel.maximumHeight=panel.height-24;break;
                case 2:
                    test.check(Math.abs(editor.controlsHeight-test.controls)<0.01,"fitting never shrinks controls or their spacing");
                    test.check(preview.height<test.previewHeight-20,"preview gives up only the missing space");
                    test.check(scroll.contentHeight<=scroll.height+0.01,"slightly shorter screen has no editor scrollbar");
                    test.check(test.find(panel,"applyButton").mapToItem(scroll,0,test.find(panel,"applyButton").height).y<=scroll.height+0.01,"Apply remains fully visible");
                    panel.maximumHeight=540;break;
                case 3:
                    test.check(scroll.contentHeight>scroll.height && preview.height>Style.space(180),"small screens keep a usable preview and scroll normally");
                    panel.maximumHeight=1040;break;
                case 4:
                    test.check(Math.abs(preview.height-test.previewHeight)<0.01,"larger screen restores original sample size");
                    host.setLanguage("pl");break;
                case 5:
                    test.check(scroll.contentHeight<=scroll.height+0.01,"Polish form also fits available height");
                    console.log("WINDOWPEEK_TEST_PASS");stop();
                    var path=Quickshell.env("WINDOWPEEK_TEST_IMAGE");
                    if(path)window.contentItem.grabToImage(function(result){result.saveToFile(path);Qt.quit();});else Qt.quit();
                }
            }catch(e){console.error("WINDOWPEEK_TEST_FAIL: "+e);stop();Qt.quit();}
        }
    }
}
