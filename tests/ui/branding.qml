import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import QtTest
import Quickshell
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    property int waits: 0
    property real originalHeight: 0
    property int gifFrames: 0
    property int stoppedFrames: 0
    property real glintBefore: 0
    property int pauseTicks: 0
    readonly property var gifLogo: named("settingsOmarchyLogo") ? find(named("settingsOmarchyLogo"), "customPanelLogo") : null
    Connections { target: test.gifLogo; function onCurrentFrameChanged() { test.gifFrames++; } }
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(ok, text) { if (!ok) throw new Error(text); }
    function wait(ok,text) { if(ok) { waits=0;return false; } if(++waits>15) throw new Error(text);step--;return true; }
    function find(item,name) {
        if(!item) return null;
        if(item.objectName===name) return item;
        for(var c of item.children || []) { var found=find(c,name);if(found) return found; } return null;
    }
    function named(name) { return find(panel,name); }
    function point(item) { return item.mapToItem(window.contentItem,item.width/2,item.height/2); }
    function hover(item) { var p=point(item);events.mouseMove(window.contentItem,p.x,p.y,0,Qt.NoButton,Qt.NoModifier); }
    function click(item) { panel.ensureVisible(item);events.mouseClick(item,item.width/2,item.height/2,Qt.LeftButton,Qt.NoModifier,0); }
    TestEvent { id: events }
    FakeHost { id: host; settings:({hintsMode:"auto",hintsUsed:98,windowPreviews:false,hoverLogoLoopDelay:0,settingsLogoLoopDelay:0}) }
    Window {
        id: window; visible:true; width:560*test.scale; height:760*test.scale
        Plugin.PanelContent {
            id:panel; x:20*test.scale;y:20*test.scale;width:500;height:700
            scale:test.scale;transformOrigin:Item.TopLeft;hostWidget:host;expanded:false;expansion:0
        }
        Binding { target: panel.QQC.Overlay.overlay; property: "transformOrigin"; value: Item.TopLeft }
        Binding { target: panel.QQC.Overlay.overlay; property: "scale"; value: test.scale }
    }
    Timer {
        interval:200;repeat:true;running:true
        onTriggered: {
            try {
                switch(test.step++) {
                case 0: panel.begin(false);test.originalHeight=panel.implicitHeight;test.hover(test.named("hoverOmarchyLogo"));break;
                case 1:
                    if(test.wait(test.find(test.named("hoverOmarchyLogo"),"logoHint").visible,"logo has its own tooltip")) break;
                    test.check(host.hints.used===99 && !test.named("backgroundInstructions").visible,"logo help counts once without showing background instructions");
                    test.check(test.find(test.named("hoverOmarchyLogo"),"logoHint").statusText.indexOf("1")>=0,"logo shows remaining automatic displays");
                    events.mouseMove(panel,2,2,0,Qt.NoButton,Qt.NoModifier);break;
                case 2:
                    if(test.wait(test.named("backgroundInstructions").visible,"empty panel background shows instructions")) break;
                    test.check(host.hints.used===100,"background help counts once");
                    test.check(panel.implicitHeight===test.originalHeight,"instructions take no layout space");
                    test.hover(test.named("windowFocus"));break;
                case 3:
                    test.check(!test.named("backgroundInstructions").visible,"rows exclude background help");
                    events.mouseMove(panel,2,2,0,Qt.NoButton,Qt.NoModifier);break;
                case 4:
                    test.check(!test.named("backgroundInstructions").visible,"automatic help stops after 100 displays");
                    test.hover(test.named("hoverOmarchyLogo"));
                    test.check(!test.find(test.named("hoverOmarchyLogo"),"logoHint").eligible,"logo help also stops at the automatic limit");
                    panel.expanded=true;panel.expansion=1;panel.showSettings();break;
                case 5:
                    test.check(test.named("settingsOmarchyLogo").visible,"Settings logo enabled by default");
                    test.named("settingsPersonalizationSection").expanded=true;panel.mode="pictures";break;
                case 6:
                    test.check(test.named("hoverLogoToggle").visible && test.named("settingsLogoToggle").visible,"both switches in Pictures and Gifs");
                    test.click(test.named("hoverLogoToggle"));test.click(test.named("settingsLogoToggle"));break;
                case 7:
                    test.check(!host.hoverLogo && !host.settingsLogo && !test.named("settingsBranding").visible,"both logos can be disabled independently");
                    test.named("logoSettings").choose(Qt.resolvedUrl("dropdown-wallpaper.svg"));break;
                case 8:
                    if(test.wait(host.settingsLogoImage!=="","Settings image selection saves")) break;
                    test.click(test.named("settingsLogoToggle"));test.click(test.named("hoverLogoToggle"));
                    test.named("settingsPersonalizationSection").expanded=false;panel.mode="settings";break;
                case 9:
                    if(test.wait(test.named("settingsOmarchyLogo").customImageReady,"custom image appears in Settings")) break;
                    panel.mode="windows";panel.expanded=false;panel.expansion=0;break;
                case 10:
                    test.check(!test.named("hoverOmarchyLogo").customImageReady && host.hoverLogoImage === "", "Settings image leaves compact logo untouched");
                    host.persistSettings({hintsMode:"on"});events.mouseMove(panel,2,2,0,Qt.NoButton,Qt.NoModifier);break;
                case 11:
                    if(test.wait(test.named("backgroundInstructions").visible,"manual hints work after budget")) break;
                    test.check(host.hints.used===100,"manual help does not reset the budget");
                    host.persistSettings({hintsMode:"off"});test.hover(test.named("hoverOmarchyLogo"));
                    test.check(!test.find(test.named("hoverOmarchyLogo"),"logoHint").eligible,"manual off disables logo help");
                    host.persistSettings({hintsMode:"on"});
                    panel.expanded=true;panel.expansion=1;panel.showSettings();test.named("settingsPersonalizationSection").expanded=true;panel.mode="pictures";break;
                case 12:
                    test.named("settingsLogoPicker").changed("builtin:omarchy-pixel");
                    test.named("settingsPersonalizationSection").expanded=false;panel.mode="settings"; break;
                case 13:
                    test.check(host.settingsLogoImage==="builtin:omarchy-pixel" && host.hoverLogoImage==="", "animated preset is independent");
                    test.glintBefore=test.find(test.named("settingsOmarchyLogo"),"pixelPanelLogo").progress;break;
                case 14:
                    test.check(test.find(test.named("settingsOmarchyLogo"),"pixelPanelLogo").progress>test.glintBefore,"visible pixel glint advances");
                    test.named("logoSettings").choose(Qt.resolvedUrl("animated-logo.gif"),"settings"); break;
                case 15:
                    if(test.wait(host.settingsLogoImage.endsWith("animated-logo.gif") && test.gifLogo.status===Image.Ready,"GIF decodes"))break;
                    test.gifFrames=0;break;
                case 16:
                    if(test.wait(test.gifFrames>0,"GIF advances frames"))break;
                    panel.mode="windows";break;
                case 17: test.stoppedFrames=test.gifFrames;break;
                case 18:
                    test.check(test.gifFrames===test.stoppedFrames,"hidden Settings GIF stops playing");
                    test.named("logoSettings").choose(Qt.resolvedUrl("dropdown-wallpaper.svg"),"hover");break;
                case 19:
                    if(test.wait(host.hoverLogoImage!=="","compact image saves independently"))break;
                    test.check(host.settingsLogoImage.endsWith("animated-logo.gif"),"compact choice preserves Settings GIF");
                    panel.mode="settings";test.named("settingsPersonalizationSection").expanded=true;panel.mode="pictures";
                    test.named("settingsLogoPicker").changed("");break;
                case 20:
                    test.check(host.settingsLogoImage==="" && host.hoverLogoImage!=="","reset changes only one logo");
                    test.named("hoverLogoPicker").changed("image");break;
                case 21:
                    test.check(test.named("logoSettings").picking,"custom image option opens picker");
                    var path=test.find(window.contentItem,"logoFolderPath");
                    path.text=Quickshell.env("WINDOWPEEK_TEST_PROFILE");path.accepted();break;
                case 22:
                    var files=test.find(window.contentItem,"logoFileList");
                    test.check(files.model.indexOf(Qt.resolvedUrl("animated-logo.gif"))>=0,"picker lists GIF files");
                    events.keyClick(Qt.Key_Escape,Qt.NoModifier,0);break;
                case 23:
                    test.check(!test.named("logoSettings").picking && host.hoverLogoImage.endsWith("dropdown-wallpaper.svg"),"cancel preserves compact image");
                    host.persistSettings({hoverLogoImage:"",settingsLogoImage:"builtin:omarchy-pixel"});
                    test.named("settingsPersonalizationSection").expanded=false;panel.mode="settings"; break;
                case 24:
                    var target=test.named("settingsOmarchyLogo");
                    if(Quickshell.env("WINDOWPEEK_TEST_IMAGE")) window.contentItem.grabToImage(function(image) {
                        image.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE")); window.visible=false;
                    });
                    else window.visible=false;
                    break;
                case 25:
                    test.check(!test.find(test.named("settingsOmarchyLogo"),"pixelPanelLogo").animating,"window hidden stops built-in animation");
                    window.visible=true;
                    test.named("settingsPersonalizationSection").expanded=true;panel.mode="pictures";
                    host.persistSettings({hoverLogoImage:"builtin:omarchy-pixel",settingsLogoImage:String(Qt.resolvedUrl("animated-logo.gif"))}); break;
                case 26:
                    test.check(test.named("hoverLogoLoopToggle").visible && test.named("settingsLogoLoopToggle").visible,"both animated choices expose a mini playback switch");
                    panel.ensureVisible(test.named("logoSettings"));
                    if(Quickshell.env("WINDOWPEEK_TEST_IMAGE")) panel.grabToImage(function(image) {
                        image.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE")+".loops.png");
                    });
                    break;
                case 27:
                    test.click(test.named("settingsLogoLoopToggle"));
                    test.check(!host.settingsLogoLoop && host.hoverLogoLoop,"Settings playback changes independently");
                    test.click(test.named("hoverLogoLoopToggle"));
                    test.check(!host.hoverLogoLoop && !host.settingsLogoLoop,"compact playback can also play once");
                    test.named("settingsPersonalizationSection").expanded=false;panel.mode="settings";
                    panel.mode="windows";panel.expanded=false;panel.expansion=0;break;
                case 28:
                    var pixel=test.find(test.named("hoverOmarchyLogo"),"pixelPanelLogo");
                    if(test.wait(pixel.progress===1 && !pixel.animating,"pixel animation finishes after one sweep"))break;
                    window.visible=false;break;
                case 29:
                    window.visible=true;
                    test.check(test.find(test.named("hoverOmarchyLogo"),"pixelPanelLogo").progress===0,"showing the logo again restarts its single sweep");
                    break;
                case 30:
                    test.check(test.find(test.named("hoverOmarchyLogo"),"pixelPanelLogo").animating,"single sweep plays again after reopening");
                    panel.expanded=true;panel.expansion=1;panel.mode="settings";break;
                case 31:
                    if(test.wait(test.gifLogo.finished && !test.gifLogo.animating,"single-play GIF pauses on its final frame"))break;
                    test.stoppedFrames=test.gifFrames;test.pauseTicks=0;break;
                case 32:
                    test.check(test.gifFrames===test.stoppedFrames,"single-play GIF does not wrap to the first frame");
                    if(++test.pauseTicks<4){test.step--;break;}
                    window.visible=false;break;
                case 33:
                    window.visible=true;
                    test.check(test.gifLogo.currentFrame===0 && !test.gifLogo.finished,"single-play GIF restarts from its first frame when shown");
                    break;
                case 34:
                    if(test.wait(test.gifLogo.finished,"reopened GIF completes once again"))break;
                    test.named("settingsPersonalizationSection").expanded=true;panel.mode="pictures";
                    test.step=38;break;
                case 38:
                    test.click(test.named("settingsLogoLoopToggle"));
                    test.check(host.settingsLogoLoop && !host.hoverLogoLoop,"looping can be restored independently");
                    test.named("logoSettings").choose(Qt.resolvedUrl("single-play-logo.gif"),"settings");test.step=35;break;
                case 35:
                    if(test.wait(host.settingsLogoImage.endsWith("single-play-logo.gif"),"finite GIF loads"))break;
                    test.named("settingsPersonalizationSection").expanded=false;panel.mode="settings";
                    test.gifFrames=0;test.pauseTicks=0;break;
                case 36:
                    if(++test.pauseTicks<5){test.step--;break;}
                    test.check(test.gifFrames>5 && !test.gifLogo.finished,"loop switch repeats even a GIF encoded to play once");
                    test.named("settingsPersonalizationSection").expanded=true;panel.mode="pictures";
                    test.named("hoverLogoPicker").changed("");break;
                case 37:
                    test.check(!test.named("hoverLogoLoopToggle").visible && test.named("settingsLogoLoopToggle").visible,"static logo hides only its own playback switch");
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            } catch(error) { console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error);stop();Qt.quit(); }
        }
    }
}
