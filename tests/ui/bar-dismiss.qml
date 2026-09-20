import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Ui as Ui
import "WindowPeek" as Plugin

ShellRoot {
    id: test
    property int step: 0
    function check(ok, message) { if (!ok) throw new Error(message); }
    QtObject { id: shell; function updateEntryInline(id, entry) { return true; } }
    Ui.PluginBarApi {
        id: api; pluginId:"sarr.windowpeek"; moduleName:"sarr.windowpeek"; shell:shell
        barSize:28; position:"top"
        layoutConfig: ({left:[{id:"sarr.windowpeek", autoUpdates:false, windowPreviews:false, panelHoverDelay:2000}],center:[],right:[]})
        _moduleWidgets: function() { return [widget]; }
    }
    TestEvent { id: events }
    Window {
        id: window; visible:true; width:500; height:60
        Plugin.Widget { id:widget; bar:api }
    }
    Timer {
        interval:100; running:true; repeat:true
        onTriggered: {
            if (!widget.settingsReady) return;
            try {
                switch (test.step++) {
                case 0:
                    events.mouseMove(window.contentItem, 450, 45, 0, Qt.NoButton, Qt.NoModifier);
                    widget.hoverDismissed = true;
                    events.mouseMove(widget, 12, 14, 0, Qt.NoButton, Qt.NoModifier);
                    break;
                case 1:
                    test.check(widget.hoverDismissed && !widget.canShowTooltip && !widget.tooltipReady,
                        "arrival after dismissal cannot schedule hover");
                    events.mouseMove(widget, 16, 14, 0, Qt.NoButton, Qt.NoModifier);
                    widget.persistSettings({panelHoverDelay:0}); break;
                case 2:
                    test.check(widget.hoverDismissed && !widget.tooltipReady,
                        "motion inside the label and zero delay keep suppression");
                    events.mouseMove(window.contentItem, 450, 45, 0, Qt.NoButton, Qt.NoModifier); break;
                case 3:
                    test.check(!widget.hoverDismissed, "leaving releases suppression");
                    widget.persistSettings({panelHoverDelay:2000});
                    events.mouseMove(widget, 12, 14, 0, Qt.NoButton, Qt.NoModifier); break;
                case 4:
                    test.check(widget.canShowTooltip && !widget.tooltipReady, "new entry starts normal dwell");
                    widget.hoverDismissed = true;
                    widget.persistSettings({panelHoverDelay:0}); break;
                case 5:
                    test.check(!widget.tooltipReady, "suppression cancels pending dwell before zero delay can reveal it");
                    console.info("WINDOWPEEK_TEST_PASS: bar hover suppression and exit"); stop(); Qt.quit();
                }
            } catch(error) { console.error("WINDOWPEEK_TEST_FAIL: " + error); stop(); Qt.quit(); }
        }
    }
}
