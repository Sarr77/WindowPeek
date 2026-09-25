import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui as Ui
import "services"

// Real Omarchy PluginRegistry, with its normal filesystem/config callbacks.
// This small IPC adapter omits desktop services and windows in a private test
// namespace; lifecycle decisions are made by the installed registry itself.
ShellRoot {
  id: root
  property var config: ({version:1,bar:{layout:{left:[],center:[],right:[]}},plugins:[]})
  readonly property string pluginId: "sarr.windowpeek"
  readonly property var pluginEntry: {
    var entries = config.bar.layout.left.concat(config.bar.layout.center, config.bar.layout.right);
    return entries.filter(function(e) { return e.id === root.pluginId; })[0] || null;
  }
  onPluginEntryChanged: Qt.callLater(injectSettings)
  function injectSettings() {
    if (widget.item && root.pluginEntry) widget.item.settings = root.pluginEntry;
  }
  FileView {
    id: saved
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    atomicWrites: true
    onLoaded: root.config = JSON.parse(text())
  }
  function mutate(fn) {
    var next = JSON.parse(JSON.stringify(config));
    fn(next); config = next;
    saved.setText(JSON.stringify(next,null,2));
  }
  PluginRegistry {
    id: registry
    firstPartyDir: Quickshell.env("OMARCHY_PATH") + "/shell/plugins"
    shellConfigProvider: function() { return root.config; }
    shellConfigMutator: function(fn) { root.mutate(fn); }
  }
  QtObject {
    id: scopedShell
    function updateEntryInline(id, entry) {
      if (id !== root.pluginId || !root.pluginEntry) return false;
      root.mutate(function(next) {
        ["left","center","right"].forEach(function(section) {
          next.bar.layout[section] = next.bar.layout[section].map(function(e) { return e.id === id ? entry : e; });
        });
      });
      return true;
    }
  }
  Ui.PluginBarApi {
    id: barApi
    pluginId: root.pluginId; moduleName: root.pluginId
    shell: scopedShell
    layoutConfig: root.config.bar.layout
    _moduleWidgets: function() { return widget.item ? [widget.item] : []; }
  }
  Loader {
    id: widget
    active: !!root.pluginEntry
    source: active ? "file://" + Quickshell.env("HOME") + "/.config/omarchy/plugins/" + root.pluginId + "/Widget.qml" : ""
    onLoaded: { item.bar = barApi; item.settings = root.pluginEntry; }
  }
  IpcHandler {
    target: "shell"
    function ping(): string { return registry.scanning ? "wait" : "ok"; }
    function rescanPlugins(): void { registry.rescan(); }
    function enablePlugin(id:string, placementJson:string): string {
      return registry.setEnabled(id,true,JSON.parse(placementJson || "{}")) ? "ok" : "unknown";
    }
    function setPluginEnabled(id:string, enabled:string): string {
      return registry.setEnabled(id,enabled === "true") ? "ok" : "unknown";
    }
    function setBarWidget(id:string, key:string, valueJson:string, selectorJson:string): string {
      return registry.setBarWidget(id,key,JSON.parse(valueJson),JSON.parse(selectorJson || "{}")) || "ok";
    }
    function listPlugins(): string {
      return JSON.stringify(Object.keys(registry.installedPlugins).map(function(id) {
        var m=registry.installedPlugins[id];
        return {id:id,name:m.name,kinds:m.kinds,enabled:registry.isEnabled(id),firstParty:m.__isFirstParty};
      }));
    }
    function testSave(json:string): bool {
      return !!widget.item && widget.item.settingsReady && widget.item.persistSettings(JSON.parse(json));
    }
    function testState(): string {
      return JSON.stringify({loaded:!!widget.item,ready:!!widget.item && widget.item.settingsReady,
        settings:widget.item ? widget.item.settings : null,
        defaults:widget.item ? {panelStyle:widget.item.panelStyle,
          backgroundTexture:widget.item.backgroundTexture, backgroundBlur:widget.item.backgroundBlur,
          wallpaperTransparency:widget.item.wallpaperTransparency,
          wallpaperInitialized:widget.item.wallpaperTransparencyRule.initialized,
          hintsMode:widget.item.hints.mode, hintsUsed:widget.item.hints.used,
          wheelScrollSpeed:widget.item.wheelScrollSpeed,
          hintsRemaining:widget.item.hints.remaining, hintsEnabled:widget.item.hints.enabled} : null});
    }
  }
}
