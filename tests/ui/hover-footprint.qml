import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property int clicks: 0
    function check(ok, message) { if(!ok) throw new Error(message); }
    Window {
        visible:true; width:500; height:400
        TestEvent { id: events }
        Plugin.HoverFootprint { id:footprint; card:card; onClicked:test.clicks++ }
        Rectangle {
            id:card; x:20; y:20; width:300; height:240; color:"#453363"
            MouseArea { anchors.fill:parent; hoverEnabled:true }
        }
    }
    Timer {
        interval:320; repeat:true; running:true
        onTriggered: {
            try {
                switch(test.step++) {
                case 0: events.mouseMove(card,290,230,0,Qt.NoButton,Qt.NoModifier); break;
                case 1: footprint.retain(); card.width=200; card.height=160; break;
                case 2:
                    test.check(footprint.active && footprint.containsPointer,"stationary pointer keeps old area after shrink");
                    events.mouseClick(footprint,290,230,Qt.LeftButton,Qt.NoModifier,0);
                    test.check(test.clicks===1,"vacated area permits expansion click");
                    events.mouseMove(card,10,10,0,Qt.NoButton,Qt.NoModifier); break;
                case 3:
                    test.check(!footprint.active,"entering new card releases retained area");
                    card.width=300; card.height=240; events.mouseMove(card,290,230,0,Qt.NoButton,Qt.NoModifier); break;
                case 4: footprint.retain(); card.width=200; card.height=160; break;
                case 5:
                    test.check(footprint.active,"second collapse retains pointer");
                    events.mouseMove(card,400,300,0,Qt.NoButton,Qt.NoModifier); break;
                case 6:
                    test.check(!footprint.active,"leaving old footprint releases it");
                    card.width=300; card.height=240; events.mouseMove(card,10,10,0,Qt.NoButton,Qt.NoModifier); break;
                case 7: footprint.retain(); card.width=200; card.height=160; break;
                case 8:
                    test.check(!footprint.active,"pointer already in new card needs no extra region");
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch(error) { console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error); stop(); Qt.quit(); }
        }
    }
}
