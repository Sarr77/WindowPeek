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
    ? Appearance.resolve(hostWidget.savedAppearance, targetTheme, String(hostWidget.themeAccent)) : String(Color.accent).toUpperCase()

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
    colorScope = draft.colorScope;
    saveFailed = false;
    selectedPresetId = ""; colorsExpanded = false; editingPreset = false; presetError = false;
    started = true;
    syncFromDraft();
    publishPreview();
    hexInput.forceActiveFocus();
  }
  function syncFromDraft() {
    mode = Appearance.ruleFor(draft, targetTheme).mode;
    syncHex(Appearance.resolve(draft, targetTheme, String(hostWidget.themeAccent)));
  }
  function closePickers() { modePicker.close(); scopePicker.close(); started = false; }
  // Color editing must not restore stale list density or scale from another monitor.
  function colorDraft() {
    return {accentColor: draft.accentColor, colorMode: draft.colorMode,
      colorScope: draft.colorScope, themeColors: draft.themeColors, colorPresets: draft.colorPresets};
  }
  function publishPreview() {
    if (!validHex) return;
    hostWidget.previewAppearance(colorDraft());
  }
  function changeRule(nextMode, scope, color) {
    mode = nextMode; colorScope = scope;
    draft = Appearance.setRule(draft, targetTheme, scope, mode, color);
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
    draft = Appearance.setRule(draft, targetTheme, targetTheme ? colorScope : "all", mode, chosenHex);
    publishPreview();
  }
  function choosePreset(preset) {
    selectedPresetId = preset.id || "";
    editingPreset = false; presetError = false;
    changeRule("custom", targetTheme ? colorScope : "all", preset.color);
  }
  function restoreSavedColor() {
    draft = Appearance.restoreColor(draft, hostWidget.savedAppearance, targetTheme);
    colorScope = draft.colorScope;
    selectedPresetId = "";
    syncFromDraft();
    publishPreview();
  }
  function resetColor() {
    selectedPresetId = "";
    changeRule("adaptive", targetTheme ? colorScope : "all", "");
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
    var next = Appearance.upsertPreset(draft, editingPresetId, presetNameInput.text, chosenHex);
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
    width: parent.width
    text: "WindowPeek · " + root.words.appearance
    textFormat: Text.PlainText
    horizontalAlignment: Text.AlignLeft
    color: root.foreground
    font.pixelSize: Style.font.subtitle
    font.bold: true
  }
  Text { text: root.words.highlight; color: root.foreground; font.pixelSize: Style.font.body }

  Item {
    id: sv
    objectName: "colorPlane"
    width: parent.width; height: Style.space(145)
    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true
    activeFocusOnTab: true
    Accessible.role: Accessible.Slider
    Accessible.name: root.words.highlight + " S / V"
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
    width: parent.width
    from: 0; to: 1; value: root.hue; stepSize: 0.002
    LayoutMirroring.enabled: false
    Accessible.name: root.words.highlight + " H"
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
    width: parent.width; spacing: Style.space(10)
    Rectangle { width: Style.space(32); height: width; color: root.accent; radius: Style.space(4); border.width: 1; border.color: Color.popups.text }
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
          root.draft = Appearance.setRule(root.draft, root.targetTheme, root.targetTheme ? root.colorScope : "all", "custom", normalized);
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
    width: parent.width
    text: root.words.restoreSavedColor + " · " + root.savedColor
    accent: root.accent
    focusable: true
    onClicked: root.restoreSavedColor()
  }
  DefaultValue {
    objectName: "colorDefault"
    width: parent.width; words: root.words; label: root.words.highlight; accent: root.accent
    valueText: Appearance.resolve({}, root.targetTheme, String(root.hostWidget.themeAccent))
    description: root.colorScope === "theme" && root.targetTheme
      ? I18n.format(root.words.colorThisTheme, {theme: root.themeName}) : root.words.colorAllThemes
    modified: root.mode !== "adaptive" || !root.validHex
    onResetRequested: root.resetColor()
    onEnsureVisible: root.ensureVisible(this)
  }
  Ui.Button {
    objectName: "colorPresetsDisclosure"
    width: parent.width
    text: (root.colorsExpanded ? "▾ " : "▸ ") + root.words.colorPresets
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
      objectName: "colorModePicker"
      width: parent.width
      uiScale: root.hostWidget ? root.hostWidget.uiScale : 1
      label: root.words.colorMode
      value: root.mode
      options: [{value:"adaptive", label:root.words.colorAdaptive},
        {value:"theme", label:root.words.colorTheme}, {value:"custom", label:root.words.customLabels}]
      accent: root.accent
      onChanged: function(value) {
        root.changeRule(value, root.targetTheme ? root.colorScope : "all", root.chosenHex);
        modePicker.value = Qt.binding(function() { return root.mode; });
      }
    }
    Choice.Dropdown {
      id: scopePicker
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
    Text {
      width: parent.width
      text: root.words.colorAdaptiveHelp
      color: root.foreground; opacity: 0.7
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
    }
    Row {
      width: parent.width
      Text { width: parent.width; text: root.words.colorPresets; color: root.foreground; font.pixelSize: Style.font.body }
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
        text: "+ " + root.words.saveColor
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
          text: root.editingPresetId ? root.words.updatePreset : root.words.saveColor
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
  Text { text: root.words.preview; color: root.foreground; font.pixelSize: Style.font.caption }
  TooltipContent { width: parent.width; hostWidget: root.hostWidget; maximumHeight: Style.space(240); interactive: false }
  Row {
    width: parent.width; spacing: Style.space(10)
    Ui.Button { objectName: "cancelButton"; width: (parent.width-parent.spacing)/2; text: root.words.cancel; focusable: true; onClicked: root.cancel() }
    Ui.Button { objectName: "applyButton"; width: (parent.width-parent.spacing)/2; text: root.words.apply; focusable: true; bordered: true; accent: root.accent; enabled: root.validHex; onClicked: root.apply() }
  }
}
