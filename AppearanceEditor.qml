import QtQuick
import QtQuick.Window
import "vendor/omarchy" as Choice
import QtQuick.Controls as QQC
import qs.Ui as Ui
import qs.Commons
import "Appearance.js" as Appearance
import "I18n.js" as I18n

Column {
  id: root
  objectName: "appearanceEditor"
  required property var hostWidget
  readonly property var words: hostWidget ? hostWidget.words : I18n.words("en")
  readonly property color foreground: hostWidget && hostWidget.bar ? hostWidget.bar.barForeground : Color.popups.text
  readonly property color accent: hostWidget ? hostWidget.accent : Color.accent
  property real hue: 0
  property real saturation: 0
  property real value: 1
  property var draft: ({})
  property string colorTarget: "accent"
  readonly property bool accentTarget: colorTarget === "accent"
  readonly property bool colorTargetVisible: colorTarget !== "wallpaper"
  readonly property var surfaceRule: Appearance.surfaceRuleFor(draft, colorTarget, targetTheme)
  readonly property string targetLabel: labelForTarget(colorTarget)
  function labelForTarget(target) {
    return target === "accent" ? words.highlight
      : target === "panel" ? words.panelBackground : target === "windows" ? words.windowFields
      : target === "menu" ? words.menuFields : target === "grain" ? words.backgroundTexture : words.wallpaperPanel;
  }
  property string mode: "adaptive"
  property string colorScope: "theme"
  property string targetTheme: ""
  property bool started: false
  property string selectedPresetId: ""
  property bool colorsExpanded: false
  property bool editingPreset: false
  property string editingPresetId: ""
  property bool presetError: false
  readonly property string themeName: targetTheme.replace(/(^|-)([a-z])/g, function(_, dash, c) { return (dash ? " " : "") + c.toUpperCase(); })
  property bool validHex: true
  property bool saveFailed: false
  property bool syncing: false
  signal finished()
  signal ensureVisible(var item)
  spacing: Style.space(12)
  readonly property string chosenHex: Appearance.fromHsv(hue, saturation, value)
  readonly property string savedColor: hostWidget
    ? (accentTarget ? Appearance.resolve(hostWidget.savedAppearance, targetTheme, String(hostWidget.themeAccent))
      : Appearance.surfaceColor(hostWidget.savedAppearance,colorTarget,targetTheme,hostWidget.surfaces.baseColor(colorTarget)))
    : String(Color.accent).toUpperCase()

  function syncHex(text) {
    var hsv = Appearance.toHsv(text);
    if (!hsv) return false;
    syncing = true;
    hue = hsv.h; saturation = hsv.s; value = hsv.v;
    hexInput.text = Appearance.hex(text);
    validHex = true;
    syncing = false;
    return true;
  }
  function begin() {
    draft = Appearance.normalize(hostWidget.savedAppearance);
    targetTheme = hostWidget.themeId;
    colorTarget = "accent";
    colorScope = draft.colorScope;
    saveFailed = false;
    selectedPresetId = ""; colorsExpanded = false; editingPreset = false; presetError = false;
    started = true;
    syncFromDraft();
    publishPreview();
    // Start at the preview; focusing HEX would scroll past it on small screens.
    editorHeading.forceActiveFocus();
  }
  function syncFromDraft() {
    colorScope = accentTarget ? draft.colorScope : Appearance.surfaceScope(draft,colorTarget);
    mode = accentTarget ? Appearance.ruleFor(draft,targetTheme).mode : (surfaceRule.color ? "custom" : "theme");
    syncHex(accentTarget ? Appearance.resolve(draft,targetTheme,String(hostWidget.themeAccent))
      : Appearance.surfaceColor(draft,colorTarget,targetTheme,hostWidget.surfaces.baseColor(colorTarget)));
  }
  function closePickers() { targetPicker.close(); modePicker.close(); scopePicker.close(); started = false; }
  function selectTarget(target) {
    colorTarget = target; selectedPresetId = ""; editingPreset = false;
    syncFromDraft();
  }
  function withColor(settings, scope, nextMode, color) {
    if (accentTarget) return Appearance.setRule(settings,targetTheme,scope,nextMode,color);
    var rule = Appearance.surfaceRuleFor(settings,colorTarget,targetTheme);
    rule.color = nextMode === "custom" ? color : "";
    return Appearance.setSurfaceRule(settings,colorTarget,targetTheme,scope,rule);
  }
  function changeSurfaceValue(key, value) {
    var rule = Appearance.surfaceRuleFor(draft,colorTarget,targetTheme);
    rule[key] = value;
    draft = Appearance.setSurfaceRule(draft,colorTarget,targetTheme,targetTheme ? colorScope : "all",rule);
    publishPreview();
  }
  function resetStyle() {
    draft = Appearance.applyStyle(draft,targetTheme,targetTheme ? colorScope : "all",{});
    syncFromDraft(); publishPreview();
  }
  // Color editing must not restore stale list density or scale from another monitor.
  function colorDraft() {
    return {accentColor: draft.accentColor, colorMode: draft.colorMode,
      colorScope: draft.colorScope, themeColors: draft.themeColors, colorPresets: draft.colorPresets, surfaceColors: draft.surfaceColors};
  }
  function publishPreview() {
    if (!validHex) return;
    hostWidget.previewAppearance(colorDraft());
  }
  function changeRule(nextMode, scope, color) {
    mode = nextMode; colorScope = scope;
    draft = withColor(draft, scope, mode, color);
    syncFromDraft();
    publishPreview();
  }
  function pick(h, s, v) {
    hue = Math.max(0, Math.min(1, h));
    saturation = Math.max(0, Math.min(1, s));
    value = Math.max(0, Math.min(1, v));
    mode = "custom";
    syncing = true; hexInput.text = chosenHex; syncing = false;
    validHex = true;
    draft = withColor(draft, targetTheme ? colorScope : "all", mode, chosenHex);
    publishPreview();
  }
  function choosePreset(preset) {
    selectedPresetId = preset.id || "";
    editingPreset = false; presetError = false;
    if (preset.style) {
      draft = Appearance.applyStyle(draft,targetTheme,targetTheme ? colorScope : "all",preset.style);
      syncFromDraft(); publishPreview();
    } else changeRule("custom", targetTheme ? colorScope : "all", preset.color);
  }
  function restoreSavedColor() {
    draft = accentTarget ? Appearance.restoreColor(draft, hostWidget.savedAppearance, targetTheme)
      : Appearance.restoreSurface(draft, hostWidget.savedAppearance, colorTarget, targetTheme);
    colorScope = draft.colorScope;
    selectedPresetId = "";
    syncFromDraft();
    publishPreview();
  }
  function resetColor() {
    selectedPresetId = "";
    if (accentTarget) changeRule("adaptive", targetTheme ? colorScope : "all", "");
    else {
      draft = Appearance.setSurfaceRule(draft,colorTarget,targetTheme,targetTheme ? colorScope : "all",{});
      syncFromDraft(); publishPreview();
    }
    saveFailed = false;
  }
  function editPreset(id) {
    editingPresetId = id;
    var preset = draft.colorPresets.find(function(p) { return p.id === id; });
    presetNameInput.text = preset ? preset.name : "";
    editingPreset = true; presetError = false;
    presetNameInput.forceActiveFocus();
  }
  function savePreset() {
    var next = Appearance.upsertPreset(draft, editingPresetId, presetNameInput.text, chosenHex, Appearance.captureStyle(draft,targetTheme));
    presetError = next === null;
    if (!next) return;
    draft = next;
    selectedPresetId = editingPresetId || next.colorPresets[next.colorPresets.length-1].id;
    editingPreset = false;
    publishPreview();
  }
  function deletePreset() {
    draft = Appearance.removePreset(draft, editingPresetId);
    selectedPresetId = ""; editingPreset = false; presetError = false;
    publishPreview();
  }
  function cancel() { closePickers(); hostWidget.cancelAppearance(); finished(); }
  function apply() {
    if (!validHex) return;
    if (hostWidget.saveAppearance(colorDraft())) { closePickers(); finished(); }
    else saveFailed = true;
  }
  Connections {
    target: root.hostWidget
    function onThemeIdChanged() {
      if (!root.started) return;
      root.targetTheme = root.hostWidget.themeId;
      root.selectedPresetId = "";
      root.editingPreset = false;
      root.syncFromDraft();
      root.publishPreview();
    }
    function onThemeAccentChanged() {
      if (root.started && root.mode !== "custom") root.syncFromDraft();
    }
  }
  Connections {
    target: root.Window.window
    function onActiveFocusItemChanged() {
      var focused = root.Window.window ? root.Window.window.activeFocusItem : null;
      for (var item = focused; item; item = item.parent) {
        if (item === root) { root.ensureVisible(focused); return; }
      }
    }
  }
  Keys.onEscapePressed: function(event) { root.cancel(); event.accepted = true; }

  Text {
    id: editorHeading
    width: parent.width
    text: "WindowPeek · " + root.words.appearance
    textFormat: Text.PlainText
    horizontalAlignment: Text.AlignLeft
    color: root.foreground
    font.pixelSize: Style.font.subtitle
    font.bold: true
  }
  Column {
    width: parent.width; spacing: Style.space(4)
    Text {
      width: parent.width; text: root.words.preview + " · " + root.targetLabel
      textFormat: Text.PlainText; elide: Text.ElideRight
      color: root.foreground; font.pixelSize: Style.font.caption
    }
    Text {
      width: parent.width; text: root.words.previewPickHint; textFormat: Text.PlainText
      wrapMode: Text.Wrap; color: root.foreground; opacity: 0.7; font.pixelSize: Style.font.caption
    }
  }
  AppearancePreview {
    id: livePreview; width: parent.width; hostWidget: root.hostWidget
    selectedTarget: root.colorTarget
    onElementPicked: function(target) {
      targetPicker.close(); modePicker.close(); scopePicker.close();
      // All changing controls are below the sample. Keep the pointer and scroll
      // where they are so several elements can be picked without chasing it.
      root.selectTarget(target);
    }
  }
  Choice.Dropdown {
    id: targetPicker; objectName: "colorTargetPicker"
    hostWidget: root.hostWidget
    width: parent.width; uiScale: root.hostWidget.uiScale
    label: root.words.colorElement; value: root.colorTarget; accent: root.accent
    options: [{value:"accent",label:root.words.highlight}, {value:"panel",label:root.words.panelBackground},
      {value:"windows",label:root.words.windowFields}, {value:"menu",label:root.words.menuFields},
      {value:"grain",label:root.words.backgroundTexture}, {value:"wallpaper",label:root.words.wallpaperPanel}]
    onChanged: function(value) { root.selectTarget(value); targetPicker.value = Qt.binding(function() { return root.colorTarget; }); }
  }

    Choice.Dropdown {
      id: scopePicker
      hostWidget: root.hostWidget
      objectName: "colorScopePicker"
      width: parent.width
      uiScale: root.hostWidget ? root.hostWidget.uiScale : 1
      label: root.words.colorScope
      value: root.targetTheme ? root.colorScope : "all"
      options: (root.targetTheme ? [{value:"theme", label:I18n.format(root.words.colorThisTheme, {theme:root.themeName})}] : [])
        .concat([{value:"all", label:root.words.colorAllThemes}])
      accent: root.accent
      onChanged: function(value) {
        root.changeRule(root.mode, value, root.chosenHex);
        scopePicker.value = Qt.binding(function() { return root.targetTheme ? root.colorScope : "all"; });
      }
    }

  Item {
    id: sv
    visible: root.colorTargetVisible
    objectName: "colorPlane"
    width: parent.width; height: Style.space(145)
    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true
    activeFocusOnTab: true
    Accessible.role: Accessible.Slider
    Accessible.name: root.targetLabel + " S / V"
    Rectangle { anchors.fill: parent; color: Appearance.fromHsv(root.hue, 1, 1) }
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: "#FFFFFFFF" }
        GradientStop { position: 1; color: "#00FFFFFF" }
      }
    }
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0; color: "#00000000" }
        GradientStop { position: 1; color: "#FF000000" }
      }
    }
    Rectangle {
      x: Math.max(0, Math.min(parent.width-width, root.saturation*parent.width-width/2))
      y: Math.max(0, Math.min(parent.height-height, (1-root.value)*parent.height-height/2))
      width: Style.space(12); height: width; radius: width/2
      color: root.chosenHex
      border.width: 2; border.color: root.value > 0.6 ? "black" : "white"
    }
    Rectangle { anchors.fill: parent; color: "transparent"; border.width: sv.activeFocus ? 2 : 0; border.color: root.accent }
    MouseArea {
      anchors.fill: parent
      preventStealing: true
      onPressed: function(mouse) { sv.forceActiveFocus(); root.pick(root.hue, mouse.x/width, 1-mouse.y/height); }
      onPositionChanged: function(mouse) { if (pressed) root.pick(root.hue, mouse.x/width, 1-mouse.y/height); }
    }
    Keys.onPressed: function(event) {
      var delta = event.modifiers & Qt.ShiftModifier ? 0.1 : 0.01;
      if (event.key === Qt.Key_Left) root.pick(root.hue, root.saturation-delta, root.value);
      else if (event.key === Qt.Key_Right) root.pick(root.hue, root.saturation+delta, root.value);
      else if (event.key === Qt.Key_Up) root.pick(root.hue, root.saturation, root.value+delta);
      else if (event.key === Qt.Key_Down) root.pick(root.hue, root.saturation, root.value-delta);
      else return;
      event.accepted = true;
    }
  }
  QQC.Slider {
    id: hueSlider
    visible: root.colorTargetVisible
    width: parent.width
    from: 0; to: 1; value: root.hue; stepSize: 0.002
    LayoutMirroring.enabled: false
    Accessible.name: root.targetLabel + " H"
    onMoved: root.pick(value, root.saturation, root.value)
    background: Rectangle {
      x: hueSlider.leftPadding
      y: hueSlider.topPadding + hueSlider.availableHeight/2 - height/2
      width: hueSlider.availableWidth; height: Style.space(15); radius: Style.space(3)
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: "#FF0000" }
        GradientStop { position: 0.166667; color: "#FFFF00" }
        GradientStop { position: 0.333333; color: "#00FF00" }
        GradientStop { position: 0.5; color: "#00FFFF" }
        GradientStop { position: 0.666667; color: "#0000FF" }
        GradientStop { position: 0.833333; color: "#FF00FF" }
        GradientStop { position: 1; color: "#FF0000" }
      }
    }
  }
  Row {
    visible: root.colorTargetVisible
    width: parent.width; spacing: Style.space(10)
    Rectangle { width: Style.space(32); height: width; color: root.chosenHex; radius: Style.space(4); border.width: 1; border.color: Color.popups.text }
    Ui.TextField {
      id: hexInput
      objectName: "hexInput"
      width: parent.width - Style.space(42)
      placeholderText: "#RRGGBB"
      Accessible.name: "HEX"
      maximumLength: 7
      LayoutMirroring.enabled: false
      horizontalAlignment: TextInput.AlignLeft
      accent: root.accent
      onTextEdited: {
        if (root.syncing) return;
        var normalized = Appearance.hex(text);
        root.validHex = normalized !== "";
        if (root.validHex) {
          var hsv = Appearance.toHsv(normalized);
          root.hue = hsv.h; root.saturation = hsv.s; root.value = hsv.v;
          root.mode = "custom";
          root.draft = root.withColor(root.draft, root.targetTheme ? root.colorScope : "all", "custom", normalized);
          root.publishPreview();
        }
      }
      onAccepted: root.apply()
    }
  }
  Text {
    width: parent.width
    visible: !root.validHex || root.saveFailed
    text: root.saveFailed ? root.words.saveStyleError : root.words.invalidHex
    color: Color.urgent
    wrapMode: Text.Wrap
    font.pixelSize: Style.font.body
  }
  Ui.Button {
    objectName: "restoreSavedColorButton"
    visible: root.colorTargetVisible
    width: parent.width
    text: root.words.restoreSavedColor + " · " + root.savedColor
    accent: root.accent
    focusable: true
    onClicked: root.restoreSavedColor()
  }
  DefaultValue {
    objectName: "colorDefault"
    width: parent.width; words: root.words; label: root.targetLabel; accent: root.accent
    valueText: root.accentTarget ? Appearance.resolve({}, root.targetTheme, String(root.hostWidget.themeAccent))
      : root.colorTargetVisible ? Appearance.hex(root.hostWidget.surfaces.baseColor(root.colorTarget)) : "0%"
    description: root.colorScope === "theme" && root.targetTheme
      ? I18n.format(root.words.colorThisTheme, {theme: root.themeName}) : root.words.colorAllThemes
    modified: root.accentTarget ? root.mode !== "adaptive" || !root.validHex
      : !!root.surfaceRule.color || root.surfaceRule.brightness !== 0 || root.surfaceRule.opacity !== null || !root.validHex
    onResetRequested: root.resetColor()
    onEnsureVisible: root.ensureVisible(this)
  }
  StyleValueControl {
    objectName: "surfaceBrightnessControl"
    width: parent.width; visible: !root.accentTarget && root.colorTarget !== "grain"
    words: root.words; label: root.words.brightness; accent: root.accent
    from: -100; to: 100; value: root.surfaceRule.brightness; defaultValue: 0
    modified: root.surfaceRule.brightness !== 0
    onChanged: function(value) { root.changeSurfaceValue("brightness",value); }
    onResetRequested: root.changeSurfaceValue("brightness",0)
    onEnsureVisible: root.ensureVisible(this)
  }
  StyleValueControl {
    objectName: "surfaceOpacityControl"
    width: parent.width; visible: ["windows","menu","grain"].indexOf(root.colorTarget) >= 0
    words: root.words; label: root.colorTarget === "grain" ? root.words.grainStrength : root.words.transparency
    accent: root.accent; from:0; to:100; stepSize:0.5
    readonly property real opacityValue: root.surfaceRule.opacity === null ? root.hostWidget.surfaces.defaultOpacity(root.colorTarget) : root.surfaceRule.opacity
    value: root.colorTarget === "grain" ? opacityValue : 100-opacityValue
    defaultValue: root.colorTarget === "grain" ? root.hostWidget.surfaces.defaultOpacity(root.colorTarget) : 100-root.hostWidget.surfaces.defaultOpacity(root.colorTarget)
    modified: root.surfaceRule.opacity !== null
    onChanged: function(value) { root.changeSurfaceValue("opacity",root.colorTarget === "grain" ? value : 100-value); }
    onResetRequested: root.changeSurfaceValue("opacity",null)
    onEnsureVisible: root.ensureVisible(this)
  }
  Ui.Button {
    objectName: "resetStyleButton"; width: parent.width
    text: root.words.resetStyle; accent: root.accent; focusable:true
    onClicked: root.resetStyle()
  }
  Ui.Button {
    objectName: "colorPresetsDisclosure"
    width: parent.width
    text: (root.colorsExpanded ? "▾ " : "▸ ") + root.words.stylePresets
    leftAlign: true
    focusable: true
    accent: root.accent
    onClicked: {
      modePicker.close(); scopePicker.close();
      root.colorsExpanded = !root.colorsExpanded;
    }
  }
  Column {
    visible: root.colorsExpanded
    width: parent.width
    spacing: Style.space(10)
    Choice.Dropdown {
      id: modePicker
      hostWidget: root.hostWidget
      objectName: "colorModePicker"
      width: parent.width
      uiScale: root.hostWidget ? root.hostWidget.uiScale : 1
      label: root.words.colorMode
      value: root.mode
      options: (root.accentTarget ? [{value:"adaptive",label:root.words.colorAdaptive}] : [])
        .concat([{value:"theme",label:root.accentTarget ? root.words.colorTheme : root.words.followTheme},{value:"custom",label:root.words.customLabels}])
      accent: root.accent
      onChanged: function(value) {
        root.changeRule(value, root.targetTheme ? root.colorScope : "all", root.chosenHex);
        modePicker.value = Qt.binding(function() { return root.mode; });
      }
    }
    Text {
      width: parent.width
      visible: root.accentTarget
      text: root.words.colorAdaptiveHelp
      color: root.foreground; opacity: 0.7
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
    }
    Row {
      width: parent.width
      Text { width: parent.width; text: root.words.stylePresets; color: root.foreground; font.pixelSize: Style.font.body }
    }
    Flow {
      width: parent.width; spacing: Style.space(6)
      PresetChip {
        objectName: "defaultColorPreset"
        maximumWidth: parent.width
        label: root.words.scratchPink; swatch: Appearance.tokyoNightAccent; accent: root.accent
        selected: root.mode === "custom" && root.chosenHex === Appearance.tokyoNightAccent && !root.selectedPresetId
        onClicked: root.choosePreset({color:Appearance.tokyoNightAccent})
      }
      Repeater {
        model: root.draft.colorPresets || []
        PresetChip {
          required property var modelData
          maximumWidth: parent.width
          label: modelData.name; swatch: modelData.color; accent: root.accent
          selected: root.selectedPresetId === modelData.id
          onClicked: root.choosePreset(modelData)
        }
      }
    }
    Row {
      width: parent.width; spacing: Style.space(8)
      Ui.Button {
        width: (parent.width-parent.spacing)/2
        text: "+ " + root.words.saveStylePreset
        fontSize: Style.font.caption
        focusable: true; bordered: true; accent: root.accent
        enabled: root.validHex && (root.draft.colorPresets || []).length < 24
        onClicked: root.editPreset("")
      }
      Ui.Button {
        width: (parent.width-parent.spacing)/2
        text: root.words.editPreset
        fontSize: Style.font.caption
        visible: root.selectedPresetId !== ""
        focusable: true; accent: root.accent
        onClicked: root.editPreset(root.selectedPresetId)
      }
    }
    Column {
      visible: root.editingPreset
      width: parent.width; spacing: Style.space(8)
      Ui.TextField {
        id: presetNameInput
        objectName: "presetNameInput"
        width: parent.width
        maximumLength: 40
        placeholderText: root.words.presetName
        Accessible.name: root.words.presetName
        accent: root.accent
        onAccepted: root.savePreset()
      }
      Text {
        visible: root.presetError
        width: parent.width; wrapMode: Text.Wrap
        text: root.words.presetNameError
        font.pixelSize: Style.font.caption; color: Color.urgent
      }
      Row {
        width: parent.width; spacing: Style.space(6)
        Ui.Button {
          width: (parent.width-parent.spacing)/2
          text: root.editingPresetId ? root.words.updatePreset : root.words.saveStylePreset
          fontSize: Style.font.caption
          focusable: true; bordered: true; accent: root.accent
          enabled: root.validHex && Appearance.presetName(presetNameInput.text) !== ""
          onClicked: root.savePreset()
        }
        Ui.Button {
          width: (parent.width-parent.spacing)/2
          text: root.editingPresetId ? root.words.deletePreset : root.words.cancel
          fontSize: Style.font.caption
          focusable: true; accent: root.accent
          onClicked: { if (root.editingPresetId) root.deletePreset(); else root.editingPreset = false; }
        }
      }
    }
    Text {
      width: parent.width; text: root.words.presetDraftHelp
      color: root.foreground; opacity: 0.7; font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
    }
  }
  Row {
    width: parent.width; spacing: Style.space(10)
    Ui.Button { objectName: "cancelButton"; width: (parent.width-parent.spacing)/2; text: root.words.cancel; focusable: true; onClicked: root.cancel() }
    Ui.Button { objectName: "applyButton"; width: (parent.width-parent.spacing)/2; text: root.words.apply; focusable: true; bordered: true; accent: root.accent; enabled: root.validHex; onClicked: root.apply() }
  }
}
