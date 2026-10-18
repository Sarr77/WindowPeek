// Plain JavaScript: imported by QML and exercised unchanged by the tests.

function text(value) {
    return typeof value === "string" ? value : "";
}

function address(value) {
    if (typeof value !== "string" || !/^0x[0-9a-f]{1,16}$/i.test(value))
        return "";
    var digits = value.slice(2).replace(/^0+/, "").toLowerCase();
    return digits ? "0x" + digits : "";
}

function workspaceId(value) {
    return Number.isSafeInteger(value) && value !== 0 ? value : null;
}

function workspaceKey(workspace) {
    if (!workspace) return "unknown";
    return workspace.id !== null ? "id:" + workspace.id : "name:" + workspace.name;
}

function compare(a, b) {
    return a < b ? -1 : a > b ? 1 : 0;
}

function compareAddresses(a, b) {
    // Pointer values can exceed JavaScript's exact integer range.
    return a.length - b.length || compare(a, b);
}

function monitorFor(workspace, monitors) {
    var hasId = Number.isInteger(workspace.monitorID) && workspace.monitorID >= 0;
    var name = text(workspace.monitor);
    for (var i = 0; i < monitors.length; i++) {
        var monitor = monitors[i];
        if (!monitor || monitor.disabled || !Number.isInteger(monitor.id)
                || monitor.id < 0 || !text(monitor.name)) continue;
        if (hasId && monitor.id !== workspace.monitorID) continue;
        if (name && monitor.name !== name) continue;
        if (hasId || name) return { id: monitor.id, name: monitor.name };
    }
    return null;
}

function normalizeWorkspace(raw, workspaces, monitors) {
    if (!raw) return null;
    var id = workspaceId(raw.id);
    var name = text(raw.name);
    if (id === null && !name) return null;

    var metadata = null;
    for (var i = 0; i < workspaces.length; i++) {
        var candidate = workspaces[i];
        if (!candidate) continue;
        if (id !== null ? workspaceId(candidate.id) === id : candidate.name === name) {
            metadata = candidate;
            break;
        }
    }
    if (metadata) {
        id = workspaceId(metadata.id);
        name = text(metadata.name) || name;
    }
    return {
        id: id,
        name: name,
        special: name.indexOf("special:") === 0,
        monitor: metadata ? monitorFor(metadata, monitors) : null
    };
}

function groupMembers(raw, ownAddress) {
    if (!Array.isArray(raw)) return [];
    var members = [];
    raw.forEach(function(value) {
        var member = address(value);
        if (member && members.indexOf(member) === -1) members.push(member);
    });
    // A partial group report cannot establish this window's membership.
    return members.length > 1 && members.indexOf(ownAddress) !== -1
        ? members.sort(compareAddresses) : [];
}

// The reader supplies clients: null until a successful inventory is available.
// Missing workspace/monitor metadata does not discard otherwise usable windows.
function normalize(snapshot) {
    if (!snapshot || !Array.isArray(snapshot.clients))
        return { status: "unavailable", windows: [] };

    var workspaces = Array.isArray(snapshot.workspaces) ? snapshot.workspaces : [];
    var monitors = Array.isArray(snapshot.monitors) ? snapshot.monitors : [];
    var activeAddress = address(snapshot.activeAddress);
    var seen = Object.create(null);
    var windows = [];
    snapshot.clients.forEach(function(client) {
        if (!client || client.mapped === false) return;
        var id = address(client.address);
        if (!id || seen[id]) return;
        seen[id] = true;
        windows.push({
            address: id,
            app: text(client.app) || text(client.class) || text(client.initialClass),
            appId: text(client.class) || text(client.initialClass),
            title: text(client.title),
            workspace: normalizeWorkspace(client.workspace, workspaces, monitors),
            group: groupMembers(client.grouped, id),
            hidden: client.hidden === true,
            active: id === activeAddress
        });
    });
    windows.sort(function(a, b) { return compareAddresses(a.address, b.address); });
    return { status: "ready", windows: windows };
}

function searchText(value) {
    return text(value).normalize("NFC").toLowerCase();
}

function workspaceOrder(workspace) {
    if (!workspace) return 3;
    if (workspace.special) return 2;
    return workspace.id !== null && workspace.id > 0 ? 0 : 1;
}

function compareSections(a, b) {
    var rank = workspaceOrder(a.workspace);
    var difference = rank - workspaceOrder(b.workspace);
    if (difference) return difference;
    if (rank === 0) return a.workspace.id - b.workspace.id;
    if (rank === 3) return 0;
    return compare(a.workspace.name, b.workspace.name) || compare(a.key, b.key);
}

// Accepts normalize()'s result. Filtering never changes the inventory or row order.
function search(inventory, query, options) {
    var result = { status: inventory.status, sections: [] };
    if (inventory.status !== "ready") return result;

    var needle = searchText(query).trim();
    var includeSpecial = !options || options.includeSpecial !== false;
    var byWorkspace = Object.create(null);
    inventory.windows.forEach(function(window) {
        if (!includeSpecial && window.workspace && window.workspace.special) return;
        if (searchText(window.app).indexOf(needle) === -1
                && searchText(window.title).indexOf(needle) === -1) return;
        var key = workspaceKey(window.workspace);
        if (!byWorkspace[key]) {
            byWorkspace[key] = { key: key, workspace: window.workspace, windows: [] };
            result.sections.push(byWorkspace[key]);
        }
        byWorkspace[key].windows.push(window);
    });
    result.sections.sort(compareSections);
    return result;
}
