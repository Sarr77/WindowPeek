import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC
import QtTest
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance
import "WindowPeek/I18n.js" as I18n

ShellRoot {
    id: test
    property int step: 0
    property int locale: 0
    property int group: 0
    property var editor: null
    property string originalMove: ""
    readonly property real scale: Number(Quickshell.env("WINDOWPEEK_TEST_SCALE")) || 1
    function check(value, message) { if (!value) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var i = 0; i < item.children.length; i++) { var result = find(item.children[i], name); if (result) return result; }
        return null;
    }
    function openEditor() {
        panel.showSettings(); find(panel, "openLabelsButton").clicked();
        editor = find(panel, "labelsEditor");
        check(editor && editor.style === host.savedLabels.labelStyle, "editor loads the saved draft on each opening");
    }
    TestEvent { id: events }
    FakeHost { id: host; Component.onCompleted: savedAppearance = Appearance.normalize({uiScale:test.scale}) }
    Window {
        id: window; visible: true; width: 950 * test.scale; height: 710 * test.scale
        color: Color.popups.background
        Rectangle {
            width: 950; height: 710; scale: test.scale; transformOrigin: Item.TopLeft
            color: Color.popups.background
            Plugin.PanelContent { id: panel; x: 20; y: 20; width: 468; height: 540; hostWidget: host }
            Plugin.TooltipContent { id: preview; x: 530; y: 20; width: 400; height: implicitHeight; maximumHeight: 670; hostWidget: host; interactive: false }
        }
        Binding { target: panel.QQC.Overlay.overlay; property: "scale"; value: test.scale; when: panel.QQC.Overlay.overlay !== null }
        Binding { target: panel.QQC.Overlay.overlay; property: "transformOrigin"; value: Item.TopLeft; when: panel.QQC.Overlay.overlay !== null }
    }
    Timer {
        interval: 70; repeat: true; running: true
        onTriggered: {
            try {
                switch (test.step++) {
                case 0:
                    test.originalMove = host.words.move;
                    panel.begin(); test.openEditor(); test.editor = test.find(panel, "labelsEditor");
                    test.editor.setStyle("custom"); break;
                case 1:
                    var input = test.find(test.editor, "labelInput_panelTitle");
                    input.forceActiveFocus();
                    events.keyClick(Qt.Key_A, Qt.NoModifier, 0); events.keyClick(Qt.Key_C, Qt.NoModifier, 0);
                    events.keyClick(Qt.Key_Left, Qt.NoModifier, 0); events.keyClick(Qt.Key_B, Qt.NoModifier, 0);
                    test.check(input.text === "abc" && input.cursorPosition === 2, "live preview preserves insertion position while typing");
                    test.check(host.textTemplates.panelTitle === "abc" && !host.savedLabels.customLabels.panelTitle, "typed heading previews without saving");
                    test.editor.setText("barText", "Okna {cout}");
                    test.check(!test.editor.valid && !test.find(test.editor, "applyLabelsButton").enabled, "unknown placeholder blocks Apply");
                    test.editor.apply(); test.check(panel.mode === "labels", "invalid draft stays editable");
                    test.editor.setText("barText", "Okna {count} · {monitor}");
                    test.editor.setText("move", "Wyślij");
                    test.editor.apply(); break;
                case 2:
                    test.check(panel.mode === "settings" && host.words.move === "Wyślij" && host.labelsPreview === null, "Apply saves and closes preview");
                    test.openEditor(); test.editor.setText("move", "Discard me");
                    panel.back(); test.check(host.words.move === "Wyślij", "Back discards a label draft");
                    test.openEditor(); test.editor.reset();
                    test.check(host.words.move === test.originalMove, "reset previews translated defaults");
                    test.editor.cancel(); test.check(host.words.move === "Wyślij", "Cancel undoes Reset");
                    test.openEditor(); test.editor.setText("move", "Escape draft");
                    test.find(test.editor, "labelInput_panelTitle").forceActiveFocus();
                    events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0);
                    test.check(panel.mode === "settings" && host.words.move === "Wyślij", "Escape from a text field cancels the draft");
                    test.openEditor(); host.rejectSave = true; test.editor.setText("move", "Unsaved"); test.editor.apply();
                    test.check(test.editor.saveFailed && panel.mode === "labels" && host.savedLabels.customLabels.move === "Wyślij", "failed write retains the editable draft and previous save");
                    host.rejectSave = false; test.editor.cancel();
                    test.openEditor(); test.editor.setText("move", "Dismissed"); panel.dismiss();
                    test.check(host.words.move === "Wyślij", "outside dismissal cancels labels");
                    panel.begin(); test.openEditor(); test.editor.setStyle("default"); test.editor.apply();
                    test.check(host.words.move === test.originalMove && host.savedLabels.customLabels.move === "Wyślij", "default style preserves inactive custom text");
                    test.openEditor(); test.editor.setStyle("custom"); test.editor.group = "actions";
                    test.editor.setText("move", "Przenieś ".repeat(20));
                    test.editor.setText("settings", "Ustawienia ".repeat(16));
                    test.editor.apply(); panel.back(); break;
                case 3:
                    var move = test.find(panel, "windowMove"), focus = test.find(panel, "windowFocus");
                    var settings = test.find(panel, "settingsButton");
                    test.check(focus.width > 200 && move.width < panel.width / 2, "long Move labels leave room for window contents");
                    test.check(settings.width <= panel.width * 0.4 && settings.text.length < host.words.settings.length, "long header actions elide within their own control");
                    test.openEditor(); test.editor.reset();
                    test.editor.setText("panelTitle", "My windows"); test.editor.setText("barText", "Windows: {count}");
                    test.editor.setText("workspaceLabel", "Desk {name}"); test.editor.setText("hiddenWorkspace", "Away");
                    break;
                case 4:
                    host.setLanguage(I18n.languages[test.locale].code);
                    test.editor.group = ["panel", "workspaces", "windows", "actions", "hints"][test.group++];
                    break;
                case 5:
                    test.check(test.editor.implicitHeight > 0 && test.editor.valid, "translated editor lays out in " + host.language);
                    test.check(host.textTemplates.panelTitle === "My windows", "language changes preserve custom text");
                    if (test.group < 5) test.step = 4;
                    else if (++test.locale < I18n.languages.length) { test.group = 0; test.step = 4; }
                    else { host.setLanguage("pl"); test.editor.group = "panel"; }
                    break;
                case 6:
                    console.info("WINDOWPEEK_TEST_PASS"); stop();
                    var image = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
                    if (image) window.contentItem.grabToImage(function(result) { result.saveToFile(image); Qt.quit(); });
                    else Qt.quit();
                }
            } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
