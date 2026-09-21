import QtQuick
import qs.Commons
import "Appearance.js" as Appearance

QtObject {
    id: root
    property var appearance: ({})
    property string themeId: ""
    property string panelStyle: "solid"
    property color accent: Color.accent
    function rule(target) { return Appearance.surfaceRuleFor(appearance, target, themeId); }
    function baseColor(target) {
        // Appearance stores RGB; Qt serializes translucent colors as #AARRGGBB.
        if (target === "panel" || target === "windows") return String(Qt.alpha(Color.popups.background, 1));
        if (target === "menu") return String(accent);
        return "#FFFFFF";
    }
    function colorFor(target) {
        if (target === "panel" && panelStyle === "solid" && !rule(target).color && rule(target).brightness === 0)
            return Color.popups.background;
        return Appearance.brighten(Appearance.surfaceColor(appearance,target,themeId,baseColor(target)), rule(target).brightness);
    }
    function defaultOpacity(target) {
        if (target === "windows") return panelStyle === "solid"
            ? (rule(target).color || rule(target).brightness !== 0 ? 100 : 0) : 52;
        if (target === "menu") return 3.5;
        if (target === "grain") return 4.5;
        return 100;
    }
    function opacityFor(target) {
        var value = rule(target).opacity;
        return (value === null ? defaultOpacity(target) : value) / 100;
    }
    readonly property color panel: colorFor("panel")
    readonly property color windows: colorFor("windows")
    readonly property real windowOpacity: opacityFor("windows")
    readonly property color menu: colorFor("menu")
    readonly property var menuRule: rule("menu")
    readonly property bool customMenu: !!menuRule.color || menuRule.brightness !== 0 || menuRule.opacity !== null
    readonly property real menuOpacity: opacityFor("menu")
    // Popovers cover other controls: keep stronger coverage than the main panel
    // while giving non-solid modes a gentle tint from the current menu color.
    readonly property color pickerBackground: panelStyle === "solid" ? Color.popups.background
        : Qt.alpha(Qt.tint(panel, Qt.alpha(menu, 0.16)), 0.94)
    readonly property color grain: colorFor("grain")
    readonly property bool customGrain: !!rule("grain").color || rule("grain").brightness !== 0
    readonly property real grainOpacity: opacityFor("grain")
    readonly property real wallpaperBrightness: rule("wallpaper").brightness / 100
}
