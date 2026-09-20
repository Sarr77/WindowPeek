import QtQuick
import Quickshell
import "WindowPeek" as Plugin
import "WindowPeek/Settings.js" as Settings

ShellRoot {
  id: suite
  Plugin.Preferences { id: preferences }
  property string scenario: Quickshell.env("WINDOWPEEK_PREFERENCES_CASE")
  function check(value, message) { if (!value) throw new Error(message); }
  Timer {
    interval:50; running:true; repeat:true
    onTriggered: {
      if (!preferences.ready) return;
      try {
        if (suite.scenario === "corrupt") {
          suite.check(preferences.failed && preferences.readBlocked, "bad JSON reported");
          suite.check(!preferences.save({language:"pl"}), "bad file cannot be silently overwritten");
        } else if (suite.scenario === "readonly") {
          suite.check(!preferences.failed && preferences.values.language === "pl", "readable file loaded");
          suite.check(!Settings.hints(preferences.values).enabled && preferences.values.hintsMode === "off",
            "manual hint dismissal survives another restart");
          suite.check(!preferences.save({language:"fr"}) && preferences.failed, "failed write is reported");
          suite.check(preferences.values.language === "pl", "failed write preserves last known data");
        } else if (suite.scenario === "restore") {
          suite.check(!preferences.failed && preferences.values.language === "pl" && preferences.values.hintsUsed === 200,
            "next process loads the last completed write");
          suite.check(preferences.values.includeSpecial && preferences.values.barLabel === "name", "WindowPeek choices restored");
          suite.check(preferences.values.scrollBounce === false, "disabled springy scrolling survives restart");
          suite.check(preferences.values.windowPreviews === false, "disabled window previews survive restart");
          suite.check(preferences.values.labelStyle === "custom" && preferences.values.customLabels.barText === "Okna {count}",
            "custom text survives a process restart");
          suite.check(Settings.hints(preferences.values).enabled && preferences.values.hintsMode === "on",
            "manual hints remain enabled after restart despite an exhausted budget");
          suite.check(preferences.save(Settings.merge(preferences.values, {hintsMode:"off"}, "sarr.windowpeek")), "manual off saves");
        } else {
          suite.check(!preferences.failed, "first start without file works");
          suite.check(preferences.save({id:"sarr.windowpeek",language:"de",hintsUsed:199,hintsMode:"auto"}), "first save");
          suite.check(preferences.save({id:"sarr.windowpeek",language:"pl",hintsUsed:200,hintsMode:"on",includeSpecial:true,barLabel:"name",scrollBounce:false,windowPreviews:false,
            labelStyle:"custom",customLabels:{barText:"Okna {count}"}}), "rapid second save");
        }
        console.info("WINDOWPEEK_TEST_PASS"); stop(); Qt.quit();
      } catch (error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
    }
  }
}
