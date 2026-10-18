// Text templates affect presentation only. They never become window identifiers.
var groups = [
    {value: "panel", word: "labelPanelGroup"},
    {value: "workspaces", word: "labelWorkspaceGroup"},
    {value: "windows", word: "windowsLabel"},
    {value: "actions", word: "labelActionGroup"},
    {value: "hints", word: "panelHints"}
];

var fields = [
    {key: "barText", group: "panel", caption: "barLabel", variables: ["count", "monitor"]},
    {key: "panelTitle", group: "panel", caption: "labelPanelTitle", variables: []},
    {key: "windowCount", group: "panel", caption: "labelWindowCount", variables: ["count"]},
    {key: "searchWindows", group: "panel", variables: []},
    {key: "workspaceLabel", group: "workspaces", variables: ["name"]},
    {key: "specialWorkspaceLabel", group: "workspaces", variables: ["name"]},
    {key: "scratchpad", group: "workspaces", variables: []},
    {key: "hiddenWorkspace", group: "workspaces", variables: []},
    {key: "unknownWorkspace", group: "workspaces", variables: []},
    {key: "unknownMonitor", group: "workspaces", variables: []},
    {key: "activeWindow", group: "windows", variables: []},
    {key: "grouped", group: "windows", variables: []},
    {key: "unnamed", group: "windows", variables: []},
    {key: "emptyWindows", group: "windows", variables: []},
    {key: "noMatches", group: "windows", variables: []},
    {key: "previewLoading", group: "windows", variables: []},
    {key: "previewUnavailable", group: "windows", variables: []},
    {key: "move", group: "actions", variables: []},
    {key: "moveNow", group: "actions", variables: []},
    {key: "moveToScratchpad", group: "actions", variables: []},
    {key: "moveTo", group: "actions", variables: []},
    {key: "moveFrom", group: "actions", variables: ["workspace"]},
    {key: "settings", group: "actions", variables: []},
    {key: "back", group: "actions", variables: []},
    {key: "focusHint", group: "hints", variables: []},
    {key: "chooseMoveHint", group: "hints", variables: []},
    {key: "bringHint", group: "hints", variables: []},
    {key: "moveHint", group: "hints", variables: []},
    {key: "openSearchHint", group: "hints", variables: []}
];
var maximumLength = 160;

function normalize(settings) {
    var custom = settings && settings.customLabels, result = {};
    fields.forEach(function(field) {
        if (custom && typeof custom[field.key] === "string") {
            var value = custom[field.key].replace(/[\x00-\x1f\x7f]+/g, " ").trim().slice(0, maximumLength);
            if (value) result[field.key] = value;
        }
    });
    return {labelStyle: settings && settings.labelStyle === "custom" ? "custom" : "default", customLabels: result};
}

function invalidVariables(key, value) {
    var field = fields.find(function(item) { return item.key === key; });
    if (!field || !value) return [];
    var invalid = [];
    String(value).replace(/\{([^{}]+)\}/g, function(token, name) {
        if (field.variables.indexOf(name) < 0 && invalid.indexOf(token) < 0) invalid.push(token);
        return token;
    });
    return invalid;
}

function valid(settings) {
    var prefs = normalize(settings);
    return prefs.labelStyle !== "custom" || fields.every(function(field) {
        return invalidVariables(field.key, prefs.customLabels[field.key]).length === 0;
    });
}

function defaults(words, barStyle, vertical) {
    var result = {};
    fields.forEach(function(field) { result[field.key] = words[field.key] || ""; });
    result.barText = barStyle === "name" ? "WindowPeek" : barStyle === "compact" ? "▣ {count}"
        : "WindowPeek" + (vertical ? "\n" : " · ") + "{count}";
    result.panelTitle = "WindowPeek";
    result.windowCount = words.windowsLabel + "  {count}";
    return result;
}

function templates(words, settings, barStyle, vertical) {
    var prefs = normalize(settings), result = defaults(words, barStyle, vertical);
    if (prefs.labelStyle === "custom") fields.forEach(function(field) {
        var value = prefs.customLabels[field.key];
        if (value && !invalidVariables(field.key, value).length) result[field.key] = value;
    });
    return result;
}

function apply(words, settings) {
    var result = {}, custom = templates(words, settings);
    Object.keys(words).forEach(function(key) { result[key] = words[key]; });
    fields.forEach(function(field) { if (Object.prototype.hasOwnProperty.call(words, field.key)) result[field.key] = custom[field.key]; });
    return result;
}

function render(template, values) {
    return String(template).replace(/\{([a-zA-Z]+)\}/g, function(token, key) {
        return values && Object.prototype.hasOwnProperty.call(values, key) ? String(values[key]) : token;
    });
}
