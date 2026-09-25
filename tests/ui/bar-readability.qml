import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Ui as Ui
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property real originalWidth: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, message) { if (!ok) throw new Error(message); }
    QtObject { id: host; property string textShadowMode: "auto" }
    Ui.PluginBarApi {
        id: bar; pluginId:"sarr.windowpeek"; moduleName:"sarr.windowpeek"
        barSize:30; fontFamily:"monospace"
        background:"#428d72"; barForeground:"#c1c497"; foregroundAnimationEnabled:true
    }
    TestEvent { id: events }
    Window {
        visible:true; width:500*test.scale; height:80*test.scale
        Rectangle {
            id: canvas; width:500; height:80; scale:test.scale; transformOrigin:Item.TopLeft; color:bar.background
            Plugin.ReadableBarButton {
                id: button; x:10; y:20; hostWidget:host; bar:bar
                text:"WindowPeek · 14 · hidden"; activeColor:"#509475"
                activeFallbackColor:"#E5C736"
                onPressed: active=!active
            }
        }
    }
    Timer {
        interval:220; running:true; repeat:true
        onTriggered: {
            try {
                var label=button.nativeLabels[0];
                switch(test.step++) {
                case 0:
                    test.check(!!label,"native bar label found"); test.originalWidth=button.implicitWidth;
                    test.check(label.color===bar.barForeground && label.style===Text.Normal,
                        "Auto leaves the idle label in its original color without shadow");
                    events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton,Qt.NoModifier,0);
                    test.check(label.color===button.activeFallbackColor && label.style===Text.Raised,
                        "click applies final ink and shadow immediately despite host color animation"); break;
                case 1:
                    test.check(button.active,"real button click activates label");
                    test.check(label.color===button.activeFallbackColor && label.style===Text.Raised,"weak active accent gets yellow fallback and glyph shadow");
                    test.check(button.implicitWidth===test.originalWidth,"shadow preserves bar width");
                    if(Quickshell.env("WINDOWPEEK_TEST_IMAGE")) canvas.grabToImage(function(r){r.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE"));});
                    test.step=10; break;
                case 10:
                    host.textShadowMode="off"; test.step=2; break;
                case 2:
                    test.check(label.color===button.activeColor && label.style===Text.Normal,"Off restores original active color");
                    host.textShadowMode="auto"; bar.background="#111c18"; button.activeColor="#dcd7ba"; break;
                case 3:
                    test.check(label.color===button.activeColor && label.style===Text.Normal,"legible accent on opaque bar stays unchanged");
                    bar.transparent=true; break;
                case 4:
                    test.check(label.style===Text.Raised,"transparent bar uses conservative estimate");
                    bar.transparent=false; host.textShadowMode="on"; break;
                case 5:
                    test.check(label.style===Text.Raised,"On also applies to opaque bar");
                    events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton,Qt.NoModifier,0);
                    test.check(label.color===bar.barForeground && label.style===Text.Normal,
                        "close restores idle ink and style immediately without a color tween"); break;
                case 6:
                    test.check(!button.active && label.color===bar.barForeground && label.style===Text.Normal,
                        "second click restores original idle rendering even with shadows On");
                    console.info("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            } catch(e) { console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+e);stop();Qt.quit(); }
        }
    }
}
