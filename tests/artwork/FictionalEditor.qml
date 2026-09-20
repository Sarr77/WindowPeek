import QtQuick

// Fictional source window for the artwork; no desktop content is captured.
Rectangle {
    width: 960; height: 540; color: "#1a1b26"
    Rectangle { width: parent.width; height: 36; color: "#24283b" }
    Text { x: 22; y: 10; text: "Atlas project — app.ts"; color: "#a9b1d6"; font.pixelSize: 17; font.family: "DejaVu Sans" }
    Rectangle { y: 36; width: 190; height: 478; color: "#16161e" }
    Text { x: 18; y: 57; text: "EXPLORER"; color: "#737aa2"; font.pixelSize: 14; font.family: "DejaVu Sans" }
    Text { x: 18; y: 94; text: "▾  ATLAS\n\n    ▾  src"; color: "#a9b1d6"; font.pixelSize: 16; font.family: "DejaVu Sans" }
    Rectangle { x: 0; y: 173; width: 190; height: 32; color: "#292e42" }
    Text { x: 48; y: 179; text: "app.ts"; color: "#c0caf5"; font.pixelSize: 17; font.family: "DejaVu Sans" }
    Text { x: 48; y: 219; text: "windows.ts\n\ntheme.ts\n\nREADME.md"; color: "#9aa5ce"; font.pixelSize: 16; font.family: "DejaVu Sans" }
    Rectangle { x: 190; y: 36; width: 770; height: 39; color: "#16161e" }
    Rectangle { x: 190; y: 36; width: 153; height: 39; color: "#1a1b26" }
    Rectangle { x: 190; y: 36; width: 153; height: 2; color: "#d898f5" }
    Text { x: 208; y: 47; text: "TS   app.ts   ×"; color: "#c0caf5"; font.pixelSize: 16; font.family: "DejaVu Sans" }
    Text { x: 212; y: 89; text: "src  ›  app.ts  ›  listWindows"; color: "#737aa2"; font.pixelSize: 14; font.family: "DejaVu Sans" }
    Rectangle { x: 190; y: 178; width: 748; height: 29; color: "#202333" }
    Column {
        x: 214; y: 120; spacing: 8
        Repeater {
            model: [
                {code: "// Find the right window", shade: "#565f89"},
                {code: "export function listWindows(workspaces) {", shade: "#bb9af7"},
                {code: "  return workspaces", shade: "#7dcfff"},
                {code: "    .flatMap(space => space.windows)", shade: "#c0caf5"},
                {code: "    .filter(window => window.visible)", shade: "#c0caf5"},
                {code: "    .sort((left, right) =>", shade: "#c0caf5"},
                {code: "      left.title.localeCompare(right.title));", shade: "#9ece6a"},
                {code: "}", shade: "#bb9af7"},
                {code: "", shade: "#565f89"},
                {code: "const windows = listWindows(workspaces);", shade: "#7aa2f7"},
                {code: "renderWindowList(windows);", shade: "#c0caf5"}
            ]
            Row {
                required property int index
                required property var modelData
                spacing: 20
                Text { width: 26; text: parent.index + 1; horizontalAlignment: Text.AlignRight; color: "#414868"; font.pixelSize: 19; font.family: "DejaVu Sans Mono" }
                Text { text: parent.modelData.code; color: parent.modelData.shade; font.pixelSize: 19; font.family: "DejaVu Sans Mono" }
            }
        }
    }
    Rectangle { y: 514; width: 960; height: 26; color: "#303652" }
    Text { x: 18; y: 519; text: "⑂ main    ✓ 0    ⚠ 0"; color: "#a9b1d6"; font.pixelSize: 14; font.family: "DejaVu Sans" }
    Text { x: 715; y: 519; text: "Ln 3, Col 10     UTF-8     TypeScript"; color: "#a9b1d6"; font.pixelSize: 13; font.family: "DejaVu Sans" }
}
