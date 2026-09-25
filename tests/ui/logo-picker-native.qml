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
    readonly property var widget: hostBar.moduleWidgets("sarr.windowpeek")[0] || null
    readonly property var panel: find(widget,"windowPeekController")
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var body: panel ? panel.body : null
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    FakeHost {
        id: host; bar: test.widget ? test.widget.bar : null
        windowPreview: thumbnail
        settings: ({hintsMode:"off", doubleClickExpand:true, windowPreviews:false,panelStyle:"wallpaper",hoverLogoImage:"builtin:omarchy-pixel",settingsLogoImage:"builtin:omarchy-pixel"})
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
        pointer.pending=true;
        mover.command=["hyprctl","eval","hl.dispatch(hl.dsp.cursor.move({x="+Math.round(point.x)+",y="+Math.round(point.y)+"}))"];
        mover.running=true;
    }
    function key(value) { check(events.keyClick(value,Qt.NoModifier,0),"key delivered"); }
    property string place: "settings"
    property string filename: "animated-logo.gif"
    property int fileIndex: -1

    Timer {
        interval:400;running:true;repeat:true
        onTriggered: {
            if(capture.running || pointer.pending || !pointer.ready) return;
            try {
                switch(test.step++) {
                case -5:
                    if(!test.widget || !test.widget.settingsReady){test.check(++test.waits<10,"widget loads");test.step--;break;}
                    test.widget.open();break;
                case -4: panel.hostWidget=host;panel.close();break;
                case -3: panel.hoverRequested=true;break;
                case -2: panel.open(false,true);break;
                case -1: panel.open();break;
                case 0: test.click(test.named("settingsButton"));break;
                case 1: test.named("settingsPersonalizationSection").expanded=true;break;
                case 2: if(test.body.mode!=="pictures"){test.body.ensureVisible(test.named("openPicturesButton"));test.click(test.named("openPicturesButton"));}break;
                case 3: test.check(test.body.mode==="pictures","Pictures and Gifs opens from Personalization");test.body.ensureVisible(test.named(test.place+"LogoPicker"));test.click(test.named(test.place+"LogoPicker"));break;
                case 4:
                    var options=test.overlay("optionList");
                    test.check(options && options.visible,"dropdown opens");
                    test.click(options.itemAtIndex(2));break;
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
                    test.check(!test.named("logoSettings").picking,"Apply closes picker");
                    test.check((test.place==="settings" ? host.settingsLogoImage : host.hoverLogoImage)===String(Qt.resolvedUrl(test.filename)),"Apply persists selected "+test.place+" file");
                    if(test.place==="settings") {
                        test.place="hover";test.filename="dropdown-wallpaper.svg";test.step=2;break;
                    }
                    test.check(host.settingsLogoImage.endsWith("animated-logo.gif"),"compact selection preserves Settings GIF");
                    test.step=11;break;
                case 11: test.click(test.named("hoverLogoPicker"));break;
                case 12: test.click(test.overlay("optionList").itemAtIndex(2));break;
                case 13:
                    test.check(test.named("logoSettings").picking,"can replace an existing custom file");
                    test.key(Qt.Key_Escape);break;
                case 14:
                    test.check(!test.named("logoSettings").picking && panel.opened,"Escape closes only the chooser");
                    test.check(host.hoverLogoImage.endsWith("dropdown-wallpaper.svg"),"Cancel keeps previous file");
                    test.click(test.named("hoverLogoPicker"));break;
                case 15: test.click(test.overlay("optionList").itemAtIndex(2));break;
                case 16:
                    var directPath=test.overlay("logoFolderPath");
                    directPath.text=Quickshell.env("WINDOWPEEK_TEST_PROFILE")+"/logo #1.GIF";
                    directPath.forceActiveFocus();test.key(Qt.Key_Return);break;
                case 17:
                    test.check(test.overlay("logoImagePreview").status===Image.Ready,"full file path with spaces and # previews");
                    test.click(test.overlay("acceptLogoImage"));break;
                case 18:
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
                    test.check(host.hoverLogoCooldown===0 && test.named("hoverLogoCooldown").text==="0","cooldown reset refreshes the field");
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
                    panel.close();console.log("WINDOWPEEK_TEST_PASS");stop();Qt.quit();break;
                }
            } catch(error) {console.error("WINDOWPEEK_TEST_FAIL step "+(test.step-1)+": "+error);stop();Qt.quit();}
        }
    }
}
