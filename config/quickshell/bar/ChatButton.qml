import QtQuick
import Quickshell
import ".."

Item {
    id: root
    implicitWidth: 26
    implicitHeight: 36

    Text {
        anchors.centerIn: parent
        text: "󰭹"
        font.family: Theme.fontFamily
        font.pixelSize: 15
        color: chatMouse.containsMouse ? Theme.primary : Theme.colOnSurface

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    MouseArea {
        id: chatMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Quickshell.execDetached(["ghostty", "--title=clipse-clipboard", "-e", "/home/Krish/.local/bin/clipse"]);
        }
    }
}
