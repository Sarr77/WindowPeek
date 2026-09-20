// Promote the opening window without mutating the inventory. Passing its address
// keeps the order stable while live focus changes; omitted means current focus.
function arrange(view, activeAddress) {
    function preferred(window) { return activeAddress === undefined ? window.active : window.address === activeAddress; }
    var sections = view.sections.slice();
    var count = sections.reduce(function(total, section) { return total + section.windows.length; }, 0);
    var active = sections.findIndex(function(section) {
        return section.windows.some(preferred);
    });
    if (active > 0) sections.unshift(sections.splice(active, 1)[0]);
    var result = sections.map(function(section) {
        var windows = section.windows.slice();
        var index = windows.findIndex(preferred);
        if (index > 0) windows.unshift(windows.splice(index, 1)[0]);
        return { key: section.key, workspace: section.workspace, windows: windows };
    });
    return { status: view.status, count: count, sections: result };
}
