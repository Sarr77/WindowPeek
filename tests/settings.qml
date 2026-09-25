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
  property var continuation: null
  property var repaired: null
  function run(fn) { try { fn(); } catch (error) { console.error("WINDOWPEEK_PREFERENCES_FAIL: " + error); Qt.quit(); } }
  function settle(fn) { continuation = fn; later.start(); }
  Timer {
    id: later; interval:10; repeat:true
    onTriggered: {
      if (Plugin.Runtime.preferences.saving) return;
      stop(); var fn=suite.continuation; suite.continuation=null; suite.run(fn);
    }
  }
  Process {
    id: repair
    command:["chmod","700",Plugin.Runtime.preferences.directory]
    onExited:function(code) { suite.run(function() { suite.check(code===0,"directory repaired"); suite.repaired(); }); }
  }
  function start() {
    var preferences=Plugin.Runtime.preferences;
    if (scenario==="startup-restored") {
      checkStartupValues(expectedLanguage);
      check(preferences.hasSavedValues && !preferences.failed,"repaired preferences load on restart");
      check(!host.saved.includeSpecial && !host.saved.autoUpdates,"restored preferences rebuild host entry");
      finish(); return;
    }
    if (startupCase) {
      check(preferences.failed && !preferences.hasSavedValues,"startup reports unavailable file");
      checkStartupValues("pl");
      check(!Plugin.Runtime.updates.enabled,"unavailable preferences cannot start an update");
      one.setLanguage("fr");
      settle(function() {
        checkStartupValues("pl");
        hostChange({includeSpecial:true,language:"de",autoUpdates:true});
        settle(function() {
          checkStartupValues("pl");
          check(JSON.stringify(host.saved)===JSON.stringify(startupEntry),"failed host edit restores every original field");
          check(!preferences.hasSavedValues && !Plugin.Runtime.updates.enabled,"fallback is not a completed save");
          if (scenario.indexOf("startup-readonly-")!==0) {finish();return;}
          repaired=function() {
            if (scenario==="startup-readonly-host") hostChange({language:"de"});
            else if (scenario==="startup-readonly-same") check(one.persistSettings({}),"identical retry accepted");
            else check(one.setLanguage("de"),"partial panel retry accepted");
            settle(function() {
              checkStartupValues(expectedLanguage);
              check(preferences.hasSavedValues && !preferences.failed,"retry commits configuration");
              check(!preferences.values.includeSpecial && preferences.values.language===expectedLanguage,"retry saves full fallback");
              check(!Plugin.Runtime.updates.enabled && !showedUnsavedChoice,"retry publishes only committed choices");
              finish();
            });
          }; repair.running=true;
        });
      }); return;
    }
    if (scenario==="restored-settings" || scenario==="removed-entry") {
      check(!one.autoUpdates && !two.autoUpdates,"cold start restores disabled updates");
      check(one.languageSetting===expectedLanguage && two.languageSetting===expectedLanguage,"cold start restores language");
      check(!host.saved.autoUpdates,"cold start repairs stale mirror");finish();return;
    }
    check(one.autoUpdates && two.autoUpdates,"initial updates enabled");
    var previous=JSON.stringify(preferences.values), calls=host.calls;
    if (scenario==="host-change" || scenario==="readonly-host") {
      var stale=clone(host.saved);
      pendingHostSettings=hostChange({autoUpdates:false,language:"de"});
      settle(function() {
        if (scenario==="readonly-host") {
          check(preferences.failed,"host failure reported");
          check(one.autoUpdates && two.autoUpdates && !showedUnsavedChoice,"failed host choice never applied");
          check(JSON.stringify(preferences.values)===previous,"failed host edit preserves committed values");
          check(host.saved.autoUpdates && host.saved.language==="pl","failed host copy rolled back");
          repaired=function() {host.saved=clone(pendingHostSettings);host.deliver(pendingHostSettings);settle(function(){checkHostSave();finish();});};
          repair.running=true;return;
        }
        checkHostSave();
        var revision=preferences.values._windowpeekRevision;
        check(revision>stale._windowpeekRevision,"host edit advances revision");
        var publishedCalls=host.calls;
        host.deliver(clone(host.saved));
        check(host.calls===publishedCalls,"identical echoes do not publish again");
        host.deliver(stale);
        settle(function() {
          checkHostSave();
          check(preferences.values._windowpeekRevision===revision,"stale echoes do not advance revision");
          check(host.calls-publishedCalls<=2,"stale echoes repair without recursion");
          hostChange({autoUpdates:true});
          settle(function() {
            check(one.autoUpdates && two.autoUpdates && Plugin.Runtime.updates.enabled,"host can enable updates");
            check(two.setHintsMode("off"),"second monitor accepts edit");
            settle(function() {
              hostChange({autoUpdates:false});
              settle(function(){checkHostSave();check(one.hints.mode==="off" && two.hints.mode==="off","host preserves later edits");finish();});
            });
          });
        });
      }); return;
    }
    one.toggleUpdates();
    check(one.autoUpdates && two.autoUpdates,"queued save is not displayed as committed");
    settle(function() {
      if (scenario==="readonly-settings") {
        check(one.saveFailed && preferences.failed,"disk failure reported");
        check(one.autoUpdates && two.autoUpdates,"disk failure preserves switches");
        check(JSON.stringify(preferences.values)===previous && host.calls===calls,"failed write changes neither worker nor mirror");
        // Retry identical data after a failed cached write; then repair and save the failed value.
        preferences.save(preferences.values);
        settle(function() {
          check(!preferences.failed,"keeping committed value clears failed cache");
          repaired=function() {
            one.toggleUpdates();
            settle(function() {
              check(!one.saveFailed && !one.autoUpdates && !two.autoUpdates,"retry commits both monitors");
              check(!preferences.values.autoUpdates && !host.saved.autoUpdates,"worker and mirror follow retry");finish();
            });
          };repair.running=true;
        });
      } else {
        check(!one.saveFailed && !one.autoUpdates && !two.autoUpdates,"durable save succeeds despite mirror failure");
        check(!preferences.values.autoUpdates && host.saved.autoUpdates,"disk authoritative while fixture mirror stays stale");
        check(one.languageSetting==="pl" && two.languageSetting==="pl","unrelated choice preserved");finish();
      }
    });
  }
  Timer {
    interval:50;running:true;repeat:true
    onTriggered: {
      if (!one.settingsReady || !two.settingsReady || Plugin.Runtime.preferences.saving) return;
      stop();suite.run(suite.start);
    }
  }
}
