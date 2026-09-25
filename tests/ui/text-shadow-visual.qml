import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons

// Fictional color patches compare the native letter-only halo at actual size.
ShellRoot {
    id:test
    Window {
        id:window; visible:true; width:1120; height:820; color:"#202126"
        Rectangle { id:canvas; anchors.fill:parent; color:window.color
            Column {
                x:20; y:20; spacing:12
                Repeater {
                    model:[{name:"Green wallpaper",bg:"#428d72",fg:"#dcd7ba"},
                        {name:"Light wallpaper",bg:"#c8d7bc",fg:"#dcd7ba"},
                        {name:"Dark wallpaper",bg:"#1b282b",fg:"#dcd7ba"},
                        {name:"Dark text on green",bg:"#428d72",fg:"#507b6e"}]
                    delegate:Column {
                        required property var modelData
                        spacing:6
                        Text { text:parent.modelData.name; color:"white"; font.pixelSize:14 }
                        Row {
                            spacing:10
                            Repeater {
                                model:[0,1,2]
                                delegate:Rectangle {
                                    required property real modelData
                                    width:350; height:150; color:parent.parent.modelData.bg
                                    Column { x:12; y:10; spacing:12
                                        Text { text:["Previous outline", "Theme text + shadow", "Theme text + outline"][parent.parent.modelData]; font.pixelSize:12; color:"#ffffff"; style:Text.Outline;styleColor:"#555555" }
                                        Repeater {
                                            model:[{text:"Windows  14",bold:false},
                                                {text:"Settings · Personalization",bold:false},
                                                {text:"Review options",bold:false},
                                                {text:"Workspace 1 · Document viewer",bold:false}]
                                            delegate:Text {
                                                required property var modelData
                                                text:modelData.text; font.bold:modelData.bold
                                                font.family:Style.font.family; font.pixelSize:10
                                                color:parent.parent.modelData===0 ? parent.parent.parent.parent.modelData.fg : "#c1c497"
                                                style:parent.parent.modelData===1 ? Text.Raised : Text.Outline
                                                styleColor:parent.parent.modelData===0 && color.r<0.4 ? Qt.rgba(1,1,1,.6) : Qt.rgba(0,0,0,.8)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Timer { interval:300; running:true; onTriggered:canvas.grabToImage(function(r){
        r.saveToFile(Quickshell.env("WINDOWPEEK_TEST_IMAGE")); console.info("WINDOWPEEK_TEST_PASS"); Qt.quit();
    }) }
}
