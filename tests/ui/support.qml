import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import qs.Commons
import "WindowPeek" as Plugin
import "WindowPeek/I18n.js" as Languages
import "WindowPeek/LogoCatalog.js" as Catalog
import "WindowPeek/Appearance.js" as Appearance

ShellRoot {
    id: test
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    property int step: 0
    property var launches: []
    property int closed: 0
    property int previewCalls: 0
    property int priorPreviewCalls: 0
    property string supportArtwork: ""
    property int languageIndex: 0
    property real savedListWidth: 0
    property real savedScrollY: 0
    property bool capturing: false
    function check(value, message) { if (!value) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child,name); if (found) return found; }
        return null;
    }
    function named(name) { return find(panel,name); }
    function click(item) { check(events.mouseClick(item,item.width/2,item.height/2,Qt.LeftButton,Qt.NoModifier,0),"mouse click delivered"); }
    function dismissModal() { check(events.mouseClick(panel,2,2,Qt.LeftButton,Qt.NoModifier,0),"outside click delivered"); }
    function capture(name, after) {
        var prefix = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
        if (prefix) {
            capturing=true;
            window.contentItem.grabToImage(function(result) {
                result.saveToFile(prefix + "-" + name + ".png");test.capturing=false;
                if (after) after();
            });
        } else if (after) after();
    }
    TestEvent { id: events }
    QtObject {
        id: previewProbe
        property Item anchorItem: null
        property bool visible: false
        property bool containsPointer: false
        property bool menuRetained: false
        function showFor(item, address, bounds) { test.previewCalls++; anchorItem=item; visible=true; }
        function hideFor(item) { if (anchorItem===item) dismiss(); }
        function dismiss() { visible=false; anchorItem=null; }
    }
    SplitParser { id: launches; onRead: function(line) { test.launches = test.launches.concat([JSON.parse(line)]); } }
    FakeHost { id: host; Component.onCompleted: savedAppearance = Appearance.normalize({uiScale:test.scale}) }
    Window {
        id: window; visible: true; width: 540 * test.scale; height: 640 * test.scale
        color: host.surfaces.panel
        Plugin.WallpaperBackdrop {
            anchors.fill: parent; palette: host.surfaces
            wallpaper: host.panelStyle === "wallpaper"; visible: host.glassPanels
            source: host.wallpaperSource; textured: host.backgroundTexture
            screenSize: Qt.size(window.width,window.height)
            tintOpacity: 1-host.wallpaperTransparency/100
        }
        Plugin.PanelContent {
            id: panel; x:20*test.scale; y:20*test.scale; width:500; height:580
            hostWidget: host; scale:test.scale; transformOrigin:Item.TopLeft
            onCloseRequested: test.closed++
        }
    }
    Component.onCompleted: Plugin.BrowserLinks.browser.stdout = launches
    Timer {
        interval:200; running:true; repeat:true
        onTriggered: {
            if (test.capturing) return;
            try {
                switch (test.step++) {
                case 0:
                    panel.begin(); panel.showSettings(); test.named("settingsControlsSection").expanded = true;
                    test.named("hintsSupportEntry").clicked(); break;
                case 1:
                    test.check(panel.mode === "support", "support opens");
                    test.check(test.named("reportIssueButton").text === "Report Bugs or Post Your Ideas", "requested action label");
                    test.check(test.launches.length === 0,"opening help never launches the browser");
                    test.click(test.named("pinPanelButton")); break;
                case 2:
                    events.mouseMove(window.contentItem, 2, 2, 0, Qt.NoButton, Qt.NoModifier);
                    test.check(panel.panelPinned && test.named("pinPanelButton").checked, "mouse pin is visibly selected");
                    test.check(!test.named("pinPanelButton").visualFocus,"mouse pin does not leave a keyboard focus ring");
                    test.capture("pinned");
                    test.click(test.named("pinPanelButton")); break;
                case 3:
                    events.mouseMove(window.contentItem, 2, 2, 0, Qt.NoButton, Qt.NoModifier);
                    test.check(!panel.panelPinned && !test.named("pinPanelButton").checked
                        && !test.named("pinPanelButton").visualFocus && !test.named("pinPanelButton").hovered,
                        "mouse unpin clears both selected and lingering focus highlighting");
                    test.capture("unpinned");
                    test.named("settingsButton").forceActiveFocus(Qt.TabFocusReason);
                    events.keyClick(Qt.Key_Backtab,Qt.ShiftModifier,0);
                    events.keyClick(Qt.Key_Space,Qt.NoModifier,0); break;
                case 4:
                    test.check(panel.panelPinned && test.named("pinPanelButton").visualFocus,"keyboard pin keeps a visible focus cue: " + JSON.stringify({pinned:panel.panelPinned,focus:test.named("pinPanelButton").activeFocus,visual:test.named("pinPanelButton").visualFocus,reason:test.named("pinPanelButton").focusReason}));
                    events.keyClick(Qt.Key_Return,Qt.NoModifier,0); break;
                case 5:
                    test.check(!panel.panelPinned && test.named("pinPanelButton").visualFocus,"keyboard unpin remains navigable");
                    test.click(test.named("pinPanelButton"));
                    test.click(test.named("pinPanelButton"));
                    events.mouseMove(window.contentItem, 2, 2, 0, Qt.NoButton, Qt.NoModifier);
                    test.check(!panel.panelPinned && !test.named("pinPanelButton").keyboardFocusVisible,
                        "mouse pin/unpin after keyboard use clears the old keyboard highlight");
                    test.click(test.named("reportIssueButton")); break;
                case 6:
                    if (Plugin.BrowserLinks.busy) { test.step--; break; }
                    test.check(test.launches.length === 1 && JSON.stringify(test.launches[0]) === JSON.stringify(["launch","browser","https://github.com/Sarr77/WindowPeek/issues"]),
                        "real button click launches the browser command with the project Issues URL");
                    test.check(!Plugin.BrowserLinks.failed,"successful launcher has no error");
                    Plugin.BrowserLinks.browser.environment = ({WINDOWPEEK_TEST_BROWSER_EXIT:"7"});
                    test.click(test.named("reportIssueButton")); break;
                case 7:
                    if (Plugin.BrowserLinks.busy) { test.step--; break; }
                    test.check(Plugin.BrowserLinks.failed && test.named("supportLinkError").visible
                        && test.named("supportLinkError").readOnly, "launcher failure exposes an address to copy");
                    test.capture("failed");
                    Plugin.BrowserLinks.browser.environment = ({});
                    test.click(test.named("reportIssueButton")); break;
                case 8:
                    if (Plugin.BrowserLinks.busy) { test.step--; break; }
                    test.check(!Plugin.BrowserLinks.failed && !test.named("supportLinkError").visible,"retry clears the error");
                    Plugin.BrowserLinks.open("https://github.com/Sarr77/WindowPeek/commits/main/"); break;
                case 9:
                    if (Plugin.BrowserLinks.busy) { test.step--; break; }
                    test.check(test.launches.length === 4 && test.launches[3][2].endsWith("/commits/main/"),"history uses the same launcher");
                    Plugin.BrowserLinks.open("https://github.com/Sarr77/WindowPeek/compare/" + "a".repeat(40) + "..." + "b".repeat(40)); break;
                case 10:
                    if (Plugin.BrowserLinks.busy) { test.step--; break; }
                    test.check(test.launches.length === 5 && test.launches[4][2].indexOf("/compare/") > 0,"checked comparison uses the same launcher");
                    test.check(!Plugin.BrowserLinks.open("file:///tmp/not-a-support-link") && test.launches.length === 5,"unrelated targets cannot launch");
                    test.named("supportSection0").expanded=true;
                    test.click(test.named("troubleshootingEntry")); break;
                case 11:
                    test.check(panel.mode==="troubleshooting", "support entry opens the existing Troubleshooting editor");
                    test.check(test.named("editorScroll").contentY===0,"Troubleshooting starts at the explanation");
                    test.click(test.named("settingsButton")); break;
                case 12:
                    test.check(panel.mode==="support" && test.named("supportSection0").expanded,
                        "Back retains support guide expansion");
                    test.check(!test.named("troubleshootingEntry").keyboardFocusVisible,"mouse Back leaves no keyboard focus highlight");
                    test.named("troubleshootingEntry").forceActiveFocus(Qt.TabFocusReason);
                    events.keyClick(Qt.Key_Return,Qt.NoModifier,0); break;
                case 13:
                    test.check(panel.mode==="troubleshooting","keyboard opens relocated entry");
                    events.keyClick(Qt.Key_Escape,Qt.NoModifier,0); break;
                case 14:
                    test.check(panel.mode==="support" && test.named("troubleshootingEntry").keyboardFocusVisible,"keyboard Back restores focus to support entry " + JSON.stringify({mode:panel.mode,active:test.named("troubleshootingEntry").activeFocus,visual:test.named("troubleshootingEntry").visualFocus,pointer:test.named("troubleshootingEntry").pointerFocus,focused:window.activeFocusItem?window.activeFocusItem.objectName:"none"}));
                    test.click(test.named("settingsButton")); break;
                case 15:
                    test.check(panel.mode==="settings", "second Back returns to Settings");
                    test.click(test.named("authorCredit")); break;
                case 16:
                    test.check(test.named("projectSupport").opened && panel.keepOpenOutside && panel.currentPopup===test.named("projectSupport"),
                        "footer opens retained support popup without leaving Settings");
                    test.supportArtwork=test.named("projectSupportArtwork").source;
                    test.check(!!Catalog.effect(test.supportArtwork) && test.named("projectSupportArtwork").playing,
                        "popup plays one locally bundled random GIF");
                    test.check(!test.named("projectSupportArtwork").themeColors && test.named("projectSupportArtwork").artworkOpacity===50,
                        "support GIF retains original colors and 50% opacity");
                    test.check(!test.named("closeProjectSupport"),"no corner close glyph");
                    test.check(test.named("projectSupportHeading").text==="Like this? Let people know",
                        "requested heading without a final period");
                    test.capture("project");
                    test.click(test.named("starWindowPeekCatalog")); break;
                case 17:
                    if (Plugin.BrowserLinks.busy) { test.step--; break; }
                    test.check(test.launches.length===6 && test.launches[5][2]==="https://plugins.omarchy.org/plugin.html?id=sarr.windowpeek","catalog star opens exact plugin listing");
                    test.click(test.named("starWindowPeekGitHub")); break;
                case 18:
                    if (Plugin.BrowserLinks.busy) { test.step--; break; }
                    test.check(test.launches.length===7 && test.launches[6][2]==="https://github.com/Sarr77/WindowPeek","GitHub star opens repository, without submitting a star");
                    test.click(test.named("projectSupportIssues")); break;
                case 19:
                    if (Plugin.BrowserLinks.busy) { test.step--; break; }
                    test.check(test.launches.length===8 && test.launches[7][2].endsWith("/issues"),"popup report opens project Issues");
                    Plugin.BrowserLinks.browser.environment=({WINDOWPEEK_TEST_BROWSER_EXIT:"7"});
                    test.click(test.named("starWindowPeekGitHub")); break;
                case 20:
                    if (Plugin.BrowserLinks.busy) { test.step--; break; }
                    test.check(test.named("projectSupportLinkError").visible,"failed launch exposes copyable address");
                    test.dismissModal(); break;
                case 21:
                    events.mouseMove(window.contentItem,2,2,0,Qt.NoButton,Qt.NoModifier);
                    test.check(!test.named("projectSupport").opened && panel.mode==="settings" && !test.named("authorCredit").hot,"mouse close preserves page without stale highlight");
                    test.check(!test.named("projectSupportArtwork").playing
                        && !test.find(test.named("projectSupportArtwork"),"customPanelLogo").animating,
                        "hidden support GIF stops decoding frames");
                    test.named("updateSwitch").forceActiveFocus(Qt.OtherFocusReason);
                    events.keyClick(Qt.Key_Tab,Qt.NoModifier,0);
                    events.keyClick(Qt.Key_Return,Qt.NoModifier,0); break;
                case 22:
                    test.check(test.named("projectSupport").opened,"keyboard opens footer popup");
                    test.check(test.named("projectSupportArtwork").source!==test.supportArtwork,"reopening chooses another GIF");
                    events.keyClick(Qt.Key_Escape,Qt.NoModifier,0); break;
                case 23:
                    test.check(!test.named("projectSupport").opened && panel.mode==="settings" && test.named("authorCredit").activeFocus,"Escape closes only popup and returns focus");
                    test.check(!Plugin.BrowserLinks.open("https://plugins.omarchy.org/plugin.html?id=other.plugin"),"catalog allowlist rejects unrelated targets");
                    host.windowPreview=previewProbe;
                    panel.begin();break;
                case 24:
                    var row=test.named("windowFocus");
                    test.check(row && row.visible,"window row available");
                    events.mouseMove(row,row.width/2,row.height/2,0,Qt.NoButton,Qt.NoModifier);break;
                case 25:
                    test.check(test.previewCalls>0 && previewProbe.visible,"ordinary row hover requests a preview");
                    test.click(test.named("authorCredit"));break;
                case 26:
                    test.check(test.named("projectSupport").opened && !previewProbe.visible,"popup dismisses the existing preview");
                    test.priorPreviewCalls=test.previewCalls;
                    var behind=test.named("windowFocus");
                    events.mouseMove(behind,behind.width/2,behind.height/2,0,Qt.NoButton,Qt.NoModifier);break;
                case 27:
                    test.check(!test.named("windowFocus").hovered && !test.named("windowPreviewTarget").requested
                        && test.previewCalls===test.priorPreviewCalls,"modal blocks underlying row hover and preview requests");
                    var toggle=test.named("updateSwitch");
                    events.mouseMove(toggle,toggle.width/2,toggle.height/2,0,Qt.NoButton,Qt.NoModifier);break;
                case 28:
                    test.check(!test.named("updateSwitch").hot && test.named("updateSwitch").text==="Automatic updates",
                        "modal blocks footer hover; notification control uses the requested label");
                    test.dismissModal();break;
                case 29:
                    var restored=test.named("windowFocus");
                    events.mouseMove(restored,restored.width/2,restored.height/2,0,Qt.NoButton,Qt.NoModifier);break;
                case 30:
                    test.check(test.named("windowFocus").hovered && previewProbe.visible
                        && test.previewCalls>test.priorPreviewCalls,"closing popup restores ordinary hover previews");
                    host.persistSettings({popupAnimations:false});
                    panel.height=500;
                    test.click(test.named("authorCredit"));break;
                case 31:
                    test.check(!test.named("projectSupportArtwork").playing,"disabled animations use the still poster");
                    host.language=Languages.languages[test.languageIndex].code;break;
                case 32:
                    var card=test.named("projectSupportCard"), scroll=test.named("projectSupportScroll");
                    test.check(card.x>=0 && card.y>=0 && card.y+card.height<=panel.height+0.01,"card fits: "+host.language);
                    test.check(scroll.contentHeight<=scroll.height+0.01,"normal popup needs no scrolling: "+host.language);
                    if (++test.languageIndex<Languages.languages.length) {test.step=31;break;}
                    host.language="en";host.persistSettings({checkUpdates:true});panel.begin();break;
                case 33:
                    var normal=test.named("windowFocus");
                    events.mouseMove(normal,normal.width/2,normal.height/2,0,Qt.NoButton,Qt.NoModifier);break;
                case 34:
                    test.check(previewProbe.visible,"preview works before notification confirmation");
                    test.click(test.named("updateSwitch"));break;
                case 35:
                    test.check(test.named("updateConfirmation").opened && !previewProbe.visible,"notification popup dismisses existing preview");
                    test.priorPreviewCalls=test.previewCalls;
                    var blocked=test.named("windowFocus");
                    events.mouseMove(blocked,blocked.width/2,blocked.height/2,0,Qt.NoButton,Qt.NoModifier);break;
                case 36:
                    test.check(!test.named("windowFocus").hovered && !test.named("windowPreviewTarget").requested
                        && test.previewCalls===test.priorPreviewCalls,"notification popup blocks underlying hover and previews");
                    var footer=test.named("updateSwitch");
                    events.mouseMove(footer,footer.width/2,footer.height/2,0,Qt.NoButton,Qt.NoModifier);break;
                case 37:
                    test.check(!test.named("updateSwitch").hot,"notification popup blocks footer hover");
                    test.dismissModal();break;
                case 38:
                    var unblocked=test.named("windowFocus");
                    events.mouseMove(unblocked,unblocked.width/2,unblocked.height/2,0,Qt.NoButton,Qt.NoModifier);break;
                case 39:
                    test.check(previewProbe.visible && test.previewCalls>test.priorPreviewCalls,"notification popup closure restores preview hover");
                    host.language="pl";test.click(test.named("updateSwitch"));break;
                case 40:
                    var offCard=test.named("updateOffCard"), primary=test.named("cancelUpdateOff");
                    test.check(offCard.y>=0 && offCard.y+offCard.height<=panel.height && primary.width>=primary.implicitWidth,
                        "Polish confirmation fits and long action is not clipped");
                    test.capture("notification-pl");host.language="ar";break;
                case 41:
                    var rtlCard=test.named("updateOffCard");
                    test.check(rtlCard.y>=0 && rtlCard.y+rtlCard.height<=panel.height,"Arabic confirmation fits");
                    test.dismissModal();
                    host.language="en";panel.height=360;panel.begin();break;
                case 42:
                    var longList=test.named("windowList");
                    test.check(test.named("windowScrollbar").visible,"short panel has a visible list scrollbar");
                    longList.contentY=30;test.savedListWidth=longList.width;test.savedScrollY=longList.contentY;
                    test.click(test.named("authorCredit"));break;
                case 43:
                    test.check(!test.named("windowScrollbar").visible && test.named("windowList").width===test.savedListWidth
                        && test.named("windowList").contentY===test.savedScrollY,"project popup hides list scrollbar without moving rows");
                    test.dismissModal();break;
                case 44:
                    test.check(test.named("windowScrollbar").visible,"list scrollbar returns after project popup");
                    test.click(test.named("updateSwitch"));break;
                case 45:
                    test.check(!test.named("windowScrollbar").visible && test.named("windowList").width===test.savedListWidth
                        && test.named("windowList").contentY===test.savedScrollY,"confirmation hides list scrollbar without moving rows");
                    test.dismissModal();panel.showSettings();test.named("settingsControlsSection").expanded=true;break;
                case 46:
                    test.check(test.named("editorScrollbar").visible,"expanded Settings needs a scrollbar");
                    test.named("editorScroll").contentY=20;test.savedScrollY=test.named("editorScroll").contentY;
                    test.click(test.named("authorCredit"));break;
                case 47:
                    test.check(!test.named("editorScrollbar").visible && test.named("editorScroll").contentY===test.savedScrollY,
                        "project popup hides editor scrollbar and retains scroll");
                    test.dismissModal();break;
                case 48:
                    test.check(test.named("editorScrollbar").visible,"editor scrollbar returns after project popup");
                    test.click(test.named("updateSwitch"));break;
                case 49:
                    test.check(!test.named("editorScrollbar").visible && test.named("editorScroll").contentY===test.savedScrollY,
                        "confirmation hides editor scrollbar and retains scroll");
                    test.dismissModal();break;
                case 50:
                    test.check(test.named("editorScrollbar").visible,"editor scrollbar returns after confirmation");
                    panel.height=580;panel.begin();
                    host.savedAppearance=Appearance.setSurfaceRule(host.savedAppearance,"panel",host.themeId,"all",{color:"#253744",brightness:0});
                    host.appearance=host.savedAppearance;
                    test.click(test.named("authorCredit"));break;
                case 51:
                    test.check(String(test.named("projectSupportCard").color)==="#253744","solid support popup follows the custom panel color");
                    test.capture("solid",function() {
                        test.dismissModal();host.wallpaperSource=Qt.resolvedUrl("dropdown-wallpaper.svg");
                        host.persistSettings({panelStyle:"wallpaper",backgroundTexture:true,backgroundBlur:true});
                        test.click(test.named("authorCredit"));
                    });break;
                case 52:
                    var wallpaper=test.find(test.named("projectSupportCard"),"dropdownWallpaper");
                    test.check(wallpaper && wallpaper.ready && wallpaper.textured && wallpaper.blurred,
                        "support popup uses the wallpaper, texture and blur settings");
                    test.check(test.named("projectSupportCard").radius===8,"popup follows the panel corner radius");
                    test.check(test.named("panelHeader").opacity<1 && test.named("panelFooter").opacity<1,"background content is muted without an inset rectangle");
                    test.capture("wallpaper",function() {test.dismissModal();test.click(test.named("updateSwitch"));});break;
                case 53:
                    var confirmationWallpaper=test.find(test.named("updateOffCard"),"dropdownWallpaper");
                    test.check(confirmationWallpaper && confirmationWallpaper.ready && confirmationWallpaper.textured && confirmationWallpaper.blurred,
                        "notification confirmation uses the same styled surface");
                    test.capture("wallpaper-confirmation",function() {
                        test.dismissModal();host.persistSettings({panelStyle:"glass"});test.click(test.named("authorCredit"));
                    });break;
                case 54:
                    test.check(!test.named("projectSupportCard").wallpaperMode
                        && test.named("projectSupportCard").color===host.surfaces.pickerBackground,"glass popup uses the shared readable popover tint");
                    var glassTexture=test.find(test.named("projectSupportCard"),"dropdownWallpaper");
                    test.check(glassTexture && !glassTexture.wallpaper && glassTexture.textured,"glass popup retains grain without a wallpaper image");
                    test.capture("glass",function() {test.dismissModal();});break;
                case 55:
                    test.check(test.named("panelHeader").opacity===1 && test.named("panelFooter").opacity===1,"closing restores background presentation");
                    console.info("WINDOWPEEK_TEST_PASS: navigation, focus, support links, errors and project popup");
                    stop(); Qt.quit();
                }
            } catch(error) { console.error("WINDOWPEEK_TEST_FAIL at " + (test.step-1) + ": " + error); stop(); Qt.quit(); }
        }
    }
}
