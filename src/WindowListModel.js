// Shared presentation rows for the panel and hover. All roles are primitive values.
function rows(view) {
    var result = [];
    function row(key, kind) {
        return { key: key, kind: kind, address: "", app: "", appId: "", title: "",
            workspaceName: "", workspaceId: 0, monitorName: "", active: false, grouped: false, first: false };
    }
    view.sections.forEach(function(section, index) {
        var header = row("workspace:" + section.key, "workspace");
        header.first = index === 0;
        if (section.workspace) {
            header.workspaceName = section.workspace.name;
            header.workspaceId = section.workspace.id || 0;
            header.monitorName = section.workspace.monitor ? section.workspace.monitor.name : "";
        }
        result.push(header);
        section.windows.forEach(function(window) {
            var item = row("window:" + window.address, "window");
            item.address = window.address; item.app = window.app; item.appId = window.appId;
            item.title = window.title; item.active = window.active; item.grouped = window.group.length > 1;
            result.push(item);
        });
    });
    return result;
}

// Update by identity: title/focus refreshes must not destroy hovered controls or
// briefly empty the scroll area. Insert/move existing rows, then remove leftovers.
function syncRows(model, next) {
    next.forEach(function(row, index) {
        if (index >= model.count || model.get(index).key !== row.key) {
            var found = -1;
            for (var i = index + 1; i < model.count; i++) {
                if (model.get(i).key === row.key) { found = i; break; }
            }
            if (found >= 0) model.move(found, index, 1);
            else model.insert(index, row);
        }
        var current = model.get(index);
        Object.keys(row).forEach(function(key) {
            if (current[key] !== row[key]) model.setProperty(index, key, row[key]);
        });
    });
    if (model.count > next.length) model.remove(next.length, model.count - next.length);
}
