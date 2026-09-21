import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin
import "WindowPeek/vendor/omarchy" as Choice
import "WindowPeek/I18n.js" as I18n

ShellRoot {
    id: test
    property int step: 0
    property int kind: 0
    property int backgroundIndex: 0
    readonly property var backgrounds: ["solid", "wallpaper", "glass", "wallpaper"]
    property bool capturing: false
    property var scrollList: null
    property real previousY: 0
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    readonly property var picker: kind ? searchable : plain
    function check(ok, message) { if (!ok) throw new Error(message + " (picker " + kind + ")"); }
    function click() { events.mouseClick(picker, picker.width / 2, picker.height - 10, Qt.LeftButton, Qt.NoModifier, 0); }
    function find(item, name) {
        if (item.objectName === name && item.visible) return item;
        for (var child of item.children || []) { var result = find(child, name); if (result) return result; }
        return null;
    }
    function options(count) {
        return Array.from({length:count}, function(_, i) {
            return {value:String(i),label:(i < 4 ? "Match " : "Other ") + (i+1),description:"Detail " + (i+1)};
        });
    }
    function wheel(down) {
        previousY = scrollList.contentY;
        check(events.mouseWheel(scrollList,30,scrollList.height/2,Qt.NoButton,Qt.NoModifier,0,down ? -120 : 120,0),
            "wheel event delivered to options");
    }
    function stationary() {
        check(Math.abs(scrollList.contentY - previousY) < .01,"a fully visible list stays still under the wheel ("
            + previousY + " -> " + scrollList.contentY + ", content " + scrollList.contentHeight + ", viewport " + scrollList.height + ")");
        check(settingsScroll.contentY === 0,"wheel does not move the editor underneath");
    }
    TestEvent { id: events }
    FakeHost { id: host; wallpaperSource: Qt.resolvedUrl("dropdown-wallpaper.svg") }
    Window {
        id: window; visible: true; width: 520 * test.scale; height: 600 * test.scale
        color: Color.popups.background
        Item {
            width: 520; height: 600; scale: test.scale; transformOrigin: Item.TopLeft
            Rectangle {
                anchors.fill: parent; visible: host.panelStyle === "glass"
                gradient: Gradient {
                    GradientStop { position: 0; color: test.backgroundIndex === 3 ? "#c4a7e7" : "#513976" }
                    GradientStop { position: 0.5; color: "#cb6479" }
                    GradientStop { position: 1; color: "#d9bd83" }
                }
            }
            Plugin.WallpaperBackdrop {
                anchors.fill: parent; visible: host.panelStyle === "wallpaper"
                source: host.wallpaperSource; palette: host.surfaces
                screenSize: Qt.size(window.width,window.height); displayScale: test.scale
                tintOpacity: 1 - host.wallpaperTransparency / 100
            }
            Text { x: 30; y: 235; text: "Content behind the open list"; color: "white"; font.pixelSize: 22; visible: host.glassPanels }
            Flickable {
              id: settingsScroll; anchors.fill: parent; contentHeight: 900
              boundsBehavior: Flickable.StopAtBounds
              Column {
                x: 20; y: 20; width: 400; spacing: 20
                Choice.Dropdown {
                    id: plain; width: parent.width; label: "List density"; uiScale: test.scale
                    hostWidget: host; accent: host.accent
                    value: "spacious"; options: ["spacious", "compact"]
                }
                Choice.SearchableDropdown {
                    id: searchable; width: parent.width; label: "Language"; uiScale: test.scale
                    hostWidget: host; accent: host.accent
                    value: "en"; options: I18n.options("en", "en")
                    rowHeight: 36; popupRowHeight: 36; placeholderText: "Search languages..."
                }
              }
            }
            Binding { target: plain.QQC.Overlay.overlay; property: "transformOrigin"; value: Item.TopLeft }
            Binding { target: plain.QQC.Overlay.overlay; property: "scale"; value: test.scale }
        }
    }
    Timer {
        interval: 120; running: true; repeat: true
        onTriggered: {
            if (test.capturing) return;
            try {
                switch (test.step++) {
                case 0:
                    Color.shellValues = ({});
                    Color.foreground = test.backgroundIndex === 3 ? "#303446" : "#c0caf5";
                    Color.background = test.backgroundIndex === 3 ? "#eff1f5" : "#1a1b26";
                    host.themeId = test.backgroundIndex === 3 ? "catppuccin-latte" : "tokyo-night";
                    host.themeAccent = test.backgroundIndex === 3 ? "#8839ef" : "#7aa2f7";
                    host.persistSettings({panelStyle:test.backgrounds[test.backgroundIndex]});
                    test.click(); break;
                case 1:
                    test.check(test.picker.popupOpen, "first click opens the picker");
                    var backing = test.find(test.picker.QQC.Overlay.overlay,"dropdownBackground");
                    test.check(!!backing, "open dropdown has a rendered background");
                    if (host.panelStyle === "wallpaper") {
                        var wallpaper = test.find(backing,"dropdownWallpaper");
                        test.check(wallpaper && wallpaper.ready && backing.color.a === 1,"wallpaper is painted over an opaque backing");
                        var origin = wallpaper.mapToItem(window.contentItem,0,0);
                        test.check(Math.abs(wallpaper.screenOrigin.x-origin.x)<.01 && Math.abs(wallpaper.screenOrigin.y-origin.y)<.01,
                            "wallpaper crop follows popup position at the current UI scale");
                        test.check(wallpaper.screenSize.width === window.width && wallpaper.screenSize.height === window.height,
                            "wallpaper uses the same window canvas as the panel");
                        test.check(Math.abs(wallpaper.mapToItem(window.contentItem,10,10).x-origin.x-10)<.01,
                            "background effects stay in window pixels even when options are scaled");
                    } else {
                        test.check(host.glassPanels
                            ? backing.color.a >= .9 && backing.color.a < 1 && backing.color !== Color.popups.background
                            : backing.color === Color.popups.background,
                            "Transparency retains its tint; Solid retains the theme surface");
                    }
                    if (test.kind) {
                        var overlay = searchable.QQC.Overlay.overlay;
                        var header = test.find(overlay, "searchHeader");
                        var list = test.find(overlay, "resultList");
                        test.check(header && list && list.mapToItem(header, 0, 0).y >= header.height,
                            "language results begin below the search field");
                        test.check(list.height > 0 && list.clip, "language results have a clipped viewport");
                        if (Quickshell.env("WINDOWPEEK_TEST_IMAGE")) {
                            test.capturing = true;
                            window.contentItem.grabToImage(function(result) {
                                var name = test.backgroundIndex === 0 ? "" : "-" + test.backgrounds[test.backgroundIndex]
                                    + (test.backgroundIndex === 3 ? "-light" : "") + ".png";
                                test.check(result.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE") + name), "image saved");
                                test.capturing = false; test.click();
                            });
                            break;
                        }
                    }
                    test.click(); break;
                case 2:
                    test.check(!test.picker.popupOpen, "second click closes the picker without reopening");
                    test.click(); break;
                case 3:
                    test.check(test.picker.popupOpen, "third click opens again");
                    events.mouseClick(window.contentItem, window.width - 10, window.height - 10, Qt.LeftButton, Qt.NoModifier, 0); break;
                case 4:
                    test.check(!test.picker.popupOpen, "outside click closes the picker");
                    test.click(); break;
                case 5: events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0); break;
                case 6:
                    test.check(!test.picker.popupOpen, "Escape closes the picker");
                    test.click(); test.click(); break;
                case 7:
                    test.check(!test.picker.popupOpen, "rapid repeated click stays closed");
                    test.check(test.picker.value === (test.kind ? "en" : "spacious"), "opening and closing does not change the choice");
                    if (test.kind++ === 0) { test.step = 0; break; }
                    if (++test.backgroundIndex < test.backgrounds.length) { test.kind = 0; test.step = 0; break; }
                    // Native checks cover rendering and popup interaction.
                    // Exact viewport sizes below belong to the isolated test:
                    // a tiling compositor can resize the fixture independently.
                    if (Quickshell.env("QT_QPA_PLATFORM") === "wayland") {
                        console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit(); break;
                    }
                    test.kind = 0; plain.options = test.options(6); plain.value = "0";
                    test.click(); break;
                case 8:
                    test.scrollList = test.find(plain.QQC.Overlay.overlay,"optionList");
                    test.check(!!test.scrollList,"plain option list is available");
                    test.wheel(true); break;
                case 9:
                    test.stationary();
                    test.check(test.scrollList.contentHeight <= test.scrollList.height + .01,"short options fit with their border and padding");
                    test.wheel(false); break;
                case 10:
                    test.stationary();
                    plain.close(); plain.options = test.options(20); test.click(); break;
                case 11:
                    test.check(test.scrollList.contentHeight > test.scrollList.height,"long lists still overflow");
                    test.wheel(true); break;
                case 12:
                    test.check(test.scrollList.contentY > test.previousY,"long lists still scroll");
                    test.scrollList.positionViewAtEnd(); test.wheel(true); break;
                case 13:
                    test.stationary();
                    plain.close(); window.height = 220 * test.scale; plain.options = test.options(6); test.click(); break;
                case 14:
                    test.check(test.scrollList.contentHeight > test.scrollList.height,"screen constraints can make a short list scrollable");
                    test.wheel(true); break;
                case 15:
                    test.check(test.scrollList.contentY > test.previousY,"constrained short lists still scroll");
                    test.check(settingsScroll.contentY === 0,"constrained scrolling stays inside the menu");
                    plain.close(); window.height = 600 * test.scale;
                    test.kind = 1; searchable.options = test.options(20); searchable.value = "0"; test.click(); break;
                case 16:
                    test.scrollList = test.find(searchable.QQC.Overlay.overlay,"resultList");
                    test.find(searchable.QQC.Overlay.overlay,"dropdownSearchField").text = "Match"; break;
                case 17:
                    test.check(test.scrollList.count === 4,"filter leaves four described results");
                    test.wheel(true); break;
                case 18:
                    test.stationary();
                    test.check(test.scrollList.contentHeight <= test.scrollList.height + .01,"filtered results fit below the actual search header");
                    test.find(searchable.QQC.Overlay.overlay,"dropdownSearchField").text = "No results"; break;
                case 19:
                    test.check(test.scrollList.count === 0,"empty filter");
                    test.wheel(true); break;
                case 20:
                    test.stationary();
                    test.find(searchable.QQC.Overlay.overlay,"dropdownSearchField").text = "Match"; break;
                case 21:
                    for (var key = 0; key < 4; key++) events.keyClick(Qt.Key_Down,Qt.NoModifier,0);
                    events.keyClick(Qt.Key_Return,Qt.NoModifier,0); break;
                case 22:
                    test.check(searchable.value === "3" && !searchable.popupOpen,"keyboard still selects the last visible result");
                    console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL at " + (test.step - 1) + ": " + error); stop(); Qt.quit(); }
        }
    }
}
