import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons
import "WindowPeek" as Plugin
import "WindowPeek/Appearance.js" as Appearance
import "WindowPeek/I18n.js" as I18n

ShellRoot {
  id: testRoot
  property int languageIndex: 0
  function check(value, message) { if (!value) throw new Error(message); }
  function find(item, name) {
    if (item.objectName === name) return item;
    for (var i = 0; i < item.children.length; i++) {
      var result = find(item.children[i], name);
      if (result) return result;
    }
    return null;
  }
  FakeHost { id: host }
  Window {
    id: window
    visible: true
    width: 420; height: 1080
    color: Color.popups.background
    Plugin.AppearanceEditor { id: editor; x: 16; y: 16; width: parent.width-32; hostWidget: host }
  }
  Timer {
    interval: 500; running: true
    onTriggered: {
      try {
        editor.begin();
        testRoot.check(!editor.colorsExpanded, "settings must start collapsed");
        testRoot.check(editor.mode === "adaptive" && String(host.accent) === "#d898f5", "default adapted color");
        testRoot.check(testRoot.find(editor,"colorPlane").y < testRoot.find(editor,"hexInput").parent.y, "palette must stay first");
        editor.changeRule("theme", "theme", "");
        testRoot.check(String(host.accent) === "#7aa2f7", "exact theme preview");
        // Another monitor can change list layout while this color draft is open.
        host.saveAppearance({tooltipStyle: "compact", uiScale: 1.2, barScale: 1.1});
        testRoot.find(editor,"hexInput").text = "#zz";
        editor.validHex = false;
        var restore = testRoot.find(editor,"restoreSavedColorButton");
        testRoot.check(restore.text === "Restore saved color · #D898F5", "button shows saved color, not theme accent");
        restore.clicked();
        testRoot.check(editor.validHex && editor.mode === "adaptive", "restore repairs invalid input and restores mode");
        testRoot.check(String(host.accent) === "#d898f5" && host.appearance.tooltipStyle === "compact", "color restore preserves saved density");
        editor.cancel();
        testRoot.check(String(host.accent) === "#d898f5", "cancel restores saved default");
        editor.begin();
        editor.colorsExpanded = true;
        editor.choosePreset({color:"#ff8800"});
        var preset = testRoot.find(editor, "defaultColorPreset");
        testRoot.check(preset.hexText === "#D898F5" && String(preset.swatch) === "#d898f5",
            "default preset shows its own color while a different color is selected");
        editor.editPreset("");
        testRoot.find(editor,"presetNameInput").text = "Amber";
        editor.savePreset();
        testRoot.check(editor.draft.colorPresets.length === 1, "preset draft added");
        testRoot.check(host.savedAppearance.colorPresets.length === 0, "preset not saved before Apply");
        var id = editor.selectedPresetId;
        testRoot.find(editor,"restoreSavedColorButton").clicked();
        testRoot.check(editor.draft.colorPresets.length === 1 && String(host.accent) === "#d898f5", "restore preserves unsaved preset");
        editor.choosePreset(editor.draft.colorPresets[0]);
        editor.editPreset(id);
        testRoot.find(editor,"presetNameInput").text = "Warm amber";
        editor.savePreset();
        host.saveAppearance({tooltipStyle: "panel", uiScale: 1.4});
        editor.apply();
        testRoot.check(host.savedAppearance.tooltipStyle === "panel" && host.savedAppearance.uiScale === 1.4,
            "color Apply does not overwrite newer density or scale");
        host.saveAppearance({tooltipStyle: "compact", uiScale: 1.2});
        testRoot.check(host.savedAppearance.colorPresets[0].name === "Warm amber", "rename and Apply persist");
        testRoot.check(String(host.accent) === "#ff8800", "Apply persists custom color");
        testRoot.check(host.savedAppearance.tooltipStyle === "compact" && host.savedAppearance.uiScale === 1.2
            && host.savedAppearance.barScale === 1.1, "color Apply preserves independent list and scale settings");
        editor.begin();
        editor.editPreset(id); editor.deletePreset();
        testRoot.check(editor.draft.colorPresets.length === 0, "delete in draft");
        editor.cancel();
        testRoot.check(host.savedAppearance.colorPresets.length === 1, "Cancel undoes deletion");
        editor.begin();
        host.themeId = "hackerman"; host.themeAccent = "#82FB9C";
        testRoot.check(editor.mode === "adaptive" && String(host.accent) === "#82fb9c", "theme change updates open editor");
        host.themeId = "tokyo-night"; host.themeAccent = "#7AA2F7";
        testRoot.check(editor.mode === "custom" && String(host.accent) === "#ff8800", "return restores theme choice");
        testRoot.check(editor.savedColor === "#FF8800", "restore target follows last Apply");
        host.rejectSave = true;
        editor.choosePreset({color:"#123456"}); editor.apply();
        testRoot.check(editor.saveFailed, "failed save remains editable");
        testRoot.check(host.savedAppearance.themeColors["tokyo-night"].color === "#FF8800", "failed save preserves disk state");
        host.rejectSave = false; editor.cancel();
        host.language = "pl"; editor.begin();
        testRoot.check(testRoot.find(editor,"colorModePicker").options[0].label === "Dopasowany (domyślny)", "translated controls");
        editor.changeRule("adaptive", "theme", "");
        editor.apply(); editor.begin();
        editor.colorsExpanded = true;
        host.language = I18n.languages[0].code;
        languageCheck.start();
      } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); Qt.quit(); }
    }
  }
  Timer {
    id: languageCheck
    interval: 20
    onTriggered: {
      try {
        var preset = testRoot.find(editor, "defaultColorPreset");
        var hexLabel = testRoot.find(preset, "presetHex");
        testRoot.check(hexLabel.text === "· #D898F5" && hexLabel.width >= hexLabel.implicitWidth
            && hexLabel.x + hexLabel.width <= hexLabel.parent.width + 1,
            "preset keeps its full HEX visible in " + host.language);
        if (++testRoot.languageIndex < I18n.languages.length) {
          host.language = I18n.languages[testRoot.languageIndex].code;
          restart(); return;
        }
        host.language = "en";
        preset.clicked();
        testRoot.check(String(host.accent) === "#d898f5", "default preset selects the displayed color");
        console.info("WINDOWPEEK_TEST_PASS");
        var destination = Quickshell.env("WINDOWPEEK_TEST_IMAGE");
        if (destination) editor.grabToImage(function(result) { result.saveToFile(destination); Qt.quit(); });
        else Qt.quit();
      } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); Qt.quit(); }
    }
  }
}
