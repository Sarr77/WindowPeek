import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "HostBar" as Host
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance

// Use the production layer surface: a plain Window does not reproduce its
// content-item ownership and transforms. Run in a private compositor.
ShellRoot {
    id: test
    property int step: -5
    property int waits: 0
    property bool finished: false
    readonly property bool protectedMode: Quickshell.env("WP_CASE").indexOf("protected") >= 0
    readonly property bool outsideCase: Quickshell.env("WP_CASE").indexOf("outside") >= 0
    readonly property var widget: hostBar.moduleWidgets("sarr.windowpeek")[0] || null
    readonly property var panel: find(widget,"windowPeekController")
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var body: panel ? panel.body : null
    property var browser: null
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    FakeHost {
        id: host; bar: test.widget ? test.widget.bar : null
        readonly property var focusRecovery: test.protectedMode && test.widget ? test.widget.focusRecovery : null
        windowPreview: thumbnail
        settings: ({hoverLogoCooldownUnit:"s",settingsLogoCooldownUnit:"s",keepSearchFocus:test.protectedMode,hintsMode:"off", doubleClickExpand:true, windowPreviews:false,panelStyle:"wallpaper",hoverLogoImage:"builtin:omarchy-pixel",settingsLogoImage:"builtin:omarchy-pixel"})
        Component.onCompleted: {
            savedAppearance = Appearance.normalize({uiScale:test.scale});
            wallpaperSource = Qt.resolvedUrl("dropdown-wallpaper.svg");
        }
    }
    Plugin.WindowThumbnail { id: thumbnail; hostWidget:host; shortcutTarget:test.body ? test.body.previewKeyTarget : null }
    Process {
        id: capture
        onExited: function(code) {
            if (code !== 0) console.error("WINDOWPEEK_TEST_FAIL: screenshot failed");
        }
    }
    QtObject {
        id:shell
        property var config: ({bar:{position:"top",transparent:false,layout:{left:[{
            id:"sarr.windowpeek",autoUpdates:false,windowPreviews:false,openOnHover:false,
            doubleClickExpand:true,uiScale:test.scale}],center:[],right:[]}}})
        function updateEntryInline(id,entry) { return true; }
        function pluginShellForId(id) { return shell; }
    }
    Component { id: widgetFactory; Plugin.Widget {} }
    QtObject {
        id: registry
        property var widgets: ({"sarr.windowpeek":{component:widgetFactory}})
        property int revision: 0
        function metadataFor(id) { return {firstParty:false}; }
    }
    Host.Bar {
        id: hostBar; shell:shell; barConfig:shell.config.bar
        barWidgetRegistry:registry; omarchyPath:"/usr/share/omarchy"
    }
    Window {
        id: outsideApp; visible: test.outsideCase; width: 900; height: 700
        title: "Artwork chooser input fixture"; color: "#24343c"
        property int presses: 0
        MouseArea { anchors.fill: parent; onPressed: outsideApp.presses++ }
    }
    Item { parent:test.body; TestEvent { id: events } }
    function named(name) { return find(body, name); }
    function overlay(name) { return find(body.Window.window.contentItem, name); }
    Process {
        id: mover
        onExited: function(code) {
            if (code === 0) pointer.write("click\n");
            else { console.error("WINDOWPEEK_TEST_FAIL: private pointer move failed"); Qt.quit(); }
        }
    }
    Process {
        id: pointer; command:[Quickshell.env("WINDOWPEEK_TEST_POINTER_FRAME"),"--listen"]
        running:true; stdinEnabled:true
        onExited: if (!test.finished) {
            console.error("WINDOWPEEK_TEST_FAIL: pointer helper stopped at step " + test.step);
            Qt.quit();
        }
        property bool ready:false
        property bool pending:false
        stdout: SplitParser { onRead:function(line) {
            if(line==="ready") pointer.ready=true;
            if(line==="clicked") pointer.pending=false;
        } }
    }
    function click(item) {
        check(!!item && item.visible, "click target is visible");
        var point=item.mapToGlobal(item.width/2,item.height/2);
        clickPoint(point);
    }
    function clickPoint(point) {
        pointer.pending=true;
        mover.command=["hyprctl","eval","hl.dispatch(hl.dsp.cursor.move({x="+Math.round(point.x)+",y="+Math.round(point.y)+"}))"];
        mover.running=true;
    }
    function outside() { clickPoint(outsideApp.contentItem.mapToGlobal(outsideApp.width-30,outsideApp.height-30)); }
    function checkRetained(count) {
        check(panel.opened && named("logoSettings").picking,"outside click retains chooser and Settings");
        check(outsideApp.presses === count && outsideApp.active,"outside app receives click and keyboard focus");
        check(browser.selection === "builtin:ttfx-burn","draft selection survives outside click");
        console.log("CHOOSER_OUTSIDE_PASS",count,test.protectedMode);
    }
    function key(value) { check(events.keyClick(value,Qt.NoModifier,0),"key delivered"); }
    property string place: "settings"
    property string filename: "animated-logo.gif"
    property int fileIndex: -1
    property int substep: 0

    Timer {
        interval:400;running:true;repeat:true
        onTriggered: {
            if(capture.running || pointer.pending || !pointer.ready) return;
            try {
                switch(test.step++) {
                case -5:
                    if(!test.widget || !test.widget.settingsReady){test.check(++test.waits<10,"widget loads");test.step--;break;}
                    test.check(test.widget.settingsLogoImage === "builtin:omarchy-random" && test.widget.hoverLogoImage === "builtin:omarchy-pixel","fresh widget uses the distinct shipped animated presets");
                    test.check(test.widget.hoverLogoCooldown === 60 && test.widget.settingsLogoCooldown === 0,"fresh widget uses independent cooldown defaults");
                    test.widget.open();break;
                case -4: panel.hostWidget=host;panel.close();break;
                case -3: panel.hoverRequested=true;break;
                case -2: panel.open(false,true);break;
                case -1: panel.open();break;
                case 0:
                    if(test.protectedMode && !panel.surface.usingNative) {
                        test.check(++test.waits<10,"native protection maps");test.step--;break;
                    }
                    test.click(test.named("settingsButton"));break;
                case 1: test.named("settingsPersonalizationSection").expanded=true;break;
                case 2: if(test.body.mode!=="pictures"){test.body.ensureVisible(test.named("openPicturesButton"));test.click(test.named("openPicturesButton"));}break;
                case 3: test.check(test.body.mode==="pictures","Pictures and Gifs opens from Personalization");test.body.ensureVisible(test.named(test.place+"LogoPicker"));test.click(test.named(test.place+"LogoPicker"));break;
                case 4:
                    test.check(test.named("logoSettings").picking,"library opens");
                    if(Quickshell.env("WP_CASE")==="opacity") {
                        test.browser=test.named("logoSettings").activePopup;
                        test.browser.select("builtin:ttfx-burn");test.step=120;break;
                    }
                    if(test.outsideCase) {
                        test.browser=test.named("logoSettings").activePopup;
                        test.browser.select("builtin:ttfx-burn");
                        test.step=100;test.outside();break;
                    }
                    if(test.substep++ === 0) { test.click(test.overlay("logoMotionChoice"));test.step--;break; }
                    if(test.substep === 2) {
                        test.check(test.overlay("logoMotionChoice").popupOpen,"motion dropdown opens");
                        test.click(test.overlay("logoThemeColors"));test.step--;break;
                    }
                    if(test.substep === 3) {
                        test.check(panel.opened && test.named("logoSettings").picking,"clicking parent library keeps the panel open");
                        test.check(!test.overlay("logoMotionChoice").popupOpen,"parent click dismisses only the dropdown");
                        test.click(test.overlay("logoMotionChoice"));test.step--;break;
                    }
                    if(test.substep === 4) { test.click(test.overlay("optionList").itemAtIndex(5));test.step--;break; }
                    if(test.substep === 5) {
                        test.check(panel.opened && test.named("logoSettings").picking,"choosing a nested option keeps the panel open");
                        test.check(test.overlay("logoMotionChoice").value==="fade","chosen motion retained in draft");
                        test.click(test.overlay("logoMotionChoice"));test.step--;break;
                    }
                    if(test.substep === 6) { test.click(test.overlay("logoMotionChoice"));test.step--;break; }
                    if(test.substep === 7) {
                        test.check(panel.opened && test.named("logoSettings").picking && !test.overlay("logoMotionChoice").popupOpen,"trigger closes only its dropdown");
                        test.click(test.overlay("logoRevealChoice"));test.step--;break;
                    }
                    if(test.substep === 8) { test.click(test.overlay("optionList").itemAtIndex(2));test.step--;break; }
                    if(test.substep === 9) {
                        test.check(panel.opened && test.named("logoSettings").picking && test.overlay("logoRevealChoice").value==="scatter","opening effect can be picked without closing the library");
                        test.click(test.overlay("logoFilesTab"));test.step--;break;
                    }
                    test.substep=0;test.click(test.overlay("browseLogoFile"));break;
                case 5:
                    test.check(test.named("logoSettings").picking,"mouse choice opens file picker");
                    var path=test.overlay("logoFolderPath");
                    test.check(!!path && path.Window.window===test.body.Window.window,"chooser is in current panel window");
                    path.forceActiveFocus();path.text=Quickshell.env("WINDOWPEEK_TEST_PROFILE");
                    test.key(Qt.Key_Return);break;
                case 6:
                    var files=test.overlay("logoFileList");
                    test.fileIndex=files.model.indexOf(Qt.resolvedUrl(test.filename));
                    test.check(test.fileIndex>=0,"requested image is listed");
                    files.positionViewAtIndex(test.fileIndex,ListView.Center);break;
                case 7:
                    test.click(test.overlay("logoFileList").itemAtIndex(test.fileIndex));break;
                case 8:
                    test.check(test.overlay("logoImagePreview").status===Image.Ready,"mouse-selected image previews");
                    test.check(test.overlay("acceptLogoImage").enabled,"Apply enabled");
                    if(Quickshell.env("WINDOWPEEK_TEST_IMAGE")){
                        capture.command=["grim","-o","WPTEST",Quickshell.env("WINDOWPEEK_TEST_IMAGE")+"."+test.place+".png"];
                        capture.running=true;
                    }
                    break;
                case 9: test.click(test.overlay("acceptLogoImage"));break;
                case 10:
                    if(test.substep++ === 0) { test.click(test.overlay("applyLogoChoice"));test.step--;break; }
                    test.substep=0;
                    test.check(!test.named("logoSettings").picking,"Apply closes library");
                    test.check((test.place==="settings" ? host.settingsLogoImage : host.hoverLogoImage)===String(Qt.resolvedUrl(test.filename)),"Apply persists selected "+test.place+" file");
                    test.check(host.effectiveSettings[test.place+"LogoReveal"]==="scatter","native opening-effect choice saved for selected view");
                    if(test.place==="settings") {
                        test.place="hover";test.filename="dropdown-wallpaper.svg";test.step=2;break;
                    }
                    test.check(host.settingsLogoImage.endsWith("animated-logo.gif"),"compact selection preserves Settings GIF");
                    test.step=11;break;
                case 11: test.click(test.named("hoverLogoPicker"));break;
                case 12: test.click(test.overlay("browseLogoFile"));break;
                case 13:
                    test.check(test.named("logoSettings").picking,"can replace an existing custom file");
                    test.key(Qt.Key_Escape);break;
                case 14:
                    if(test.substep++ === 0) {
                        test.check(test.named("logoSettings").picking && test.named("logoSettings").activePopup.objectName === "logoBrowser","Escape returns from file picker to library");
                        test.key(Qt.Key_Escape);test.step--;break;
                    }
                    test.substep=0;
                    test.check(!test.named("logoSettings").picking && panel.opened,"second Escape closes only the library");
                    test.check(host.hoverLogoImage.endsWith("dropdown-wallpaper.svg"),"Cancel keeps previous file");
                    test.click(test.named("hoverLogoPicker"));break;
                case 15: test.click(test.overlay("browseLogoFile"));break;
                case 16:
                    var directPath=test.overlay("logoFolderPath");
                    directPath.text=Quickshell.env("WINDOWPEEK_TEST_PROFILE")+"/logo #1.GIF";
                    directPath.forceActiveFocus();test.key(Qt.Key_Return);break;
                case 17:
                    test.check(test.overlay("logoImagePreview").status===Image.Ready,"full file path with spaces and # previews");
                    test.click(test.overlay("acceptLogoImage"));break;
                case 18:
                    if(test.substep++ === 0) { test.click(test.overlay("applyLogoChoice"));test.step--;break; }
                    test.substep=0;
                    test.check(decodeURIComponent(host.hoverLogoImage).endsWith("/logo #1.GIF")
                        && host.hoverLogoImage.indexOf("%23") >= 0,"full path preserves spaces and escaped #");
                    test.body.ensureVisible(test.named("hoverLogoLoopToggle"));break;
                case 19:
                    var hoverDelay=test.named("hoverLogoLoopDelay");
                    hoverDelay.forceActiveFocus();hoverDelay.text="0.3";
                    test.click(test.named("hoverLogoLoopToggle"));break;
                case 20:
                    test.check(host.hoverLogoLoopDelay===0.3 && host.settingsLogoLoopDelay===4.2,"outside click saves decimal delay independently");
                    test.check(!test.named("hoverLogoLoopDelay").focus && !test.named("hoverLogoLoopDelay").cursorVisible,"outside click ends compact delay editing");
                    test.check(!host.hoverLogoLoop && host.settingsLogoLoop,"compact mini switch changes only compact playback");
                    test.check(test.named("hoverLogoLoopToggle").text===host.words.loopAnimation,"loop label stays constant when off");
                    test.body.ensureVisible(test.named("settingsLogoLoopToggle"));break;
                case 21:
                    var settingsDelay=test.named("settingsLogoLoopDelay");
                    settingsDelay.forceActiveFocus();settingsDelay.text="2";
                    test.click(test.named("settingsLogoLoopToggle"));break;
                case 22:
                    test.check(host.settingsLogoLoopDelay===2 && host.hoverLogoLoopDelay===0.3,"outside click saves whole seconds independently");
                    test.check(!test.named("settingsLogoLoopDelay").focus && !test.named("settingsLogoLoopDelay").cursorVisible,"outside click ends Settings delay editing");
                    test.check(!host.settingsLogoLoop,"Settings mini switch saves once mode");
                    if(Quickshell.env("WINDOWPEEK_TEST_IMAGE")) {
                        capture.command=["grim","-o","WPTEST",Quickshell.env("WINDOWPEEK_TEST_IMAGE")+".switches.png"];
                        capture.running=true;
                    }
                    break;
                case 23:
                    test.body.ensureVisible(test.named("hoverLogoCooldown"));break;
                case 24:
                    var cooldown=test.named("hoverLogoCooldown");cooldown.forceActiveFocus();cooldown.text="0.3";test.key(Qt.Key_Return);
                    test.check(host.hoverLogoCooldown===0.3,"fractional seconds save as cooldown");
                    test.click(test.named("hoverLogoCooldownUnit"));break;
                case 25:
                    var units=test.overlay("optionList");test.check(units && units.visible,"cooldown units open");
                    test.click(units.itemAtIndex(1));break;
                case 26:
                    test.check(host.effectiveSettings.hoverLogoCooldownUnit==="min" && host.hoverLogoCooldown===0.3,"changing units preserves duration");
                    var minutes=test.named("hoverLogoCooldown");
                    test.check(Number(minutes.text)===0.005,"unit conversion displays fractional minutes");
                    minutes.forceActiveFocus();minutes.text="0.5";test.key(Qt.Key_Return);
                    test.check(host.hoverLogoCooldown===30,"minutes are stored as seconds");
                    test.body.ensureVisible(test.named("settingsLogoCooldown"));break;
                case 27:
                    var other=test.named("settingsLogoCooldown");other.forceActiveFocus();other.text="60";test.key(Qt.Key_Return);
                    test.check(host.settingsLogoCooldown===60 && host.hoverLogoCooldown===30,"cooldown slots are independent even with looping off");
                    if(Quickshell.env("WINDOWPEEK_TEST_IMAGE")) {
                        capture.command=["grim","-o","WPTEST",Quickshell.env("WINDOWPEEK_TEST_IMAGE")+".cooldown.png"];
                        capture.running=true;
                    }break;
                case 28:
                    test.click(test.named("settingsLogoCooldownReset"));break;
                case 29:
                    test.check(host.settingsLogoCooldown===0 && host.hoverLogoCooldown===30,"cooldown reset affects only its slot");
                    test.body.ensureVisible(test.named("hoverLogoCooldownReset"));break;
                case 30: test.click(test.named("hoverLogoCooldownReset"));break;
                case 31:
                    test.check(host.hoverLogoCooldown===60 && test.named("hoverLogoCooldown").text==="1","cooldown reset restores one minute and refreshes the field");
                    test.check(test.named("hoverLogoCooldownUnit").value==="min","reset preserves the chosen units");
                    test.click(test.named("hoverLogoLoopDelayReset"));break;
                case 32:
                    test.check(host.hoverLogoLoopDelay===4.2,"loop delay resets to its original default");
                    test.check(host.settingsLogoLoopDelay!==4.2,"hover delay reset preserves Settings delay");
                    test.body.ensureVisible(test.named("settingsLogoLoopDelayReset"));break;
                case 33: test.click(test.named("settingsLogoLoopDelayReset"));break;
                case 34:
                    test.check(host.settingsLogoLoopDelay===4.2,"Settings loop delay resets independently");
                    test.body.ensureVisible(test.named("sharedLogoCooldownToggle"));break;
                case 35: test.click(test.named("sharedLogoCooldownToggle"));break;
                case 36:
                    test.check(host.sharedLogoCooldownEnabled && !test.named("hoverLogoCooldown").visible && !test.named("settingsLogoCooldown").visible,"shared switch replaces both individual cooldown fields");
                    var shared=test.named("sharedLogoCooldown");shared.forceActiveFocus();shared.text="0.3";test.key(Qt.Key_Return);
                    test.check(host.sharedLogoCooldown===0.3,"shared fractional seconds save");
                    test.click(test.named("sharedLogoCooldownUnit"));break;
                case 37: test.click(test.overlay("optionList").itemAtIndex(1));break;
                case 38:
                    var sharedMinutes=test.named("sharedLogoCooldown");
                    test.check(Number(sharedMinutes.text)===0.005,"shared minutes preserve the stored duration");
                    sharedMinutes.forceActiveFocus();sharedMinutes.text="0.5";test.key(Qt.Key_Return);
                    test.check(host.sharedLogoCooldown===30,"shared fractional minutes save as seconds");
                    test.click(test.named("sharedLogoCooldownReset"));break;
                case 39:
                    test.check(host.sharedLogoCooldown===0,"shared cooldown reset works");
                    test.click(test.named("sharedLogoCooldownToggle"));break;
                case 40:
                    test.check(!host.sharedLogoCooldownEnabled && test.named("hoverLogoCooldown").visible && test.named("settingsLogoCooldown").visible,"individual cooldown fields return when sharing is off");
                    test.key(Qt.Key_Escape);break;
                case 41:
                    test.check(test.body.mode==="settings" && test.named("settingsPersonalizationSection").expanded,"Back returns one level to expanded Personalization");
                    panel.close();test.finished=true;console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                case 100:
                    test.checkRetained(1);test.click(test.overlay("logoMotionChoice"));break;
                case 101:
                    test.check(test.overlay("logoMotionChoice").popupOpen,"nested dropdown opens after returning");
                    test.outside();break;
                case 102:
                    test.checkRetained(2);test.click(test.overlay("logoThemeColors"));break;
                case 103:
                    test.check(!test.overlay("logoMotionChoice").popupOpen,"clicking parent dismisses nested dropdown only");
                    test.click(test.overlay("logoFilesTab"));break;
                case 104: test.click(test.overlay("browseLogoFile"));break;
                case 105:
                    test.check(test.named("logoSettings").activePopup.objectName === "logoImagePicker","file browser opens");
                    test.outside();break;
                case 106:
                    test.checkRetained(3);
                    test.check(test.named("logoSettings").activePopup.objectName === "logoImagePicker","file browser survives outside click");
                    test.click(test.overlay("logoFolderPath"));break;
                case 107: test.key(Qt.Key_Escape);break;
                case 108:
                    test.check(test.named("logoSettings").picking && panel.opened,"Escape closes only file browser");
                    test.key(Qt.Key_Escape);break;
                case 109:
                    test.check(!test.named("logoSettings").picking && panel.opened,"second Escape closes only library");
                    test.check(host.settingsLogoImage === "builtin:omarchy-pixel","Cancel preserves original choice");
                    test.outside();break;
                case 110:
                    test.check(!panel.opened && outsideApp.presses === 4,"outside dismissal resumes after closing chooser");
                    test.finished=true;console.log("WINDOWPEEK_TEST_PASS chooser outside",test.scale,test.protectedMode);stop();Qt.quit();break;
                case 120:
                    test.check(test.browser.contentItem.implicitHeight<=test.browser.availableHeight+1,"chooser fits the available screen height");
                    test.check(test.overlay("logoLibraryPreview").status===Image.Ready,"transparent GIF is ready");
                    var slider=test.overlay("logoTransparencySlider");
                    test.clickPoint(slider.mapToGlobal(slider.leftPadding+slider.handle.width/2
                        + 0.75*(slider.availableWidth-slider.handle.width),slider.height/2));break;
                case 121:
                    test.check(Math.abs(test.browser.artworkOpacity-25)<=1,"actual slider click sets a manual opacity");
                    test.check(host.settings[test.place+"LogoOpacity"]===undefined,"preview has not saved opacity");
                    if(Quickshell.env("WINDOWPEEK_TEST_IMAGE")) {
                        capture.command=["grim",Quickshell.env("WINDOWPEEK_TEST_IMAGE")];capture.running=true;
                    }
                    test.step=126;break;
                case 126:
                    test.click(test.overlay("applyLogoChoice"));test.step=122;break;
                case 122:
                    test.check(!test.named("logoSettings").picking && panel.opened,"Apply keeps the parent panel open");
                    test.check(Math.abs(host.settings[test.place+"LogoOpacity"]-25)<=1,"opacity saved for the selected view");
                    test.click(test.named(test.place+"LogoPicker"));break;
                case 123:
                    test.check(Math.abs(test.browser.artworkOpacity-25)<=1,"saved opacity restored");
                    test.click(test.overlay("logoTransparencyReset"));break;
                case 124:
                    test.check(test.browser.artworkOpacity===50 && test.browser.opacityOverride===null,"reset restores automatic GIF opacity");
                    test.browser.close();break;
                case 125:
                    test.check(Math.abs(host.settings[test.place+"LogoOpacity"]-25)<=1,"Cancel preserves saved opacity");
                    test.finished=true;panel.close();console.log("WINDOWPEEK_TEST_PASS chooser opacity",test.scale);stop();Qt.quit();break;
                }
            } catch(error) {console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error);stop();Qt.quit();}
        }
    }
}
