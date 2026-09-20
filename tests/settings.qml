import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui as Ui
import "WindowPeek" as Plugin

ShellRoot {
  id: suite
  property string scenario: Quickshell.env("WINDOWPEEK_PREFERENCES_CASE")
  property string expectedLanguage: Quickshell.env("WINDOWPEEK_EXPECTED_LANGUAGE") || "pl"
  readonly property bool startupCase: scenario.indexOf("startup-") === 0
  readonly property var startupEntry: ({id:"sarr.windowpeek", includeSpecial:false, language:"pl",
    autoUpdates:false, windowPreviews:false, hintsMode:"auto", hintsUsed:37, uiScale:1.25,
    panelHoverDelay:0, previewHoverDelay:1250, popupAnimations:false, openOnHover:false,
    customLabels:{barText:"My windows"}, _windowpeekRevision:1})
  property var pendingHostSettings: null
  property bool showedUnsavedChoice: false
  function clone(value) { return JSON.parse(JSON.stringify(value)); }
  function check(value, message) { if (!value) throw new Error(message); }
  function finish() { console.info("WINDOWPEEK_PREFERENCES_PASS"); Qt.quit(); }
  function hostChange(values) {
    var entry = clone(host.saved);
    Object.keys(values).forEach(function(key) { entry[key] = values[key]; });
    host.saved = clone(entry);
    host.deliver(entry);
    return entry;
  }
  function checkHostSave() {
    check(!one.autoUpdates && !two.autoUpdates, "host choice reaches both monitors");
    check(one.languageSetting === "de" && two.languageSetting === "de", "host language reaches both monitors");
    check(Plugin.Runtime.preferences.values.autoUpdates === false, "host choice is durably saved");
    check(!Plugin.Runtime.updates.enabled, "update worker sees disabled updates");
    check(!Plugin.Runtime.preferences.failed, "host save completed without an error");
    check(!showedUnsavedChoice, "controls never present an unsaved update choice");
  }
  function checkStartupValues(language) {
    [one, two].forEach(function(widget) {
      suite.check(widget.includeSpecial === false, "startup keeps the special workspace preference");
      suite.check(widget.languageSetting === language && !widget.autoUpdates, "startup keeps language and update choice");
      suite.check(widget.hints.used === 37 && widget.hints.mode === "auto", "startup keeps hint progress");
      suite.check(!widget.windowPreviews && widget.uiScale === 1.25, "startup keeps layout choices");
      suite.check(widget.panelHoverDelay === 0 && widget.previewHoverDelay === 1250 && !widget.popupAnimations && !widget.openOnHover,
        "startup and write retries keep independent delays, including zero and disabled animations");
      suite.check(widget.savedLabels.customLabels.barText === "My windows", "startup keeps nested preferences");
    });
  }

  QtObject {
    id: host
    property var saved: suite.scenario === "removed-entry" || suite.scenario === "startup-restored"
      ? ({id:"sarr.windowpeek"}) : (suite.startupCase ? suite.clone(suite.startupEntry)
        : ({id:"sarr.windowpeek", autoUpdates:true, language:"en", _windowpeekRevision:1}))
    property int calls: 0
    function deliver(entry) {
      // Bar.applySettingsDelta sends one snapshot to every live widget. The
      // first recipient may save and publish before the second receives it.
      one.settings = suite.clone(entry);
      two.settings = suite.clone(entry);
    }
    function updateEntryInline(id, entry) {
      calls++;
      if (suite.scenario === "mirror-error") throw new Error("unavailable host");
      if (suite.scenario === "mirror-rejected") return false;
      if (JSON.stringify(saved) === JSON.stringify(entry)) return false;
      saved = suite.clone(entry);
      deliver(suite.clone(entry));
      return true;
    }
  }
  Ui.PluginBarApi {
    id: bar
    pluginId: "sarr.windowpeek"; moduleName: pluginId
    shell: host
    layoutConfig: ({left:[host.saved], center:[], right:[]})
    _moduleWidgets: function() { return [one, two]; }
  }
  Plugin.Widget { id: one; visible: false; bar: bar }
  Plugin.Widget { id: two; visible: false; bar: bar }
  Connections {
    target: one
    function onAutoUpdatesChanged() {
      if (one.settingsReady && Plugin.Runtime.preferences.hasSavedValues
          && one.autoUpdates !== Plugin.Runtime.preferences.values.autoUpdates)
        suite.showedUnsavedChoice = true;
    }
  }
  Process {
    id: repair
    command: ["chmod", "700", Plugin.Runtime.preferences.directory]
    onExited: function(code) {
      try {
        suite.check(code === 0, "test directory made writable");
        if (suite.startupCase) {
          if (suite.scenario === "startup-readonly-host") suite.hostChange({language:"de"});
          else if (suite.scenario === "startup-readonly-same")
            suite.check(one.persistSettings({}), "unchanged startup settings can be retried");
          else suite.check(one.setLanguage("de"), "partial panel edit retries the first save");
          suite.checkStartupValues(suite.expectedLanguage);
          var preferences = Plugin.Runtime.preferences;
          suite.check(preferences.hasSavedValues && !preferences.failed, "retry establishes a saved configuration");
          suite.check(preferences.values.includeSpecial === false && preferences.values.language === suite.expectedLanguage,
            "retry saves the full original host entry with the requested change");
          suite.check(!Plugin.Runtime.updates.enabled, "retry preserves disabled updates");
          suite.check(!suite.showedUnsavedChoice, "retry applies only saved choices");
          suite.finish();
          return;
        }
        if (suite.scenario === "readonly-host") {
          host.saved = suite.clone(suite.pendingHostSettings);
          host.deliver(suite.pendingHostSettings);
          suite.checkHostSave();
          suite.finish();
          return;
        }
        // Retry the identical value: FileView's cached text may be from the failed write.
        one.toggleUpdates();
        suite.check(!one.saveFailed && !one.autoUpdates && !two.autoUpdates, "retry commits on both monitors");
        suite.check(Plugin.Runtime.preferences.values.autoUpdates === false, "worker sees the successful retry");
        suite.check(host.saved.autoUpdates === false, "host mirror follows the retry");
        suite.finish();
      } catch (error) { console.error("WINDOWPEEK_PREFERENCES_FAIL: " + error); Qt.quit(); }
    }
  }
  Timer {
    interval: 50; running: true; repeat: true
    onTriggered: {
      if (!one.settingsReady || !two.settingsReady) return;
      stop();
      try {
        var preferences = Plugin.Runtime.preferences;
        if (suite.scenario === "startup-restored") {
          suite.checkStartupValues(suite.expectedLanguage);
          suite.check(preferences.hasSavedValues && !preferences.failed, "repaired preferences load on restart");
          suite.check(host.saved.includeSpecial === false && host.saved.autoUpdates === false,
            "restored preferences rebuild the removed host entry");
          suite.finish();
          return;
        }
        if (suite.startupCase) {
          suite.check(preferences.failed && !preferences.hasSavedValues, "startup reports the unavailable preference file");
          suite.checkStartupValues("pl");
          suite.check(!Plugin.Runtime.updates.enabled, "unavailable preferences cannot start an update");
          suite.check(!one.setLanguage("fr"), "panel edit cannot bypass the failed save");
          suite.hostChange({includeSpecial:true, language:"de", autoUpdates:true});
          suite.checkStartupValues("pl");
          suite.check(JSON.stringify(host.saved) === JSON.stringify(suite.startupEntry), "failed host edit restores every original field");
          suite.check(!preferences.hasSavedValues && !Plugin.Runtime.updates.enabled,
            "fallback is never presented to the worker as a successful file save");
          if (suite.scenario.indexOf("startup-readonly-") === 0) repair.running = true;
          else suite.finish();
          return;
        }
        if (suite.scenario === "restored-settings" || suite.scenario === "removed-entry") {
          suite.check(!one.autoUpdates && !two.autoUpdates, "cold start restores disabled updates despite an older host mirror");
          suite.check(one.languageSetting === suite.expectedLanguage && two.languageSetting === suite.expectedLanguage, "cold start restores other preferences");
          suite.check(host.saved.autoUpdates === false, "cold start repairs the stale host mirror");
          suite.finish();
          return;
        }
        suite.check(one.autoUpdates && two.autoUpdates, "initial updates enabled");
        var previous = JSON.stringify(preferences.values), calls = host.calls;
        if (suite.scenario === "host-change" || suite.scenario === "readonly-host") {
          var stale = suite.clone(host.saved);
          suite.pendingHostSettings = suite.hostChange({autoUpdates:false, language:"de"});
          if (suite.scenario === "readonly-host") {
            suite.check(preferences.failed, "host write failure reported");
            suite.check(one.autoUpdates && two.autoUpdates && !suite.showedUnsavedChoice, "failed host choice is never applied");
            suite.check(JSON.stringify(preferences.values) === previous, "failed host edit leaves saved values unchanged");
            suite.check(host.saved.autoUpdates === true && host.saved.language === "pl", "host copy rolled back after disk failure");
            repair.running = true;
            return;
          }
          suite.checkHostSave();
          var revision = preferences.values._windowpeekRevision;
          suite.check(revision > stale._windowpeekRevision, "host edit advances the saved revision");
          // Repeat notifications, then a delayed pre-edit snapshot.
          var publishedCalls = host.calls;
          host.deliver(suite.clone(host.saved));
          suite.check(host.calls === publishedCalls, "identical host echoes do not publish again");
          host.deliver(stale);
          suite.checkHostSave();
          suite.check(preferences.values._windowpeekRevision === revision, "host echoes do not create new revisions");
          suite.check(host.calls - publishedCalls <= 2, "each monitor repairs a stale copy without recursive publishing");
          suite.hostChange({autoUpdates:true});
          suite.check(one.autoUpdates && two.autoUpdates && Plugin.Runtime.updates.enabled, "host can re-enable updates");
          suite.check(two.setHintsMode("off"), "panel edits can follow a host edit on another monitor");
          suite.hostChange({autoUpdates:false});
          suite.checkHostSave();
          suite.check(one.hints.mode === "off" && two.hints.mode === "off", "host changes preserve later panel edits");
          suite.finish();
          return;
        }
        one.toggleUpdates();
        if (suite.scenario === "readonly-settings") {
          suite.check(one.saveFailed && preferences.failed, "disk write failure reported");
          suite.check(one.autoUpdates && two.autoUpdates, "disk failure leaves both switches enabled");
          suite.check(JSON.stringify(preferences.values) === previous, "worker preferences unchanged");
          suite.check(host.calls === calls, "disk failure never reaches the host mirror");
          suite.check(preferences.save(preferences.values), "keeping the saved value clears the failed cache");
          repair.running = true;
        } else {
          suite.check(!one.saveFailed && !one.autoUpdates && !two.autoUpdates, "durable save succeeds independently of host mirror");
          suite.check(preferences.values.autoUpdates === false, "worker and UI agree");
          suite.check(host.saved.autoUpdates === true, "host fixture remained stale");
          suite.check(one.languageSetting === "pl" && two.languageSetting === "pl", "unrelated preference preserved");
          suite.finish();
        }
      } catch (error) { console.error("WINDOWPEEK_PREFERENCES_FAIL: " + error); Qt.quit(); }
    }
  }
}
