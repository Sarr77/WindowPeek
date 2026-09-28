import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import QtTest
import Quickshell
import "WindowPeek" as Plugin
import "WindowPeek/LogoCatalog.js" as Catalog
import "WindowPeek/Appearance.js" as Appearance

ShellRoot {
    id: test
    property int step: 0
    property int waits: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    property int effectIndex: 0
    property bool captured: false
    property rect beforeCenter
    property point cornerOrigin
    property var browser: null
    function check(ok, text) { if (!ok) throw new Error(text); }
    function wait(ok, text) { if (ok) {waits=0;return false;} if(++waits>25)throw new Error(text); step--;return true; }
    function find(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (var c of item.children || []) { var found = find(c,name); if(found) return found; } return null;
    }
    function named(name) { return find(window.contentItem,name); }
    TestEvent { id: events }
    FakeHost { id: host; Component.onCompleted:savedAppearance=Appearance.normalize({uiScale:test.scale}) }
    Window {
        id: window; visible:true; width:560*test.scale; height:760*test.scale
        Plugin.PanelContent {
            id: panel; x:20*test.scale; y:20*test.scale; width:500; height:700
            scale:test.scale; transformOrigin:Item.TopLeft; hostWidget:host
        }
        Binding { target: panel.QQC.Overlay.overlay; property:"transformOrigin";value:Item.TopLeft }
        Binding { target: panel.QQC.Overlay.overlay; property:"scale";value:test.scale }
    }
    Timer {
        interval:140; repeat:true; running:true
        onTriggered: {
            try {
                var browser = test.browser;
                switch(test.step++) {
                case 0: panel.begin(true);panel.showSettings();panel.mode="pictures";break;
                case 1: test.named("settingsLogoPicker").clicked();break;
                case 2:
                    test.browser = test.named("logoSettings").activePopup; browser = test.browser;
                    test.check(browser && browser.visible,"library opens");
                    test.check(browser.entries.length===37,"all 37 authentic effects available");
                    test.check(browser.width>0 && browser.height>0,"bounded browser");
                    test.check(browser.contentItem.implicitHeight<=browser.availableHeight+1,"chooser controls fit without covering the preview or actions");
                    var previewRoot=test.named("logoLibraryPreview");
                    var natural=test.find(previewRoot,"naturalLogoArt");
                    test.check(Math.abs(natural.width/natural.height-1215/285)<0.001,"original preview preserves Settings aspect");
                    browser.select("builtin:omarchy-pixel");
                    test.check(browser.artworkOpacity===100,"pixel wordmark keeps its original translucency");
                    test.check(Math.abs(natural.width/natural.height-1215/285)<0.001,"pixel preview preserves Settings aspect");
                    test.named("logoLibrarySearch").text="laser";break;
                case 3:
                    test.check(browser.entries.length===1 && browser.entries[0].source==="builtin:ttfx-laseretch","search filters effects");
                    browser.select(browser.entries[0].source);break;
                case 4:
                    if(test.wait(test.named("logoLibraryPreview").status===Image.Ready,"selected animation decodes"))break;
                    test.check(host.settingsLogoImage==="","browsing never changes saved source");
                    test.check(browser.artworkOpacity===50,"switching from pixel to a GIF uses the GIF default");
                    var opacitySlider=test.named("logoTransparencySlider");opacitySlider.value=38;opacitySlider.moved();
                    test.check(browser.artworkOpacity===62 && test.named("logoLibraryPreview").artworkOpacity===62,"transparency previews on artwork only");
                    test.check(host.settings.settingsLogoOpacity===undefined,"opacity remains a draft until Apply");
                    browser.reveal="pixels";browser.motion="float";
                    browser.replay();
                    test.check(test.find(test.named("logoLibraryPreview"),"naturalLogoArt").opacity===0,"Replay masks the image before its deferred restart");
                    host.rejectSave=true;test.named("applyLogoChoice").clicked();break;
                case 5:
                    test.check(browser.visible && browser.error!=="" && host.settingsLogoImage==="","failed save retains draft and shows error");
                    host.rejectSave=false;test.named("applyLogoChoice").clicked();break;
                case 6:
                    test.check(!browser.visible && host.settingsLogoImage==="builtin:ttfx-laseretch","Apply persists only selected target");
                    test.check(host.settings.settingsLogoOpacity===62 && host.settings.hoverLogoOpacity===undefined,"opacity saves independently for one view");
                    test.check(host.settings.settingsLogoReveal==="pixels" && host.settings.settingsLogoMotion==="float" && !host.settings.hoverLogoReveal,"effect and motion persist independently for the selected target");
                    test.check(host.hoverLogoImage==="","independent compact source");
                    test.named("settingsLogoPicker").clicked();break;
                case 7:
                    test.check(browser.reveal==="pixels","saved opening effect restored in chooser");
                    test.check(browser.artworkOpacity===62,"saved opacity restored in chooser");
                    test.named("logoTransparencyReset").clicked();
                    test.check(browser.artworkOpacity===50 && browser.opacityOverride===null,"opacity reset follows the GIF default");
                    browser.select("builtin:ttfx-waves");browser.reveal="scatter";browser.close();break;
                case 8:
                    test.check(host.settingsLogoImage==="builtin:ttfx-laseretch","Cancel leaves selection unchanged");
                    test.check(host.settings.settingsLogoOpacity===62,"Cancel also preserves saved opacity");
                    test.check(host.settings.settingsLogoReveal==="pixels","Cancel leaves opening effect unchanged");
                    test.named("settingsLogoSourceReset").resetRequested();break;
                case 9:
                    test.check(host.settingsLogoImage===Catalog.randomChoice,"default random animation remains restorable");
                    test.check(host.settings.settingsLogoOpacity===null,"full artwork reset restores automatic opacity");
                    test.check(host.settings.settingsLogoReveal==="none" && host.settings.settingsLogoMotion==="none","original reset also removes applied effects");
                    test.named("settingsLogoPicker").clicked();browser.select(String(Qt.resolvedUrl("animated-logo.gif")));browser.filesTab=true;break;
                case 10:
                    if(test.wait(test.named("logoLibraryPreview").status===Image.Ready,"custom animation preview"))break;
                    test.check(browser.artworkOpacity===50,"custom GIF also starts at half opacity");
                    browser.reveal="scatter";
                    test.named("applyLogoChoice").clicked();break;
                case 11:
                    test.check(host.settingsLogoImage.endsWith("animated-logo.gif") && host.settings.logoRecentFiles.length===1,"custom source remembered after Apply");
                    test.check(host.settings.settingsLogoOpacity===null,"accepting a default does not turn it into a manual override");
                    test.check(host.settings.settingsLogoReveal==="scatter","opening effect works with a custom GIF");
                    test.named("settingsLogoPicker").clicked();browser.select("file:///definitely-missing-windowpeek.gif");break;
                case 12:
                    if(test.wait(test.named("logoLibraryPreview").status===Image.Error,"missing image reports error"))break;
                    test.check(!test.named("applyLogoChoice").enabled,"invalid image cannot be applied");
                    test.named("logoLibrarySearch").text="";browser.filesTab=false;browser.select("builtin:ttfx-"+Catalog.effects[0][0]);break;
                case 13:
                    if(test.wait(test.named("logoLibraryPreview").status===Image.Ready,"effect decodes: "+Catalog.effects[test.effectIndex][0]))break;
                    if(++test.effectIndex<Catalog.effects.length) { browser.select("builtin:ttfx-"+Catalog.effects[test.effectIndex][0]);test.step--; }
                    break;
                case 14:
                    browser.select(Quickshell.env("WINDOWPEEK_TEST_LOGO_PREVIEW") || "builtin:ttfx-highlight");browser.previewPlaying=false;test.named("logoLibrarySearch").text="";
                    break;
                case 15:
                    if(!test.captured) {
                        if(test.wait(!Catalog.effect(browser.selection) || test.named("logoLibraryPreview").posterReady,"still preview ready"))break;
                        test.captured=true;
                        if(Quickshell.env("WINDOWPEEK_TEST_IMAGE")) window.contentItem.grabToImage(function(r){r.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE"));});
                        test.step--;break;
                    }
                    browser.close();panel.mode="settings";panel.forceActiveFocus();events.keyPress(Qt.Key_Control,Qt.ControlModifier,0);break;
                case 16:
                    test.check(test.named("logoMoveHandle").visible,"Ctrl shows move and resize controls");
                    if(Quickshell.env("WINDOWPEEK_TEST_IMAGE")) window.contentItem.grabToImage(function(r){r.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE")+".placement.png");});
                    var handle = test.named("logoMoveHandle");
                    events.mousePress(handle, handle.width/2, handle.height/2, Qt.LeftButton, Qt.ControlModifier, 0);
                    events.mouseMove(handle, handle.width/2 + 20, handle.height/2 - 10, 0, Qt.LeftButton, Qt.ControlModifier);
                    events.mouseRelease(handle, handle.width/2 + 20, handle.height/2 - 10, Qt.LeftButton, Qt.ControlModifier, 0);
                    test.check(host.settings.settingsLogoLayout.x !== 0, "dragging saves position on release");
                    test.named("resetLogoPlacement").clicked();
                    test.check(host.settings.settingsLogoLayout.zoom===100,"direct reset persists default layout");
                    var rectangle = test.named("logoPlacementBounds");
                    var center = Qt.point(rectangle.x+rectangle.width/2, rectangle.y+rectangle.height/2);
                    var stretch = test.named("logoWidthHandle");
                    events.mousePress(stretch, stretch.width/2, stretch.height/2, Qt.LeftButton, Qt.ControlModifier, 0);
                    events.mouseMove(stretch, stretch.width/2 + 15, stretch.height/2, 0, Qt.LeftButton, Qt.ControlModifier);
                    events.mouseRelease(stretch, stretch.width/2 + 15, stretch.height/2, Qt.LeftButton, Qt.ControlModifier, 0);
                    test.check(host.settings.settingsLogoLayout.width>100 && host.settings.settingsLogoLayout.height===100,"width handle stretches only width");
                    test.named("resetLogoPlacement").clicked();
                    stretch = test.named("logoHeightHandle");
                    events.mousePress(stretch, stretch.width/2, stretch.height/2, Qt.LeftButton, Qt.ControlModifier, 0);
                    events.mouseMove(stretch, stretch.width/2, stretch.height/2 + 8, 0, Qt.LeftButton, Qt.ControlModifier);
                    events.mouseRelease(stretch, stretch.width/2, stretch.height/2 + 8, Qt.LeftButton, Qt.ControlModifier, 0);
                    test.check(host.settings.settingsLogoLayout.height>100 && host.settings.settingsLogoLayout.width===100,"dragging the bottom handle downward increases only height");
                    test.check(Math.abs(rectangle.x+rectangle.width/2-center.x)<0.01 && Math.abs(rectangle.y+rectangle.height/2-center.y)<0.01,"axis resizing keeps the centre fixed");
                    test.named("resetLogoPlacement").clicked();
                    break;
                case 17:
                    var wheelHandle=test.named("logoMoveHandle");
                    test.check(events.mouseWheel(wheelHandle, wheelHandle.width/2, wheelHandle.height/2, Qt.NoButton, Qt.ControlModifier, 0, 120, 0), "wheel delivered");break;
                case 18: break;
                case 19: break;
                case 20:
                    test.check(host.settings.settingsLogoLayout.zoom>100,"Ctrl wheel saves zoom after settling: " + JSON.stringify(host.settings.settingsLogoLayout) + " editing="+panel.logoControlHeld);
                    events.keyRelease(Qt.Key_Control,Qt.NoModifier,0);
                    test.check(!test.named("logoMoveHandle").visible,"releasing Ctrl hides editing controls");
                    host.persistSettings({settingsLogoImage:"",settingsLogoMotion:"pulse"});break;
                case 21:
                    test.check(test.named("settingsOmarchyLogo").playbackGranted,"motion works with original static logo");
                    panel.mode="pictures";
                    // The arrow is actionable even with the default source and
                    // only a layout override. Use the actual click guard.
                    for (var place of ["hover", "settings"]) {
                        var prefix=place+"Logo", other=place==="hover" ? "settingsLogo" : "hoverLogo";
                        var defaults=Catalog.artworkDefaults(place);
                        host.persistSettings(defaults);
                        var values={};values[prefix+"Layout"]={zoom:85,width:125,height:60,x:15,y:-20};
                        values[other+"Layout"]={zoom:75,width:130,height:90,x:-8,y:12};
                        host.persistSettings(values);
                        var reset=test.named(prefix+"SourceReset"), before=JSON.stringify(host.settings);
                        test.check(reset.modified,"layout-only customization enables reset: "+place);
                        host.rejectSave=true;reset.clicked();host.rejectSave=false;
                        test.check(JSON.stringify(host.settings)===before && reset.modified,"failed reset preserves all preferences");
                        reset.clicked();
                        test.check(JSON.stringify(host.settings[prefix+"Layout"])===JSON.stringify(Catalog.layout({})) && !reset.modified,"arrow resets layout and returns to default state: "+place);
                        test.check(host.settings[other+"Layout"].zoom===75,"reset leaves the other view alone");
                        values={};values[prefix+"Image"]="builtin:omarchy-pixel";values[prefix+"ThemeColors"]=false;
                        values[prefix+"Motion"]="pulse";values[prefix+"Reveal"]="iris";values[prefix+"Opacity"]=23;
                        values[prefix+"Loop"]=false;values[prefix+"LoopDelay"]=9;values[prefix+"Cooldown"]=120;values[prefix+"CooldownUnit"]="min";
                        host.persistSettings(values);reset.clicked();
                        for(var key of Object.keys(defaults)) test.check(JSON.stringify(host.settings[key])===JSON.stringify(defaults[key]),"full artwork reset: "+key);
                        test.check(!reset.modified,"complete reset clears modified state");
                    }
                    host.persistSettings({settingsLogoLayout:{zoom:85,width:120,height:140,x:8,y:-5}});
                    panel.mode="settings";panel.forceActiveFocus();events.keyPress(Qt.Key_Control,Qt.ControlModifier,0);break;
                case 22:
                    var rectangle=test.named("logoPlacementBounds");
                    test.beforeCenter=Qt.rect(rectangle.x,rectangle.y,rectangle.width,rectangle.height);
                    var handle=test.named("logoWidthHandle");
                    var saved=JSON.stringify(host.settings.settingsLogoLayout);
                    test.check(events.mouseClick(handle,handle.width/2,handle.height/2,Qt.LeftButton,Qt.ControlModifier,0),"single click delivered");
                    test.check(JSON.stringify(host.settings.settingsLogoLayout)===saved,"single click leaves handle in place for double-click");
                    test.check(events.mouseDoubleClickSequence(handle,handle.width/2,handle.height/2,Qt.LeftButton,Qt.ControlModifier,20),"width handle double-click delivered");break;
                case 23:
                    var rectangle=test.named("logoPlacementBounds");
                    var saved=host.settings.settingsLogoLayout;
                    test.check(Math.abs(rectangle.x+rectangle.width/2-rectangle.parent.width/2)<0.01,"right handle centers horizontally");
                    test.check(Math.abs(rectangle.y-test.beforeCenter.y)<0.01 && saved.y===-5,"horizontal centering leaves vertical position alone");
                    test.check(saved.zoom===85 && saved.width===120 && saved.height===140,"centering preserves chosen size and proportions");
                    test.check(Math.abs(rectangle.width-test.beforeCenter.width)<0.01 && Math.abs(rectangle.height-test.beforeCenter.height)<0.01,"centering does not resize artwork");
                    var handle=test.named("logoHeightHandle");
                    events.mousePress(handle,handle.width/2,handle.height/2,Qt.LeftButton,Qt.ControlModifier,0);
                    events.mouseMove(handle,handle.width/2+1,handle.height/2-1,0,Qt.LeftButton,Qt.ControlModifier);
                    events.mouseRelease(handle,handle.width/2+1,handle.height/2-1,Qt.LeftButton,Qt.ControlModifier,0);
                    test.check(host.settings.settingsLogoLayout.y===-5,"pointer jitter is not a resize or centering action");
                    events.mouseDoubleClickSequence(handle,handle.width/2,handle.height/2,Qt.LeftButton,Qt.ControlModifier,20);break;
                case 24:
                    var rectangle=test.named("logoPlacementBounds");
                    var saved=host.settings.settingsLogoLayout;
                    test.check(Math.abs(rectangle.y+rectangle.height/2-rectangle.parent.height/2)<0.01,"bottom handle centers vertically despite small pointer jitter");
                    test.check(saved.x===0 && saved.zoom===85 && saved.width===120 && saved.height===140,"vertical centering preserves other values");
                    test.check(Math.abs(rectangle.width-test.beforeCenter.width)<0.01 && Math.abs(rectangle.height-test.beforeCenter.height)<0.01,"vertical centering preserves rendered size");
                    host.persistSettings({settingsLogoLayout:{zoom:85,width:120,height:140,x:8,y:-5}});break;
                case 25:
                    var handle=test.named("logoWidthHandle");
                    events.mousePress(handle,handle.width/2,handle.height/2,Qt.LeftButton,Qt.ControlModifier,0);
                    events.mouseMove(handle,handle.width/2+15,handle.height/2,0,Qt.LeftButton,Qt.ControlModifier);
                    events.mouseRelease(handle,handle.width/2+15,handle.height/2,Qt.LeftButton,Qt.ControlModifier,0);
                    test.check(host.settings.settingsLogoLayout.width>120 && host.settings.settingsLogoLayout.x===8 && host.settings.settingsLogoLayout.y===-5,"drag release stretches without also centering");
                    host.persistSettings({settingsLogoLayout:{zoom:75,width:130,height:160,x:4,y:-12}});break;
                case 26:
                    var rectangle=test.named("logoPlacementBounds");
                    test.beforeCenter=Qt.rect(rectangle.x,rectangle.y,rectangle.width,rectangle.height);
                    var handle=test.named("logoScaleHandle");
                    test.check(handle.visible,"Ctrl shows the proportional corner handle");
                    var saved=JSON.stringify(host.settings.settingsLogoLayout);
                    events.mouseClick(handle,handle.width/2,handle.height/2,Qt.LeftButton,Qt.ControlModifier,0);
                    test.check(JSON.stringify(host.settings.settingsLogoLayout)===saved,"corner click does not reset or center");
                    test.cornerOrigin=handle.mapToItem(window.contentItem,handle.width/2,handle.height/2);
                    events.mousePress(window.contentItem,test.cornerOrigin.x,test.cornerOrigin.y,Qt.LeftButton,Qt.ControlModifier,0);
                    events.mouseMove(window.contentItem,test.cornerOrigin.x-18*test.scale,test.cornerOrigin.y-8*test.scale,0,Qt.LeftButton,Qt.ControlModifier);break;
                case 27:
                    var rectangle=test.named("logoPlacementBounds");
                    test.check(rectangle.width>test.beforeCenter.width && rectangle.height>test.beforeCenter.height,"corner outward drag enlarges both dimensions");
                    test.check(Math.abs(rectangle.width/rectangle.height-test.beforeCenter.width/test.beforeCenter.height)<0.001,"corner drag preserves custom stretched proportions");
                    test.check(Math.abs(rectangle.x+rectangle.width/2-test.beforeCenter.x-test.beforeCenter.width/2)<0.01 && Math.abs(rectangle.y+rectangle.height/2-test.beforeCenter.y-test.beforeCenter.height/2)<0.01,"corner drag grows around the fixed center");
                    test.check(host.settings.settingsLogoLayout.zoom===75,"corner drag does not save on every move");
                    events.mouseMove(window.contentItem,test.cornerOrigin.x+18*test.scale,test.cornerOrigin.y+8*test.scale,0,Qt.LeftButton,Qt.ControlModifier);break;
                case 28:
                    var rectangle=test.named("logoPlacementBounds");
                    test.check(rectangle.width<test.beforeCenter.width && rectangle.height<test.beforeCenter.height,"same corner gesture reverses to shrink");
                    test.check(Math.abs(rectangle.width/rectangle.height-test.beforeCenter.width/test.beforeCenter.height)<0.001,"shrinking retains custom proportions");
                    test.check(Math.abs(rectangle.x+rectangle.width/2-test.beforeCenter.x-test.beforeCenter.width/2)<0.01 && Math.abs(rectangle.y+rectangle.height/2-test.beforeCenter.y-test.beforeCenter.height/2)<0.01,"shrinking retains center");
                    events.mouseRelease(window.contentItem,test.cornerOrigin.x+18*test.scale,test.cornerOrigin.y+8*test.scale,Qt.LeftButton,Qt.ControlModifier,0);
                    var saved=host.settings.settingsLogoLayout;
                    test.check(saved.zoom<75 && saved.width===130 && saved.height===160 && saved.x===4 && saved.y===-12,"corner release saves only proportional zoom");
                    events.keyRelease(Qt.Key_Control,Qt.NoModifier,0);
                    console.log("WINDOWPEEK_TEST_PASS", "logo-library", test.scale);Qt.quit();break;
                }
            } catch(e) { console.error("WINDOWPEEK_TEST_FAIL",test.step,e);Qt.exit(1); }
        }
    }
}
