import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    property int step: 0
    property int waits: 0
    property int handleIndex: 0
    readonly property var handles: [
        {name:"logoLeftHandle",x:-1,y:0}, {name:"logoWidthHandle",x:1,y:0},
        {name:"logoTopHandle",x:0,y:-1}, {name:"logoHeightHandle",x:0,y:1},
        {name:"logoScaleHandle",x:-1,y:-1}, {name:"logoScaleTopRightHandle",x:1,y:-1},
        {name:"logoScaleBottomLeftHandle",x:-1,y:1}, {name:"logoScaleBottomRightHandle",x:1,y:1}
    ]
    property rect before
    property point origin
    function check(ok, text) { if (!ok) throw new Error(text); }
    function close(a,b) { return Math.abs(a-b)<0.1; }
    function find(item,name) {
        if(item.objectName===name)return item;
        for(var child of item.children||[]){var result=find(child,name);if(result)return result;}return null;
    }
    function press(name) {
        var handle=find(placement,name);
        origin=handle.mapToItem(window.contentItem,handle.width/2,handle.height/2);
        events.mousePress(window.contentItem,origin.x,origin.y,Qt.LeftButton,Qt.ControlModifier,0);
    }
    function move(dx,dy) { events.mouseMove(window.contentItem,origin.x+dx*scale,origin.y+dy*scale,0,Qt.LeftButton,Qt.ControlModifier); }
    function release(dx,dy) { events.mouseRelease(window.contentItem,origin.x+dx*scale,origin.y+dy*scale,Qt.LeftButton,Qt.ControlModifier,0); }
    function sameSize() {
        check(close(placement.bounds.width,before.width) && close(placement.bounds.height,before.height),"translation must not resize artwork");
    }
    FakeHost {
        id: host
        // A shortened landscape image in a viewport smaller than its default
        // height: the old default-height clamp left zero vertical movement.
        settings: ({settingsLogoLayout:{zoom:157,width:52,height:25,x:-12,y:-26}})
    }
    TestEvent { id: events }
    Window {
        id: window; visible:true; width:540*test.scale;height:240*test.scale
        Item {
            x:24*test.scale;y:24*test.scale;scale:test.scale
            Plugin.LogoPlacement {
                id:placement;width:468;height:140;baselineWidth:324
                hostWidget:host;artwork:art;naturalAspect:5/3;editing:true
            }
            Plugin.LogoArt {
                id:art; source:Quickshell.env("WINDOWPEEK_TEST_LOGO_SOURCE") || Qt.resolvedUrl("WindowPeek/tests/artwork/reveal.svg")
                playing:true;reveal:"iris";themeColors:false
            }
        }
    }
    Timer {
        interval:80;running:true;repeat:true
        onTriggered: {
            try {
                switch(test.step++) {
                case 0:
                    if (art.status!==Image.Ready) {
                        test.check(++test.waits<60,"artwork decodes before testing its controls");test.step--;break;
                    }
                    if (Quickshell.env("WINDOWPEEK_TEST_LOGO_SOURCE"))
                        test.check(test.close(art.aspect,5/3),"current artwork retains its measured source proportions");
                    var right=find(placement,"logoWidthHandle"), bottom=find(placement,"logoHeightHandle");
                    test.check(test.close(right.parent.x+right.parent.width/2,placement.bounds.width),"width handle sits on the right edge");
                    test.check(test.close(bottom.parent.y+bottom.parent.height/2,placement.bounds.height),"height handle sits on the bottom edge");
                    test.before=placement.bounds;test.press("logoMoveHandle");test.move(0,24);break;
                case 1:
                    test.check(test.close(placement.bounds.y,test.before.y+24),"shortened image moves down despite its taller default height");
                    test.sameSize();test.check(host.settings.settingsLogoLayout.y===-26,"drag saves only on release");
                    test.release(0,24);break;
                case 2:
                    test.before=placement.bounds;test.press("logoMoveHandle");test.move(0,-16);break;
                case 3:
                    test.check(test.close(placement.bounds.y,test.before.y-16),"same image moves back up");test.sameSize();
                    test.release(0,-16);break;
                case 4:
                    test.before=placement.bounds;test.press("logoMoveHandle");test.move(20,8);break;
                case 5:
                    test.check(test.close(placement.bounds.x,test.before.x+20) && test.close(placement.bounds.y,test.before.y+8),"diagonal drag follows both axes");
                    test.sameSize();test.release(20,8);break;
                case 6:
                    test.before=placement.bounds;test.press("logoMoveHandle");test.move(400,300);break;
                case 7:
                    test.check(test.close(placement.bounds.x+placement.bounds.width,placement.width-placement.edgeMargin) && test.close(placement.bounds.y+placement.bounds.height,placement.height-placement.edgeMargin),"movement reaches the actual lower/right edge");
                    test.sameSize();test.move(-400,-300);break;
                case 8:
                    test.check(test.close(placement.bounds.x,placement.edgeMargin) && test.close(placement.bounds.y,placement.edgeMargin),"movement reaches the actual upper/left edge");
                    test.sameSize();test.release(-400,-300);break;
                case 9:
                    test.sameSize();
                    test.check(test.close(placement.bounds.x,placement.edgeMargin) && test.close(placement.bounds.y,placement.edgeMargin),"release retains translated bounds");
                    placement.centerAxis(true);placement.centerAxis(false);break;
                case 10:
                    test.sameSize();
                    test.check(test.close(placement.centerX,placement.width/2) && test.close(placement.centerY,placement.height/2),"centering preserves dimensions");
                    test.press("logoMoveHandle");test.move(0,-16);test.release(0,-16);break;
                case 11:
                    test.before=placement.bounds;test.press("logoHeightHandle");test.move(0,60);break;
                case 12:
                    test.check(test.close(placement.centerX,test.before.x+test.before.width/2),"height growth never changes horizontal position");
                    test.check(test.close(placement.bounds.height,placement.height-2*placement.edgeMargin) && test.close(placement.bounds.y,placement.edgeMargin),"height growth uses all available room with only the required shift");
                    test.check(placement.bounds.y>=placement.edgeMargin-0.1,"resizing stays in the viewport");
                    test.check(test.close(placement.bounds.width,test.before.width),"height limit never shrinks the width");
                    var cappedHeight=placement.bounds.height;test.move(0,120);
                    test.check(test.close(placement.bounds.height,cappedHeight),"further outward movement stops at the height limit");
                    test.release(0,120);
                    host.persistSettings({settingsLogoLayout:{zoom:250,width:150,height:25,x:0,y:0}});break;
                case 13:
                    test.before=placement.bounds;test.press("logoMoveHandle");test.move(0,-20);break;
                case 14:
                    test.check(placement.bounds.y<test.before.y,"viewport-fitted oversized artwork still moves along its free axis");
                    test.sameSize();test.release(0,-20);break;
                case 15:
                    test.sameSize();
                    host.persistSettings({settingsLogoLayout:{zoom:100,width:70,height:25,x:0,y:0}});
                    placement.centerAxis(true);placement.centerAxis(false);break;
                case 16:
                    test.before=placement.bounds;test.press("logoWidthHandle");test.move(400,0);break;
                case 17:
                    test.check(test.close(placement.bounds.height,test.before.height),"width limit never shrinks the height");
                    test.check(test.close(placement.centerX,test.before.x+test.before.width/2) && test.close(placement.centerY,test.before.y+test.before.height/2),"width limit preserves centre");
                    var cappedWidth=placement.bounds.width;test.move(600,0);
                    test.check(test.close(placement.bounds.width,cappedWidth),"further outward movement stops at the width limit");
                    test.release(600,0);break;
                case 18:
                    host.persistSettings({settingsLogoLayout:{zoom:100,width:60,height:25,x:-100,y:0}});break;
                case 19:
                    test.before=placement.bounds;test.press("logoWidthHandle");test.move(20,0);break;
                case 20:
                    test.check(test.close(placement.bounds.width,test.before.width+40),"width continues growing from the left edge");
                    test.check(test.close(placement.bounds.x,placement.edgeMargin),"left edge stays within the viewport with minimum translation");
                    test.check(test.close(placement.bounds.y,test.before.y) && test.close(placement.bounds.height,test.before.height),"horizontal growth leaves the vertical axis unchanged");
                    test.move(40,0);break;
                case 21:
                    test.check(test.close(placement.bounds.width,test.before.width+80) && test.close(placement.bounds.x,placement.edgeMargin),"continued growth does not accumulate position drift");
                    test.move(0,0);break;
                case 22:
                    test.check(test.close(placement.bounds.x,test.before.x) && test.close(placement.bounds.width,test.before.width),"reversing the drag returns to the original size and position");
                    test.move(20,0);test.release(20,0);break;
                case 23:
                    test.check(test.close(placement.bounds.width,test.before.width+40) && test.close(placement.bounds.x,placement.edgeMargin),"release saves the required translation and size together");
                    host.persistSettings({settingsLogoLayout:{zoom:100,width:60,height:25,x:100,y:0}});break;
                case 24:
                    test.before=placement.bounds;test.press("logoWidthHandle");test.move(20,0);break;
                case 25:
                    test.check(test.close(placement.bounds.width,test.before.width+40) && test.close(placement.bounds.x,test.before.x-40),"growth at the right boundary shifts left only as far as needed");
                    test.check(test.close(placement.bounds.height,test.before.height),"opposite-edge growth also preserves height");
                    test.release(20,0);break;
                case 26:
                    host.persistSettings({settingsLogoLayout:{zoom:75,width:80,height:50,x:-100,y:0}});break;
                case 27:
                    test.before=placement.bounds;test.press("logoScaleHandle");test.move(-12,-5);break;
                case 28:
                    test.check(placement.bounds.width>test.before.width && placement.bounds.height>test.before.height,"corner zoom can grow away from an occupied edge");
                    test.check(test.close(placement.bounds.x,placement.edgeMargin),"corner zoom shifts only as far as required");
                    test.check(test.close(placement.bounds.width/placement.bounds.height,test.before.width/test.before.height),"edge-assisted corner zoom keeps proportions");
                    test.move(0,0);break;
                case 29:
                    test.sameSize();test.check(test.close(placement.bounds.x,test.before.x) && test.close(placement.bounds.y,test.before.y),"corner reversal restores the original centre");
                    test.release(0,0);break;
                case 30:
                    host.persistSettings({settingsLogoLayout:{zoom:65,width:90,height:55,x:0,y:0}});
                    placement.centerAxis(false);break;
                case 31:
                    var handle=test.handles[test.handleIndex];
                    var control=test.find(placement,handle.name);
                    test.check(!!control && control.visible,"handle exists: "+handle.name);
                    test.check(test.close(control.parent.x+control.parent.width/2,(handle.x+1)*placement.bounds.width/2)
                        && test.close(control.parent.y+control.parent.height/2,(handle.y+1)*placement.bounds.height/2),"handle matches its edge/corner: "+handle.name);
                    if(handle.x && handle.y) test.check(control.parent.radius===control.parent.width/2,"corner is a round dot");
                    test.before=placement.bounds;test.press(handle.name);test.move(handle.x*8,handle.y*8);break;
                case 32:
                    var handle=test.handles[test.handleIndex];
                    test.check(handle.x ? placement.bounds.width>test.before.width : test.close(placement.bounds.width,test.before.width),"outward width direction: "+handle.name);
                    test.check(handle.y ? placement.bounds.height>test.before.height : test.close(placement.bounds.height,test.before.height),"outward height direction: "+handle.name);
                    test.check(test.close(placement.centerX,test.before.x+test.before.width/2) && test.close(placement.centerY,test.before.y+test.before.height/2),"symmetric resizing: "+handle.name);
                    if(handle.x && handle.y) test.check(test.close(placement.bounds.width/placement.bounds.height,test.before.width/test.before.height),"corner preserves user proportions: "+handle.name);
                    test.move(-handle.x*8,-handle.y*8);break;
                case 33:
                    var handle=test.handles[test.handleIndex];
                    test.check(handle.x ? placement.bounds.width<test.before.width : test.close(placement.bounds.width,test.before.width),"inward width direction: "+handle.name);
                    test.check(handle.y ? placement.bounds.height<test.before.height : test.close(placement.bounds.height,test.before.height),"inward height direction: "+handle.name);
                    test.release(-handle.x*8,-handle.y*8);
                    if(++test.handleIndex<test.handles.length)test.step=30;break;
                case 34:
                    host.persistSettings({settingsLogoLayout:{zoom:25,width:250,height:104.79630608803674,x:0,y:0}});
                    placement.centerArtwork();break;
                case 35:
                    test.before=placement.bounds;test.press("logoWidthHandle");test.move(30,0);break;
                case 36:
                    test.check(test.close(placement.bounds.width,test.before.width+60),"width grows beyond 250 percent at 25 percent zoom");
                    test.check(test.close(placement.bounds.height,test.before.height),"growth beyond numeric cap preserves height");
                    test.move(400,0);break;
                case 37:
                    test.check(test.close(placement.bounds.width,placement.width-2*placement.edgeMargin),"low-zoom width can fill the available area");
                    test.check(test.close(placement.bounds.height,test.before.height),"viewport limit preserves other axis");
                    test.move(0,0);break;
                case 38:
                    test.sameSize();test.move(30,0);test.release(30,0);break;
                case 39:
                    test.check(host.settings.settingsLogoLayout.width>250 && host.settings.settingsLogoLayout.zoom===25,"extended width persists without changing zoom");
                    placement.height=180;
                    host.persistSettings({settingsLogoLayout:{zoom:25,width:250,height:250,x:0,y:0}});
                    placement.centerArtwork();break;
                case 40:
                    test.before=placement.bounds;test.press("logoHeightHandle");test.move(0,10);break;
                case 41:
                    test.check(test.close(placement.bounds.height,test.before.height+20),"height also grows beyond 250 percent");
                    test.check(test.close(placement.bounds.width,test.before.width),"extended height preserves width");
                    test.release(0,10);
                    host.persistSettings({settingsLogoLayout:{zoom:250,width:25,height:25,x:0,y:0}});
                    placement.centerArtwork();break;
                case 42:
                    test.before=placement.bounds;test.press("logoScaleHandle");test.move(-10,-5);break;
                case 43:
                    test.check(placement.bounds.width>test.before.width && placement.bounds.height>test.before.height,"corner can grow beyond 250 percent zoom");
                    test.check(test.close(placement.bounds.width/placement.bounds.height,test.before.width/test.before.height),"extended zoom preserves proportions");
                    test.release(-10,-5);break;
                case 44:
                    console.log("WINDOWPEEK_TEST_PASS logo-placement",test.scale);Qt.quit();break;
                }
            }catch(error){console.error("WINDOWPEEK_TEST_FAIL",test.step,error);Qt.exit(1);}
        }
    }
}
