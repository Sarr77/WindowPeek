// Hyprland's JSON batch replies are separated by three newlines.
function snapshot(output) {
    try {
        var parts = output.trim().split(/\n{3,}/).map(function(part) { return JSON.parse(part); });
        if (parts.length !== 4 || !parts.slice(0, 3).every(Array.isArray)
                || !parts[3] || typeof parts[3] !== "object" || Array.isArray(parts[3])) return null;
        return { clients: parts[0], workspaces: parts[1], monitors: parts[2],
            activeAddress: typeof parts[3].address === "string" ? parts[3].address : "" };
    } catch (error) { return null; }
}

function relevantEvent(name) {
    return /^(activewindow|activespecial|movewindow|openwindow|closewindow|windowtitle|monitoradded|monitorremoved|workspace|createworkspace|destroyworkspace|renameworkspace|moveworkspace|focusedmon|togglegroup|moveintogroup|moveoutofgroup|configreloaded)/.test(name);
}
