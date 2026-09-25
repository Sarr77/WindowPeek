import QtQuick
import Quickshell
import "WindowPeek" as Plugin

ShellRoot {
  id: suite
  Plugin.Preferences { id: preferences }
  property bool started: false
  property int completions: 0
  property string scenario: Quickshell.env("WINDOWPEEK_PREFERENCES_CASE")
  function check(value, message) { if (!value) throw new Error(message); }
  Timer {
    interval:50; running:true; repeat:true
    onTriggered: {
      if (!preferences.ready) return;
      try {
        if (suite.started) {
          if (preferences.saving) return;
          if (suite.scenario === "readonly") {
            suite.check(preferences.failed && preferences.values.language === "pl", "failed async write preserves committed values");
          } else if (suite.scenario !== "corrupt") suite.check(!preferences.failed, "all queued writes completed");
          console.info("WINDOWPEEK_PREFERENCES_PASS"); stop(); Qt.quit(); return;
        }
        suite.started = true;
        if (suite.scenario === "corrupt") {
          suite.check(preferences.failed && preferences.readBlocked, "bad JSON reported");
          suite.check(!preferences.hasSavedValues, "bad JSON is not an empty saved configuration");
          suite.check(!preferences.save({language:"pl"}), "bad file cannot be silently overwritten");
        } else if (suite.scenario === "empty") {
          suite.check(preferences.hasSavedValues && !preferences.failed, "empty but valid settings are a saved configuration");
          suite.check(preferences.save({}), "unchanged empty settings remain valid");
        } else if (suite.scenario === "readonly") {
          suite.check(!preferences.failed && preferences.values.language === "pl", "readable file loaded");
          suite.check(preferences.save({language:"fr"}), "async write accepted for verification");
          suite.check(preferences.values.language === "pl", "failed write preserves last known data");
        } else if (suite.scenario === "restore") {
          suite.check(!preferences.failed && preferences.values.language === "pl" && preferences.values.hintsUsed === 99,
            "next process loads the last completed write");
          suite.check(preferences.values.customLabels.barText === "My shelf", "custom labels restored");
        } else {
          suite.check(!preferences.failed && !preferences.hasSavedValues, "first start without file works");
          suite.check(preferences.save({id:"sarr.windowpeek",language:"de",hintsUsed:98}), "first save");
          suite.check(!preferences.hasSavedValues, "enqueue does not pretend that a write has completed");
          suite.check(preferences.save({id:"sarr.windowpeek",language:"pl",hintsUsed:99,customLabels:{barText:"My shelf"}}), "rapid second save");
        }
        // The next tick checks the durable outcome after the queue settles.
      } catch (error) { console.error("WINDOWPEEK_PREFERENCES_FAIL: " + error); stop(); Qt.quit(); }
    }
  }
}
