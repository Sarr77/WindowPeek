pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property string lastUrl: ""
    property bool failed: false
    readonly property bool busy: browser.running
    // Only WindowPeek's public support/history links are accepted. Arguments
    // go directly to Omarchy's default-browser launcher, without a shell.
    function open(url) {
        if (busy) return false;
        lastUrl = String(url);
        failed = lastUrl !== "https://github.com/Sarr77/WindowPeek"
            && lastUrl !== "https://plugins.omarchy.org/plugin.html?id=sarr.windowpeek"
            && !/^https:\/\/github\.com\/Sarr77\/WindowPeek\/(?:issues|commits\/main\/|commit\/[a-f0-9]{40}|compare\/[a-f0-9]{40}\.\.\.[a-f0-9]{40})$/.test(lastUrl);
        if (failed) return false;
        browser.command = ["omarchy", "launch", "browser", lastUrl];
        browser.running = true;
        return true;
    }
    property Process browser: Process {
        onExited: function(code) { root.failed = code !== 0; }
    }
}
