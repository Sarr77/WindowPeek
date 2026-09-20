import QtQuick
import QtTest
import "../WindowModel.js" as Model

TestCase {
    name: "WindowModel"

    function test_readiness() {
        compare(Model.normalize(null).status, "unavailable");
        compare(Model.search(Model.normalize({ clients: [] }), "").status, "ready");
    }

    function test_search_in_qml_engine() {
        var group = ["0x20000000000001", "0x20000000000000"];
        var inventory = Model.normalize({
            clients: [
                { address: group[0], class: "Editor", title: "Cafe\u0301", hidden: true,
                    workspace: { id: -1337, name: "Projekt Łódź" }, grouped: group },
                { address: group[1], class: "Editor", title: "Notes",
                    workspace: { id: -1337, name: "Projekt Łódź" }, grouped: group }
            ],
            workspaces: [{ id: -1337, name: "Projekt Łódź", monitorID: 7 }],
            monitors: [{ id: 7, name: "TEST-A" }],
            activeAddress: group[1]
        });
        compare(inventory.windows[0].address, group[1]);
        compare(inventory.windows[0].active, true);
        var result = Model.search(inventory, "CAFÉ");
        compare(result.sections.length, 1);
        compare(result.sections[0].workspace.monitor.name, "TEST-A");
        compare(result.sections[0].windows.length, 1);
        compare(result.sections[0].windows[0].address, group[0]);
        compare(result.sections[0].windows[0].hidden, true);
        compare(result.sections[0].windows[0].group.length, 2);
    }
}
