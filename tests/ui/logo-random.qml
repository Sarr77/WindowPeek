import QtQuick
import QtQuick.Window
import Quickshell
import "WindowPeek" as Plugin
import "WindowPeek/LogoCatalog.js" as Catalog

ShellRoot {
    id: test
    property int step: 0
    property int waits: 0
    property string hoverSource: ""
    property string settingsSource: ""
    property string previewSource: ""
    property var browser: null
    property bool capturing: false
    property bool captured: false
    readonly property var hoverLogo: find(panel,"hoverOmarchyLogo")
    readonly property var settingsLogo: find(panel,"settingsOmarchyLogo")
    function check(ok,text) { if(!ok) throw new Error(text); }
    function wait(ok,text) { if(ok){waits=0;return false;}check(++waits<40,text);step--;return true; }
    function find(item,name) {
        if(!item)return null;
        if(item.objectName===name)return item;
        for(var child of item.children || []) {var found=find(child,name);if(found)return found;}
        return null;
    }
    FakeHost {
        id:host
        settings:({hoverLogoImage:Catalog.randomChoice,settingsLogoImage:Catalog.randomChoice,
            hoverLogoCooldown:60,settingsLogoCooldown:0,settingsLogoReveal:"iris",settingsLogoMotion:"float"})
    }
    Window {
        id:window; visible:true;width:560;height:780
        Plugin.PanelContent { id:panel; x:20;y:20;width:500;height:740;hostWidget:host;visible:opened;expanded:false }
    }
    Timer {
        interval:100;running:true;repeat:true
        onTriggered: {
            try {
                var hover=test.hoverLogo, settings=test.settingsLogo;
                switch(test.step++) {
                case 0: panel.begin();break;
                case 1:
                    if(test.wait(hover.playbackGranted && hover.customImageReady,"first hover GIF loads and plays"))break;
                    test.hoverSource=hover.renderedSource;
                    test.check(!!Catalog.effect(test.hoverSource),"random resolves to a bundled GIF");
                    test.check(test.find(hover,"naturalLogoArt").opacity===0.5,"hover GIF renders with 50% default transparency");
                    test.check(Plugin.Runtime.logoAnimationHistory.hover.source===Catalog.randomChoice,"cooldown identity is the mode, not the random file");
                    panel.expanded=true;break;
                case 2: panel.expanded=false;break;
                case 3:
                    test.check(hover.renderedSource===test.hoverSource,"expanding/collapsing keeps the same GIF");
                    panel.expanded=true;panel.showSettings();break;
                case 4:
                    if(test.wait(settings.playbackGranted && settings.customImageReady,"Settings random GIF loads"))break;
                    test.settingsSource=settings.renderedSource;
                    panel.mode="pictures";break;
                case 5:
                    test.check(!settings.playing,"submenu suspends animation");
                    panel.back();break;
                case 6:
                    test.check(settings.renderedSource===test.settingsSource && settings.playbackGranted,"submenu return resumes the same random choice");
                    host.persistSettings({settingsLogoLayout:{zoom:80},settingsLogoThemeColors:false,settingsLogoOpacity:32});break;
                case 7:
                    test.check(settings.renderedSource===test.settingsSource,"layout and tint edits never reroll");
                    test.check(test.find(settings,"naturalLogoArt").parent.artworkOpacity===32,"manual Settings opacity reaches the renderer");
                    test.check(settings.motion==="float" && settings.reveal==="iris","random GIF leaves chosen effects alone");
                    panel.opened=false;break;
                case 8: panel.begin();panel.expanded=false;break;
                case 9:
                    if(test.wait(hover.customImageReady,"next hover image ready"))break;
                    test.check(hover.renderedSource!==test.hoverSource,"new opening selects another GIF");
                    test.check(!hover.playbackGranted,"new random GIF cannot bypass hover cooldown");
                    panel.showSettings();break;
                case 10:
                    if(test.wait(settings.customImageReady && settings.playbackGranted,"new Settings visit starts"))break;
                    test.check(settings.renderedSource!==test.settingsSource,"new Settings visit selects another GIF");
                    test.check(test.find(settings,"naturalLogoArt").parent.artworkOpacity===32,"random selection preserves manual opacity");
                    host.persistSettings({settingsLogoCooldown:60});
                    panel.mode="windows";panel.showSettings();break;
                case 11:
                    if(test.wait(settings.customImageReady,"blocked Settings image ready"))break;
                    test.check(!settings.playbackGranted,"random respects Settings cooldown too");
                    test.settingsSource=settings.renderedSource;
                    panel.mode="pictures";break;
                case 12: panel.back();break;
                case 13:
                    test.check(settings.renderedSource===test.settingsSource && !settings.playbackGranted,"submenu cannot bypass denied cooldown or reroll");
                    panel.mode="pictures";find(panel,"settingsLogoPicker").clicked();break;
                case 14:
                    test.browser=find(panel,"logoSettings").activePopup;
                    if(test.wait(test.browser && test.browser.visible,"random chooser opens"))break;
                    if(test.wait(!!Catalog.effect(test.browser.previewSource),"random preview resolves"))break;
                    test.previewSource=test.browser.previewSource;
                    test.browser.replay();break;
                case 15:
                    test.check(test.browser.previewSource===test.previewSource,"effect replay keeps the chosen GIF");
                    test.browser.select(Catalog.randomChoice);break;
                case 16:
                    if(test.wait(find(window.contentItem,"logoLibraryPreview").status===Image.Ready,"next GIF preview loads"))break;
                    test.check(test.browser.previewSource!==test.previewSource,"Next GIF rerolls only the preview");
                    test.check(settings.renderedSource===test.settingsSource,"browser does not reroll panel artwork");
                    test.browser.select("builtin:ttfx-rain");test.browser.close();break;
                case 17:
                    test.check(host.settingsLogoImage===Catalog.randomChoice,"Cancel preserves random mode");
                    find(panel,"settingsLogoPicker").clicked();test.browser.select("builtin:ttfx-rain");break;
                case 18:
                    if(test.wait(find(window.contentItem,"logoLibraryPreview").status===Image.Ready,"specific preview ready"))break;
                    find(window.contentItem,"applyLogoChoice").clicked();break;
                case 19:
                    test.check(host.settingsLogoImage==="builtin:ttfx-rain","explicit GIF replaces random mode");
                    find(panel,"settingsLogoPicker").clicked();find(window.contentItem,"logoRandomChoice").clicked();break;
                case 20:
                    if(test.wait(find(window.contentItem,"logoLibraryPreview").status===Image.Ready,"random preview ready for Apply"))break;
                    test.check(test.browser.contentItem.implicitHeight<=test.browser.availableHeight+1,"random chooser fits without overlap");
                    if(Quickshell.env("WINDOWPEEK_TEST_IMAGE") && !test.captured) {
                        if(!test.capturing) {
                            test.capturing=true;
                            window.contentItem.grabToImage(function(result) {
                                test.captured=result.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE"));
                            });
                        }
                        if(test.wait(test.captured,"chooser screenshot saved"))break;
                    }
                    find(window.contentItem,"applyLogoChoice").clicked();break;
                case 21:
                    test.check(host.settingsLogoImage===Catalog.randomChoice,"Apply saves random mode, never the preview filename");
                    test.check(host.settings.settingsLogoReveal==="iris" && host.settings.settingsLogoMotion==="float","Apply preserves effects independently");
                    console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            }catch(error){console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error);stop();Qt.quit();}
        }
    }
}
