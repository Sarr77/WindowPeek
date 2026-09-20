.import "WindowModel.js" as Model

function client(snapshot, value) {
    var id = Model.address(value);
    return id && snapshot && Array.isArray(snapshot.clients)
        ? snapshot.clients.find(function(w) { return w && w.mapped !== false && Model.address(w.address) === id; }) : null;
}

function selector(workspace) {
    if (!workspace || typeof workspace.name !== "string" || !workspace.name
            || /[\x00-\x1f\x7f]/.test(workspace.name)) return "";
    if (workspace.name.indexOf("special:") === 0) return workspace.name;
    return /^[1-9][0-9]*$/.test(workspace.name) ? workspace.name : "name:" + workspace.name;
}

function destinations(snapshot, sourceAddress, includeSpecial) {
    if (!snapshot) return [];
    var source = client(snapshot, sourceAddress);
    var current = source && source.workspace ? selector(source.workspace) : "";
    var seen = Object.create(null), result = [];
    function add(workspace) {
        var value = selector(workspace);
        if (!value || value === current || seen[value]) return;
        if (!includeSpecial && value.indexOf("special:") === 0) return;
        seen[value] = true;
        result.push({ value: value, name: workspace.name, id: Model.workspaceId(workspace.id),
            monitor: typeof workspace.monitor === "string" ? workspace.monitor : "" });
    }
    (snapshot.workspaces || []).forEach(add);
    add({name: "special:scratchpad"});
    for (var i = 1; i <= 10; i++) add({ id: i, name: String(i) });
    result.sort(function(a, b) {
        var an = /^[1-9][0-9]*$/.test(a.name), bn = /^[1-9][0-9]*$/.test(b.name);
        return an && bn ? Number(a.name) - Number(b.name) : an !== bn ? (an ? -1 : 1) : Model.compare(a.name, b.name);
    });
    return result;
}

function focus(address, expectedWorkspace) {
    var id = Model.address(address);
    if (!id) return "";
    return 'local w = hl.get_window("address:' + id + '"); '
        + 'if not w or not w.mapped then error("windowClosed") end; '
        + (expectedWorkspace ? 'if not w.workspace or w.workspace.name ~= '
            + JSON.stringify(expectedWorkspace) + ' then error("windowChanged") end; ' : '')
        // Hyprland opens special workspaces on the focused monitor. Select
        // their existing monitor first so focusing never summons the workspace.
        + 'if w.workspace and w.workspace.name:sub(1, 8) == "special:" then '
        + 'local monitor = w.monitor; if not monitor then error("unavailable") end; '
        + 'hl.dispatch(hl.dsp.focus({monitor = monitor.name})); end; '
        + 'hl.dispatch(hl.dsp.focus({window = "address:' + id + '"}))';
}

function move(snapshot, address, destination) {
    var win = client(snapshot, address);
    var target = destinations(snapshot, address, true).find(function(item) { return item.value === destination; });
    if (!win || !win.workspace || !target || !selector(win.workspace)) return null;
    var id = Model.address(address);
    // JSON quoting is also valid Lua for these strings: control characters were rejected.
    var command = 'local w = hl.get_window("address:' + id + '"); '
        + 'if not w or not w.mapped then error("windowClosed") end; '
        + 'if not w.workspace or w.workspace.name ~= ' + JSON.stringify(win.workspace.name) + ' then error("windowChanged") end; ';
    if (target.id !== null) {
        command += 'local target = hl.get_workspace(' + JSON.stringify(destination) + '); '
            + 'if target and target.id ~= ' + target.id + ' then error("destinationChanged") end; ';
    }
    command += 'if w.group and w.group.size > 1 then '
        + 'if w.group.locked then error("groupLocked") end; w.group:remove(w); end; '
        + 'if w.group and w.group.size > 1 then error("groupLocked") end; '
        + 'hl.dispatch(hl.dsp.window.move({window = "address:' + id + '", workspace = '
        + JSON.stringify(destination) + ', follow = false}))';
    return { command: command, target: target.name, source: win.workspace.name };
}

function bring(snapshot, address, monitorName) {
    var win = client(snapshot, address);
    var monitor = snapshot && (snapshot.monitors || []).find(function(item) { return item.name === monitorName; });
    var active = monitor && monitor.activeWorkspace;
    var target = active && (snapshot.workspaces || []).find(function(item) { return item.id === active.id; });
    var destination = selector(target);
    if (!win || !win.workspace || !destination || destination.indexOf("special:") === 0) return null;
    var sameWorkspace = win.workspace.id === target.id && win.workspace.name === target.name;
    var plan = sameWorkspace ? null : move(snapshot, address, destination);
    if (!sameWorkspace && !plan) return null;
    // Capture the destination before dismissing the panel. If the desktop
    // changes before dispatch, refuse the move instead of choosing a new target.
    var guard = 'local monitor = hl.get_monitor(' + JSON.stringify(monitorName) + '); '
        + 'local target = hl.get_workspace(' + JSON.stringify(destination) + '); '
        + 'if not monitor or not target or target.id ~= ' + target.id
        + ' or not monitor.active_workspace or monitor.active_workspace.id ~= target.id '
        + 'then error("destinationChanged") end; ';
    return { command: guard + (plan ? plan.command + '; ' : '') + focus(address, target.name),
        source: win.workspace.name, target: target.name, monitor: monitor.id };
}

function failure(output) {
    var keys = ["windowClosed", "windowChanged", "destinationChanged", "groupLocked", "unavailable"];
    return keys.find(function(key) { return output.indexOf(key) >= 0; }) || "actionFailed";
}
