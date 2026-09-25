import QtQuick
import QtQuick.Window
import Quickshell
ShellRoot {
    Window {
        visible:true; width:1600; height:1000; title:"Fictional keyboard receiver"; color:"#112233"
        Item {
            anchors.fill:parent; focus:true
            Keys.onPressed:function(event) {console.log("BACKGROUND_KEY:"+event.text);event.accepted=true;}
        }
        MouseArea {anchors.fill:parent;onClicked:console.log("BACKGROUND_CLICK");onWheel:function(event){console.log("BACKGROUND_WHEEL:"+event.angleDelta.y);event.accepted=true;}}
    }
    Window {
        visible:true; width:800; height:1000; title:"Fictional second receiver"; color:"#224433"
        Item {anchors.fill:parent;focus:true;Keys.onPressed:function(event){console.log("BACKGROUND_KEY:"+event.text);event.accepted=true;}}
        MouseArea {anchors.fill:parent;onClicked:console.log("BACKGROUND_CLICK");onWheel:function(event){console.log("BACKGROUND_WHEEL:"+event.angleDelta.y);event.accepted=true;}}
    }
}
